import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Security

@MainActor
@Observable
final class AuthStore {
    var email = ""
    var password = ""
    var isSigningIn = false
    var errorMessage: String?

    private let appleCoordinator = AppleSignInCoordinator()
    private let supabaseAuthClient: SupabaseAuthClient

    init(supabaseAuthClient: SupabaseAuthClient = SupabaseAuthClient()) {
        self.supabaseAuthClient = supabaseAuthClient
    }

    var canSubmitEmail: Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
            password.isEmpty == false &&
            isSigningIn == false
    }

    func signInWithApple() async throws -> AuthSession {
        guard isSigningIn == false else {
            throw CancellationError()
        }
        isSigningIn = true
        defer { isSigningIn = false }
        let result = try await appleCoordinator.signIn()
        guard
            let identityToken = result.identityToken,
            identityToken.isEmpty == false,
            let authorizationCode = result.authorizationCode,
            authorizationCode.isEmpty == false
        else {
            throw APIError.unknown
        }
        return try await supabaseAuthClient.exchangeAppleIdentityToken(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            nonce: result.nonce,
            appleUserID: result.userID,
            email: result.email
        )
    }

    func signInWithEmail() async throws -> AuthSession {
        guard isSigningIn == false else {
            throw CancellationError()
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.isEmpty == false, password.isEmpty == false else {
            throw APIError.decoding
        }
        isSigningIn = true
        defer { isSigningIn = false }
        return try await supabaseAuthClient.signInWithEmail(email: trimmedEmail, password: password)
    }
}

enum AuthErrorPresentation {
    static func message(for error: Error) -> String? {
        if let code = authorizationErrorCode(for: error) {
            return code == .canceled ? nil : "Sign in couldn't finish. Try again.".localized
        }
        if let apiError = error as? APIError {
            return apiError.localizedDescription
        }
        if error is CancellationError {
            return nil
        }
        return APIError.mapTransport(error).localizedDescription
    }

    private static func authorizationErrorCode(for error: Error) -> ASAuthorizationError.Code? {
        if let authorizationError = error as? ASAuthorizationError {
            return authorizationError.code
        }

        let nsError = error as NSError
        guard nsError.domain == ASAuthorizationError.errorDomain else { return nil }
        return ASAuthorizationError.Code(rawValue: nsError.code)
    }
}

struct AppleSignInResult: Sendable {
    let userID: String
    let email: String?
    let identityToken: String?
    let authorizationCode: String?
    let nonce: String
}

@MainActor
private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentNonce: String?
    private var currentController: ASAuthorizationController?

    func signIn() async throws -> AppleSignInResult {
        if Task.isCancelled {
            throw CancellationError()
        }
        guard continuation == nil else {
            throw CancellationError()
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                beginAuthorization(continuation: continuation)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelInFlightAuthorization()
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(throwing: APIError.unknown)
            return
        }
        let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        let nonce = currentNonce ?? ""
        finish(returning: AppleSignInResult(
            userID: credential.user,
            email: credential.email,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            nonce: nonce
        ))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish(throwing: error)
    }

    private func beginAuthorization(continuation: CheckedContinuation<AppleSignInResult, Error>) {
        if Task.isCancelled {
            continuation.resume(throwing: CancellationError())
            return
        }

        self.continuation = continuation
        do {
            let nonce = try Self.randomNonce()
            currentNonce = nonce
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email]
            request.nonce = Self.sha256(nonce)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            currentController = controller
            controller.performRequests()
        } catch {
            finish(throwing: error)
        }
    }

    private func finish(returning result: AppleSignInResult) {
        continuation?.resume(returning: result)
        resetInFlightAuthorization()
    }

    private func finish(throwing error: Error) {
        continuation?.resume(throwing: error)
        resetInFlightAuthorization()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeWindows = scenes
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
        return activeWindows.first { $0.isKeyWindow } ??
            activeWindows.first ??
            scenes.flatMap(\.windows).first { $0.isKeyWindow } ??
            UIWindow()
    }

    private static func randomNonce(length: Int = 32) throws -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw APIError.unknown
        }
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func cancelInFlightAuthorization() {
        finish(throwing: CancellationError())
    }

    private func resetInFlightAuthorization() {
        currentController?.delegate = nil
        currentController?.presentationContextProvider = nil
        continuation = nil
        currentNonce = nil
        currentController = nil
    }
}
