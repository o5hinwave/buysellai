import AuthenticationServices
import XCTest
@testable import BuySellAI

final class AuthErrorPresentationTests: XCTestCase {
    func testAppleSignInCancellationDoesNotShowErrorToast() {
        let error = NSError(
            domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.Code.canceled.rawValue
        )

        XCTAssertNil(AuthErrorPresentation.message(for: error))
    }

    func testAppleSignInFailureUsesFriendlyRetryCopy() throws {
        let error = NSError(
            domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.Code.failed.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Raw framework failure"]
        )

        let message = try XCTUnwrap(AuthErrorPresentation.message(for: error))

        XCTAssertEqual(message, "Sign in couldn't finish. Try again.")
        XCTAssertFalse(message.localizedCaseInsensitiveContains("framework"))
        XCTAssertFalse(message.localizedCaseInsensitiveContains(ASAuthorizationError.errorDomain))
    }

    func testAPIErrorsKeepTheirSpecificFriendlyCopy() {
        XCTAssertEqual(
            AuthErrorPresentation.message(for: APIError.rateLimited),
            "Too many tries right now. Give it a minute."
        )
        XCTAssertEqual(
            AuthErrorPresentation.message(for: APIError.accountAlreadyLinked),
            "That Apple account is already linked to another BuySell account."
        )
    }

    func testTransportErrorsMapToFriendlyAuthCopy() {
        XCTAssertEqual(
            AuthErrorPresentation.message(for: URLError(.notConnectedToInternet)),
            "You're offline. Reconnect and try again."
        )
    }
}
