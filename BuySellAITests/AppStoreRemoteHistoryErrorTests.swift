import Foundation
import XCTest
@testable import BuySellAI

@MainActor
final class AppStoreRemoteHistoryErrorTests: XCTestCase {
    override func tearDown() {
        AppStoreRemoteHistoryMockURLProtocol.handler = nil
        clearStoredSession()
        super.tearDown()
    }

    func testSignedInLoadHistoryReplacesRowsFromRemote() async throws {
        let firstID = try XCTUnwrap(UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"))
        let secondID = try XCTUnwrap(UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"))
        let remoteEntries = [
            HistoryEntry(
                id: firstID,
                createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-14T20:00:00Z")),
                itemName: "Lamp",
                category: .home,
                condition: .good,
                suggestedPrice: Decimal(45),
                imageThumbnail: Data([1, 2, 3]),
                marketplace: .ebay,
                listingText: "TITLE:\nLamp"
            ),
            HistoryEntry(
                id: secondID,
                createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-14T19:00:00Z")),
                itemName: "Chair",
                category: .furniture,
                condition: .fair,
                suggestedPrice: Decimal(30),
                imageThumbnail: nil,
                marketplace: .craigslist,
                listingText: "TITLE:\nChair"
            )
        ]
        var observedRequest: URLRequest?
        let store = try makeStore { request in
            observedRequest = request
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Self.remoteRows(for: remoteEntries))
        }
        store.session = signedInSession
        store.history = [historyEntry]

        await store.loadHistory()

        let request = try XCTUnwrap(observedRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertTrue(request.url?.absoluteString.contains("select=id,created_at,item_name,category,condition,suggested_price,image_thumbnail_base64,marketplace,listing_text") == true)
        XCTAssertTrue(request.url?.absoluteString.contains("order=created_at.desc") == true)
        XCTAssertEqual(store.history.map(\.id), [firstID, secondID])
        XCTAssertEqual(store.history[0].imageThumbnail, Data([1, 2, 3]))
        XCTAssertNil(store.toast)
    }

    func testSignedInLoadHistoryShowsMappedTimeoutToast() async throws {
        let store = try makeStore { _ in
            throw URLError(.timedOut)
        }
        store.session = signedInSession

        await store.loadHistory()

        XCTAssertEqual(store.toast?.text, APIError.timeout.localizedDescription)
    }

    func testSignedInLateLoadHistoryDoesNotOverwriteNewlySavedListing() async throws {
        let staleRemoteEntry = HistoryEntry(
            id: try XCTUnwrap(UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")),
            createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-14T18:00:00Z")),
            itemName: "Stale remote lamp",
            category: .home,
            condition: .fair,
            suggestedPrice: Decimal(12),
            imageThumbnail: nil,
            marketplace: .craigslist,
            listingText: "TITLE:\nStale remote lamp"
        )
        let fetchStarted = expectation(description: "remote fetch started")
        let postReturned = expectation(description: "remote save returned")
        let releaseFetch = DispatchSemaphore(value: 0)
        let store = try makeStore { request in
            switch request.httpMethod {
            case "GET":
                fetchStarted.fulfill()
                XCTAssertEqual(.success, releaseFetch.wait(timeout: .now() + 2))
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                ))
                return (response, Self.remoteRows(for: [staleRemoteEntry]))
            case "POST":
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                ))
                postReturned.fulfill()
                return (response, Data())
            default:
                XCTFail("Unexpected request method: \(request.httpMethod ?? "nil")")
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                ))
                return (response, Data())
            }
        }
        store.session = signedInSession

        let loadTask = Task { await store.loadHistory() }
        await fulfillment(of: [fetchStarted], timeout: 1)

        store.saveListing(item: lamp, imageData: nil, marketplace: .ebay, listingText: "TITLE:\nLamp")
        XCTAssertEqual(store.history.map(\.itemName), ["Lamp"])

        releaseFetch.signal()
        await fulfillment(of: [postReturned], timeout: 1)
        await loadTask.value

        XCTAssertEqual(store.history.map(\.itemName), ["Lamp"])
        XCTAssertFalse(store.history.contains { $0.id == staleRemoteEntry.id })
    }

    func testLateSetSessionFetchDoesNotOverwriteNewlySavedListing() async throws {
        let staleRemoteEntry = HistoryEntry(
            id: try XCTUnwrap(UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")),
            createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-14T17:00:00Z")),
            itemName: "Older remote chair",
            category: .furniture,
            condition: .fair,
            suggestedPrice: Decimal(20),
            imageThumbnail: nil,
            marketplace: .craigslist,
            listingText: "TITLE:\nOlder remote chair"
        )
        let fetchStarted = expectation(description: "session remote fetch started")
        let postReturned = expectation(description: "remote save returned")
        let releaseFetch = DispatchSemaphore(value: 0)
        let store = try makeStore { request in
            switch request.httpMethod {
            case "GET":
                fetchStarted.fulfill()
                XCTAssertEqual(.success, releaseFetch.wait(timeout: .now() + 2))
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                ))
                return (response, Self.remoteRows(for: [staleRemoteEntry]))
            case "POST":
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                ))
                postReturned.fulfill()
                return (response, Data())
            default:
                XCTFail("Unexpected request method: \(request.httpMethod ?? "nil")")
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                ))
                return (response, Data())
            }
        }

        let signInTask = Task { await store.setSession(signedInSession) }
        await fulfillment(of: [fetchStarted], timeout: 1)

        store.saveListing(item: lamp, imageData: nil, marketplace: .ebay, listingText: "TITLE:\nLamp")
        XCTAssertEqual(store.history.map(\.itemName), ["Lamp"])

        releaseFetch.signal()
        await fulfillment(of: [postReturned], timeout: 1)
        await signInTask.value

        XCTAssertEqual(store.history.map(\.itemName), ["Lamp"])
        XCTAssertFalse(store.history.contains { $0.id == staleRemoteEntry.id })
    }

    func testSignedInSaveListingRollsBackAndShowsRateLimitToast() async throws {
        let store = try makeStore { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }
        store.session = signedInSession

        store.saveListing(item: lamp, imageData: nil, marketplace: .ebay, listingText: "TITLE:\nLamp")
        await waitForToast(APIError.rateLimited.localizedDescription, in: store)

        XCTAssertTrue(store.history.isEmpty)
    }

    func testSignedInSaveFailureAfterSignOutDoesNotReplaceSignOutToast() async throws {
        let postStarted = expectation(description: "remote save started")
        let postReturned = expectation(description: "remote save returned")
        let releasePost = DispatchSemaphore(value: 0)
        let store = try makeStore { request in
            XCTAssertEqual(request.httpMethod, "POST")
            postStarted.fulfill()
            XCTAssertEqual(.success, releasePost.wait(timeout: .now() + 2))
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            ))
            postReturned.fulfill()
            return (response, Data())
        }
        store.session = signedInSession

        store.saveListing(item: lamp, imageData: nil, marketplace: .ebay, listingText: "TITLE:\nLamp")
        await fulfillment(of: [postStarted], timeout: 1)

        store.signOut()
        XCTAssertNil(store.session)
        XCTAssertEqual(store.toast?.text, "Signed out.")

        releasePost.signal()
        await fulfillment(of: [postReturned], timeout: 1)
        await settleAsyncCompletions()

        XCTAssertEqual(store.toast?.text, "Signed out.")
    }

    func testSignedInDeleteHistoryRestoresRowAndShowsMappedServerToast() async throws {
        let entry = historyEntry
        let store = try makeStore { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }
        store.session = signedInSession
        store.history = [entry]

        store.deleteHistory(entry)
        await waitForToast(APIError.server(503).localizedDescription, in: store)

        XCTAssertEqual(store.history.map(\.id), [entry.id])
    }

    func testSignedInDeleteFailureAfterNewerSaveDoesNotRestoreStaleSnapshot() async throws {
        let entry = historyEntry
        let deleteStarted = expectation(description: "remote delete started")
        let deleteReturned = expectation(description: "remote delete returned")
        let releaseDelete = DispatchSemaphore(value: 0)
        let store = try makeStore { request in
            switch request.httpMethod {
            case "DELETE":
                deleteStarted.fulfill()
                XCTAssertEqual(.success, releaseDelete.wait(timeout: .now() + 2))
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 400,
                    httpVersion: nil,
                    headerFields: nil
                ))
                deleteReturned.fulfill()
                return (response, Data())
            case "POST":
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                ))
                return (response, Data())
            default:
                XCTFail("Unexpected request method: \(request.httpMethod ?? "nil")")
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                ))
                return (response, Data())
            }
        }
        store.session = signedInSession
        store.history = [entry]

        store.deleteHistory(entry)
        await fulfillment(of: [deleteStarted], timeout: 1)
        XCTAssertTrue(store.history.isEmpty)

        store.saveListing(item: vase, imageData: nil, marketplace: .craigslist, listingText: "TITLE:\nVase")
        XCTAssertEqual(store.history.map(\.itemName), ["Vase"])

        releaseDelete.signal()
        await fulfillment(of: [deleteReturned], timeout: 1)
        await settleAsyncCompletions()

        XCTAssertEqual(store.history.map(\.itemName), ["Vase"])
        XCTAssertNil(store.toast)
    }

    func testSignedInClearHistoryRestoresRowsAndShowsOfflineToast() async throws {
        let entry = historyEntry
        let store = try makeStore { _ in
            throw URLError(.notConnectedToInternet)
        }
        store.session = signedInSession
        store.history = [entry]

        store.clearHistory()
        await waitForToast(APIError.offline.localizedDescription, in: store)

        XCTAssertEqual(store.history.map(\.id), [entry.id])
    }

    func testSignedInClearFailureAfterNewerSaveDoesNotRestoreStaleSnapshot() async throws {
        let entry = historyEntry
        let clearStarted = expectation(description: "remote clear started")
        let clearReturned = expectation(description: "remote clear returned")
        let releaseClear = DispatchSemaphore(value: 0)
        let store = try makeStore { request in
            switch request.httpMethod {
            case "DELETE":
                clearStarted.fulfill()
                XCTAssertEqual(.success, releaseClear.wait(timeout: .now() + 2))
                clearReturned.fulfill()
                throw URLError(.notConnectedToInternet)
            case "POST":
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                ))
                return (response, Data())
            default:
                XCTFail("Unexpected request method: \(request.httpMethod ?? "nil")")
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                ))
                return (response, Data())
            }
        }
        store.session = signedInSession
        store.history = [entry]

        store.clearHistory()
        await fulfillment(of: [clearStarted], timeout: 1)
        XCTAssertTrue(store.history.isEmpty)

        store.saveListing(item: vase, imageData: nil, marketplace: .craigslist, listingText: "TITLE:\nVase")
        XCTAssertEqual(store.history.map(\.itemName), ["Vase"])

        releaseClear.signal()
        await fulfillment(of: [clearReturned], timeout: 1)
        await settleAsyncCompletions()

        XCTAssertEqual(store.history.map(\.itemName), ["Vase"])
        XCTAssertNil(store.toast)
    }

    private var signedInSession: AuthSession {
        AuthSession(
            userID: "user-123",
            email: "person@example.com",
            accessToken: "access-token",
            refreshToken: "refresh-token"
        )
    }

    private var lamp: DetectedItem {
        DetectedItem(
            name: "Lamp",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )
    }

    private var vase: DetectedItem {
        DetectedItem(
            name: "Vase",
            category: .home,
            condition: .likeNew,
            priceEstimate: Decimal(32)
        )
    }

    private var historyEntry: HistoryEntry {
        HistoryEntry(
            id: UUID(),
            createdAt: Date(),
            itemName: "Lamp",
            category: .home,
            condition: .good,
            suggestedPrice: Decimal(45),
            imageThumbnail: nil,
            marketplace: .ebay,
            listingText: "TITLE:\nLamp"
        )
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

    private func makeStore(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) throws -> AppStore {
        AppStoreRemoteHistoryMockURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStoreRemoteHistoryMockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration)
        let url = try XCTUnwrap(URL(string: "https://example.supabase.co"))
        let config = AppConfig(supabaseURL: url, anonKey: "anon-test-key")
        let remoteHistoryClient = RemoteHistoryClient(session: session, config: config)
        let suiteName = "AppStoreRemoteHistoryErrorTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return AppStore(defaults: defaults, remoteHistoryClient: remoteHistoryClient)
    }

    private func waitForToast(_ expectedText: String?, in store: AppStore) async {
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            if store.toast?.text == expectedText {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Expected toast \(expectedText ?? "nil"), got \(store.toast?.text ?? "nil")")
    }

    private func settleAsyncCompletions() async {
        try? await Task.sleep(nanoseconds: 150_000_000)
    }

    private func clearStoredSession() {
        Keychain.delete("appleUserID")
        Keychain.delete("authUserID")
        Keychain.delete("authEmail")
        Keychain.delete("supabaseAccessToken")
        Keychain.delete("supabaseRefreshToken")
    }
}

private final class AppStoreRemoteHistoryMockURLProtocol: URLProtocol {
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
            guard let handler = Self.handler else {
                XCTFail("Missing AppStoreRemoteHistoryMockURLProtocol handler")
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
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
