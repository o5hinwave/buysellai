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
            listingText: "TITLE:\nSigned-in lamp\n\nDESCRIPTION:\nSigned-in lamp in good condition."
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

    func testStoredSupabaseSessionRefreshesAccessTokenBeforeLoadingRemoteHistory() async throws {
        try Keychain.save("server-user", for: authUserIDKey)
        try Keychain.save("person@example.com", for: authEmailKey)
        try Keychain.save("old-access", for: accessTokenKey)
        try Keychain.save("old-refresh", for: refreshTokenKey)

        let remoteEntry = HistoryEntry(
            id: try XCTUnwrap(UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")),
            createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-15T20:00:00Z")),
            itemName: "Refreshed lamp",
            category: .home,
            condition: .good,
            suggestedPrice: Decimal(45),
            imageThumbnail: Data([4, 5, 6]),
            marketplace: .ebay,
            listingText: "TITLE:\nRefreshed lamp\n\nDESCRIPTION:\nRefreshed lamp in good condition."
        )
        var requestPaths: [String] = []
        let store = try makeStoreWithAuthRefresh { request in
            let url = try XCTUnwrap(request.url)
            requestPaths.append(url.path)

            if url.path == "/auth/v1/token" {
                let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
                XCTAssertEqual(components.queryItems?.first(where: { $0.name == "grant_type" })?.value, "refresh_token")
                let body = try XCTUnwrap(Self.bodyData(from: request))
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertEqual(json["refresh_token"] as? String, "old-refresh")
                XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")

                let response = try XCTUnwrap(HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                ))
                return (response, Data(#"{"access_token":"new-access","refresh_token":"new-refresh","user":{"id":"server-user","email":"person@example.com"}}"#.utf8))
            }

            XCTAssertEqual(url.path, "/rest/v1/history")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer new-access")
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Self.remoteRows(for: [remoteEntry]))
        }
        let context = try makeModelContext()
        store.configure(modelContext: context)

        await store.loadHistory()

        XCTAssertEqual(requestPaths, ["/auth/v1/token", "/rest/v1/history"])
        XCTAssertEqual(store.session?.accessToken, "new-access")
        XCTAssertEqual(store.session?.refreshToken, "new-refresh")
        XCTAssertEqual(Keychain.load(accessTokenKey), "new-access")
        XCTAssertEqual(Keychain.load(refreshTokenKey), "new-refresh")
        XCTAssertEqual(store.history.map(\.id), [remoteEntry.id])
        XCTAssertNil(store.toast)
    }

    func testStoredSupabaseSessionUsesFreshJWTWithoutRefreshRoundTrip() async throws {
        let freshAccessToken = Self.jwt(expiration: Date().addingTimeInterval(3_600))
        try Keychain.save("server-user", for: authUserIDKey)
        try Keychain.save("person@example.com", for: authEmailKey)
        try Keychain.save(freshAccessToken, for: accessTokenKey)
        try Keychain.save("refresh-token", for: refreshTokenKey)

        let remoteEntry = HistoryEntry(
            id: try XCTUnwrap(UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")),
            createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-16T20:00:00Z")),
            itemName: "Fresh token lamp",
            category: .home,
            condition: .good,
            suggestedPrice: Decimal(45),
            imageThumbnail: Data([7, 8, 9]),
            marketplace: .ebay,
            listingText: "TITLE:\nFresh token lamp\n\nDESCRIPTION:\nFresh token lamp in good condition."
        )
        var requestPaths: [String] = []
        let store = try makeStoreWithAuthRefresh { request in
            let url = try XCTUnwrap(request.url)
            requestPaths.append(url.path)
            XCTAssertEqual(url.path, "/rest/v1/history")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(freshAccessToken)")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Self.remoteRows(for: [remoteEntry]))
        }
        let context = try makeModelContext()
        store.configure(modelContext: context)

        await store.loadHistory()

        XCTAssertEqual(requestPaths, ["/rest/v1/history"])
        XCTAssertEqual(store.session?.accessToken, freshAccessToken)
        XCTAssertEqual(store.session?.refreshToken, "refresh-token")
        XCTAssertEqual(Keychain.load(accessTokenKey), freshAccessToken)
        XCTAssertEqual(Keychain.load(refreshTokenKey), "refresh-token")
        XCTAssertEqual(store.history.map(\.id), [remoteEntry.id])
        XCTAssertNil(store.toast)
    }

    func testStoredSupabaseSessionShowsToastAndPreservesHistoryWhenExpiredJWTRefreshFails() async throws {
        let expiredAccessToken = Self.jwt(expiration: Date().addingTimeInterval(-60))
        try Keychain.save("server-user", for: authUserIDKey)
        try Keychain.save("person@example.com", for: authEmailKey)
        try Keychain.save(expiredAccessToken, for: accessTokenKey)
        try Keychain.save("refresh-token", for: refreshTokenKey)

        let visibleEntry = HistoryEntry(
            id: try XCTUnwrap(UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")),
            createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-17T20:00:00Z")),
            itemName: "Visible lamp",
            category: .home,
            condition: .good,
            suggestedPrice: Decimal(45),
            imageThumbnail: nil,
            marketplace: .ebay,
            listingText: "TITLE:\nVisible lamp\n\nDESCRIPTION:\nVisible lamp in good condition."
        )
        var requestPaths: [String] = []
        let store = try makeStoreWithAuthRefresh { request in
            let url = try XCTUnwrap(request.url)
            requestPaths.append(url.path)
            XCTAssertEqual(url.path, "/auth/v1/token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }
        let context = try makeModelContext()
        store.configure(modelContext: context)
        store.history = [visibleEntry]

        await store.loadHistory()

        XCTAssertEqual(requestPaths, ["/auth/v1/token"])
        XCTAssertEqual(store.history.map(\.id), [visibleEntry.id])
        XCTAssertEqual(store.toast?.text, APIError.sessionExpired.localizedDescription)
    }

    func testAppleCredentialRevocationClearsAppleSessionAndStoredCredentials() async throws {
        try Keychain.save("server-user", for: authUserIDKey)
        try Keychain.save("apple-user", for: appleUserIDKey)
        try Keychain.save("person@example.com", for: authEmailKey)
        try Keychain.save("access-token", for: accessTokenKey)
        try Keychain.save("refresh-token", for: refreshTokenKey)
        let store = makeStore()

        store.handleAppleCredentialRevoked()

        XCTAssertNil(store.session)
        XCTAssertNil(Keychain.load(authUserIDKey))
        XCTAssertNil(Keychain.load(appleUserIDKey))
        XCTAssertNil(Keychain.load(authEmailKey))
        XCTAssertNil(Keychain.load(accessTokenKey))
        XCTAssertNil(Keychain.load(refreshTokenKey))
        XCTAssertEqual(store.toast?.text, "Apple sign-in was disconnected.")
        XCTAssertEqual(store.toast?.style, .info)
    }

    func testAppleCredentialRevocationDoesNotClearEmailSession() throws {
        try Keychain.save("email-user", for: authUserIDKey)
        try Keychain.save("person@example.com", for: authEmailKey)
        try Keychain.save("access-token", for: accessTokenKey)
        let store = makeStore()

        store.handleAppleCredentialRevoked()

        XCTAssertEqual(store.session?.userID, "email-user")
        XCTAssertEqual(Keychain.load(authUserIDKey), "email-user")
        XCTAssertEqual(Keychain.load(accessTokenKey), "access-token")
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

    func testSessionPersistenceLogsKeychainWriteFailuresWithoutSensitiveValues() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)
        let persistStart = try XCTUnwrap(source.range(of: "private func persist(_ session: AuthSession)"))
        let nextSection = try XCTUnwrap(source.range(of: "private var hasRemoteSessionCredentials", range: persistStart.upperBound..<source.endIndex))
        let persistSource = source[persistStart.lowerBound..<nextSection.lowerBound]

        XCTAssertNotNil(source.range(of: "import os"))
        XCTAssertNotNil(source.range(of: #"Logger(subsystem: "BuySellAI", category: "Persistence")"#))
        XCTAssertNotNil(persistSource.range(of: "private func saveCredential(_ value: String, for key: String)"))
        XCTAssertNotNil(persistSource.range(of: "try Keychain.save(value, for: key)"))
        XCTAssertNotNil(persistSource.range(of: #"logger.error("Credential persistence write failed")"#))
        XCTAssertNil(persistSource.range(of: "try? Keychain.save"))
    }

    func testLocalHistoryClearFailuresAreLoggedInsteadOfSilentlyIgnored() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)
        let setSessionStart = try XCTUnwrap(source.range(of: "func setSession(_ session: AuthSession) async"))
        let showToastStart = try XCTUnwrap(source.range(of: "func showToast(_ text: String, style: ToastStyle)", range: setSessionStart.upperBound..<source.endIndex))
        let setSessionSource = source[setSessionStart.lowerBound..<showToastStart.lowerBound]

        XCTAssertNil(source.range(of: "try? clearLocalHistory()"))
        XCTAssertNotNil(source.range(of: "clearLocalHistoryReportingFailure()"))
        XCTAssertNotNil(source.range(of: #"logger.error("Local history clear failed")"#))
        XCTAssertNotNil(source.range(of: #"Account deleted. Local history couldn't be cleared."#))
        XCTAssertNil(setSessionSource.range(of: "try clearLocalHistory()"))
        XCTAssertNotNil(setSessionSource.range(of: "didClearLocalHistory = clearLocalHistoryReportingFailure()"))
        XCTAssertNotNil(setSessionSource.range(of: #"Signed in. Listings synced. Local history couldn't be cleared."#))
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

    private func makeStoreWithAuthRefresh(
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
        let authClient = SupabaseAuthClient(session: session, config: config)
        let suiteName = "BuySellAI.AppStoreSessionPersistenceRefreshTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return AppStore(
            defaults: defaults,
            remoteHistoryClient: remoteHistoryClient,
            supabaseAuthClient: authClient
        )
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

    private static func jwt(expiration: Date) -> String {
        let header = base64URLString(Data(#"{"alg":"none","typ":"JWT"}"#.utf8))
        let payloadData = (try? JSONSerialization.data(withJSONObject: [
            "exp": Int(expiration.timeIntervalSince1970),
            "sub": "server-user"
        ])) ?? Data()
        let payload = base64URLString(payloadData)
        return "\(header).\(payload).signature"
    }

    private static func base64URLString(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let httpBody = request.httpBody {
            return httpBody
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count < 0 {
                return nil
            }
            if count == 0 {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
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
