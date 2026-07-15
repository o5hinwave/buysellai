import XCTest
@testable import BuySellAI

@MainActor
final class AppStoreSessionPersistenceTests: XCTestCase {
    private let appleUserIDKey = "appleUserID"
    private let authUserIDKey = "authUserID"
    private let authEmailKey = "authEmail"
    private let accessTokenKey = "supabaseAccessToken"
    private let refreshTokenKey = "supabaseRefreshToken"

    override func setUp() {
        super.setUp()
        clearStoredSession()
    }

    override func tearDown() {
        clearStoredSession()
        super.tearDown()
    }

    func testAppleSessionPersistsAppleUserIdentifierSeparately() async throws {
        let store = makeStore()
        let session = AuthSession(
            userID: "apple-user",
            email: "person@example.com",
            accessToken: nil,
            refreshToken: nil,
            appleUserID: "apple-user"
        )

        await store.setSession(session)

        XCTAssertEqual(Keychain.load(authUserIDKey), "apple-user")
        XCTAssertEqual(Keychain.load(appleUserIDKey), "apple-user")
        XCTAssertEqual(Keychain.load(authEmailKey), "person@example.com")
    }

    func testEmailSessionDoesNotPopulateAppleUserIdentifierSlot() async throws {
        try Keychain.save("stale-apple-user", for: appleUserIDKey)
        let store = makeStore()
        let session = AuthSession(
            userID: "email-user",
            email: "person@example.com",
            accessToken: nil,
            refreshToken: nil
        )

        await store.setSession(session)

        XCTAssertEqual(Keychain.load(authUserIDKey), "email-user")
        XCTAssertNil(Keychain.load(appleUserIDKey))
        XCTAssertEqual(Keychain.load(authEmailKey), "person@example.com")
    }

    func testStoredAppleUserIdentifierRestoresWithSession() throws {
        try Keychain.save("apple-user", for: appleUserIDKey)
        try Keychain.save("auth-user", for: authUserIDKey)
        try Keychain.save("person@example.com", for: authEmailKey)

        let store = makeStore()

        XCTAssertEqual(store.session?.userID, "auth-user")
        XCTAssertEqual(store.session?.appleUserID, "apple-user")
        XCTAssertEqual(store.session?.email, "person@example.com")
    }

    private func makeStore() -> AppStore {
        let suiteName = "BuySellAI.AppStoreSessionPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return AppStore(defaults: defaults)
    }

    private func clearStoredSession() {
        Keychain.delete(appleUserIDKey)
        Keychain.delete(authUserIDKey)
        Keychain.delete(authEmailKey)
        Keychain.delete(accessTokenKey)
        Keychain.delete(refreshTokenKey)
    }
}
