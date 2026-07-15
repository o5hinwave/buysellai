import Foundation
import SwiftData
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
        AppStoreSessionPersistenceMockURLProtocol.handler = nil
    }

    override func tearDown() {
        clearStoredSession()
        AppStoreSessionPersistenceMockURLProtocol.handler = nil
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

    func testStoredSupabaseSessionLoadsRemoteHistoryAfterRelaunch() async throws {
        try Keychain.save("server-user", for: authUserIDKey)
        try Keychain.save("person@example.com", for: authEmailKey)
        try Keychain.save("access-token", for: accessTokenKey)
        try Keychain.save("refresh-token", for: refreshTokenKey)

        let remoteEntry = HistoryEntry(
            id: try XCTUnwrap(UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")),
            createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-14T20:00:00Z")),
            itemName: "Signed-in lamp",
            category: .home,
            condition: .good,
            suggestedPrice: Decimal(45),
            imageThumbnail: Data([1, 2, 3]),
            marketplace: .ebay,
            listingText: "TITLE:\nSigned-in lamp"
        )
        var observedRequest: URLRequest?
        let store = try makeStore { request in
            observedRequest = request
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Self.remoteRows(for: [remoteEntry]))
        }
        let context = try makeModelContext()
        store.configure(modelContext: context)

        XCTAssertEqual(store.session?.userID, "server-user")
        XCTAssertEqual(store.session?.accessToken, "access-token")

        await store.loadHistory()

        let request = try XCTUnwrap(observedRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(store.history.map(\.id), [remoteEntry.id])
        XCTAssertEqual(store.history.first?.itemName, "Signed-in lamp")
        XCTAssertEqual(store.history.first?.imageThumbnail, Data([1, 2, 3]))
        XCTAssertNil(store.toast)
    }

    func testAuthSessionIdentityUsesUserID() {
        let session = AuthSession(
            userID: "server-user",
            email: "person@example.com",
            accessToken: "access-token",
            refreshToken: "refresh-token"
        )

        XCTAssertEqual(session.id, "server-user")
    }

    private func makeStore() -> AppStore {
        let suiteName = "BuySellAI.AppStoreSessionPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return AppStore(defaults: defaults)
    }

    private func makeStore(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) throws -> AppStore {
        AppStoreSessionPersistenceMockURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStoreSessionPersistenceMockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration)
        let url = try XCTUnwrap(URL(string: "https://example.supabase.co"))
        let config = AppConfig(supabaseURL: url, anonKey: "anon-test-key")
        let remoteHistoryClient = RemoteHistoryClient(session: session, config: config)
        let suiteName = "BuySellAI.AppStoreSessionPersistenceRemoteTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return AppStore(defaults: defaults, remoteHistoryClient: remoteHistoryClient)
    }

    private func makeModelContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HistoryEntryModel.self, configurations: configuration)
        return ModelContext(container)
    }

    private static func remoteRows(for entries: [HistoryEntry]) -> Data {
        let formatter = ISO8601DateFormatter()
        let rows = entries.map { entry in
            [
                "id": entry.id.uuidString,
                "created_at": formatter.string(from: entry.createdAt),
                "item_name": entry.itemName,
                "category": jsonValue(entry.category?.rawValue),
                "condition": jsonValue(entry.condition?.rawValue),
                "suggested_price": jsonValue(entry.suggestedPrice?.doubleValue),
                "image_thumbnail_base64": jsonValue(entry.imageThumbnail?.base64EncodedString()),
                "marketplace": entry.marketplace.rawValue,
                "listing_text": entry.listingText
            ]
        }
        return (try? JSONSerialization.data(withJSONObject: rows)) ?? Data()
    }

    private static func jsonValue<T>(_ value: T?) -> Any {
        value ?? NSNull()
    }

    private func clearStoredSession() {
        Keychain.delete(appleUserIDKey)
        Keychain.delete(authUserIDKey)
        Keychain.delete(authEmailKey)
        Keychain.delete(accessTokenKey)
        Keychain.delete(refreshTokenKey)
    }
}

private final class AppStoreSessionPersistenceMockURLProtocol: URLProtocol {
    private static let handlerLock = NSLock()
    private static var storedHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))? {
        get {
            handlerLock.lock()
            defer { handlerLock.unlock() }
            return storedHandler
        }
        set {
            handlerLock.lock()
            storedHandler = newValue
            handlerLock.unlock()
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
