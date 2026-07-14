import AuthenticationServices
import Observation

@MainActor
@Observable
final class AuthStore {
    var email = ""
    var password = ""
    var showsEmailForm = false
    var isSigningIn = false
    var errorMessage: String?

    private let appleCoordinator = AppleSignInCoordinator()

    func signInWithApple() async throws -> AuthSession {
        isSigningIn = true
        defer { isSigningIn = false }
        return try await appleCoordinator.signIn()
    }

    func signInWithEmail() throws {
        // TODO(agent): needs backend Supabase auth endpoint/configuration.
        throw APIError.notConfigured
    }
}

@MainActor
private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<AuthSession, Error>?

    func signIn() async throws -> AuthSession {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: APIError.unknown)
            continuation = nil
            return
        }
        continuation?.resume(returning: AuthSession(userID: credential.user, email: credential.email, accessToken: nil))
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? UIWindow()
    }
}

