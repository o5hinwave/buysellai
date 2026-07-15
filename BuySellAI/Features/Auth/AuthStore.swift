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
    var showsEmailForm = false
    var isSigningIn = false
    var errorMessage: String?

    private let appleCoordinator = AppleSignInCoordinator()
    private let supabaseAuthClient: SupabaseAuthClient

    init(supabaseAuthClient: SupabaseAuthClient = SupabaseAuthClient()) {
        self.supabaseAuthClient = supabaseAuthClient
    }

    func signInWithApple() async throws -> AuthSession {
        isSigningIn = true
        defer { isSigningIn = false }
        let result = try await appleCoordinator.signIn()
        guard let identityToken = result.identityToken, identityToken.isEmpty == false else {
            return AuthSession(userID: result.userID, email: result.email, appleUserID: result.userID)
        }
        do {
            return try await supabaseAuthClient.exchangeAppleIdentityToken(
                identityToken: identityToken,
                nonce: result.nonce,
                appleUserID: result.userID,
                email: result.email
            )
        } catch APIError.notConfigured {
            return AuthSession(userID: result.userID, email: result.email, appleUserID: result.userID)
        }
    }

    func signInWithEmail() async throws -> AuthSession {
        isSigningIn = true
        defer { isSigningIn = false }
        return try await supabaseAuthClient.signInWithEmail(email: email, password: password)
    }
}

struct AppleSignInResult: Sendable {
    let userID: String
    let email: String?
    let identityToken: String?
    let nonce: String
}

@MainActor
private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentNonce: String?

    func signIn() async throws -> AppleSignInResult {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            do {
                let nonce = try Self.randomNonce()
                self.currentNonce = nonce
                let provider = ASAuthorizationAppleIDProvider()
                let request = provider.createRequest()
                request.requestedScopes = [.email]
                request.nonce = Self.sha256(nonce)
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            } catch {
                continuation.resume(throwing: error)
                self.continuation = nil
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: APIError.unknown)
            continuation = nil
            return
        }
        let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        continuation?.resume(returning: AppleSignInResult(
            userID: credential.user,
            email: credential.email,
            identityToken: identityToken,
            nonce: currentNonce ?? ""
        ))
        continuation = nil
        currentNonce = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        currentNonce = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? UIWindow()
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
}
