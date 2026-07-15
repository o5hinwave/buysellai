import Foundation
import XCTest
@testable import BuySellAI

@MainActor
final class AppStoreRemoteHistoryErrorTests: XCTestCase {
    override func tearDown() {
        AppStoreRemoteHistoryMockURLProtocol.handler = nil
        super.tearDown()
    }

    func testSignedInLoadHistoryShowsMappedTimeoutToast() async throws {
        let store = try makeStore { _ in
            throw URLError(.timedOut)
        }
        store.session = signedInSession

        await store.loadHistory()

        XCTAssertEqual(store.toast?.text, APIError.timeout.localizedDescription)
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
}

private final class AppStoreRemoteHistoryMockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

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
