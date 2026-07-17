import Foundation
import SwiftData
import XCTest
@testable import BuySellAI

@MainActor
final class AppStoreMigrationTests: XCTestCase {
    override func tearDown() {
        AppStoreMigrationMockURLProtocol.handler = nil
        clearStoredSession()
        super.tearDown()
    }

    func testSetSessionMigratesGuestHistoryOnceAndClearsLocalRows() async throws {
        let firstID = try XCTUnwrap(UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"))
        let secondID = try XCTUnwrap(UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"))
        let blankListingID = try XCTUnwrap(UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc"))
        let blankNameID = try XCTUnwrap(UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"))
        let entries = [
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
            ),
            HistoryEntry(
                id: blankListingID,
                createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-14T18:30:00Z")),
                itemName: "Blank listing",
                category: .home,
                condition: .good,
                suggestedPrice: Decimal(10),
                imageThumbnail: nil,
                marketplace: .ebay,
                listingText: "  \n\t  "
            ),
            HistoryEntry(
                id: blankNameID,
                createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-14T18:00:00Z")),
                itemName: "  \n\t  ",
                category: .home,
                condition: .good,
                suggestedPrice: Decimal(10),
                imageThumbnail: nil,
                marketplace: .ebay,
                listingText: "TITLE:\nBlank name"
            )
        ]
        let context = try makeModelContext()
        entries.forEach { context.insert(HistoryEntryModel(entry: $0)) }
        try context.save()

        var upsertedIDBatches: [[String]] = []
        var fetchCount = 0
        let remoteHistoryClient = try makeRemoteHistoryClient { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")

            switch request.httpMethod {
            case "POST":
                let body = try XCTUnwrap(Self.bodyData(from: request))
                let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [[String: Any]])
                upsertedIDBatches.append(rows.compactMap { $0["id"] as? String }.sorted())
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil))
                return (response, Data())
            case "GET":
                fetchCount += 1
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
                return (response, Self.remoteRows(for: entries))
            default:
                XCTFail("Unexpected request method: \(request.httpMethod ?? "nil")")
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil))
                return (response, Data())
            }
        }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "AppStoreMigrationTests-\(UUID().uuidString)"))
        let store = AppStore(defaults: defaults, remoteHistoryClient: remoteHistoryClient)
        store.configure(modelContext: context)
        defer { store.signOut() }

        let session = AuthSession(
            userID: "user-123",
            email: "person@example.com",
            accessToken: "access-token",
            refreshToken: "refresh-token"
        )

        await store.setSession(session)

        XCTAssertEqual(upsertedIDBatches, [[firstID.uuidString, secondID.uuidString].sorted()])
        XCTAssertEqual(fetchCount, 1)
        XCTAssertEqual(store.history.map(\.id), [firstID, secondID])
        XCTAssertTrue(try context.fetch(FetchDescriptor<HistoryEntryModel>()).isEmpty)

        await store.setSession(session)

        XCTAssertEqual(upsertedIDBatches.count, 1)
        XCTAssertEqual(fetchCount, 2)
        XCTAssertEqual(store.history.map(\.id), [firstID, secondID])
    }

    func testSetSessionSignOutDuringMigrationDoesNotClearGuestHistory() async throws {
        let entry = HistoryEntry(
            id: try XCTUnwrap(UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")),
            createdAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-14T18:00:00Z")),
            itemName: "Guest lamp",
            category: .home,
            condition: .good,
            suggestedPrice: Decimal(45),
            imageThumbnail: nil,
            marketplace: .ebay,
            listingText: "TITLE:\nGuest lamp"
        )
        let context = try makeModelContext()
        context.insert(HistoryEntryModel(entry: entry))
        try context.save()

        let migrationStarted = expectation(description: "migration upload started")
        let releaseMigration = DispatchSemaphore(value: 0)
        let remoteHistoryClient = try makeRemoteHistoryClient { request in
            let url = try XCTUnwrap(request.url)
            switch request.httpMethod {
            case "POST":
                migrationStarted.fulfill()
                XCTAssertEqual(.success, releaseMigration.wait(timeout: .now() + 2))
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil))
                return (response, Data())
            case "GET":
                XCTFail("Stale sign-in migration should not fetch remote history after sign out.")
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
                return (response, Self.remoteRows(for: []))
            default:
                XCTFail("Unexpected request method: \(request.httpMethod ?? "nil")")
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil))
                return (response, Data())
            }
        }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "AppStoreMigrationTests-\(UUID().uuidString)"))
        let store = AppStore(defaults: defaults, remoteHistoryClient: remoteHistoryClient)
        store.configure(modelContext: context)

        let session = AuthSession(
            userID: "user-123",
            email: "person@example.com",
            accessToken: "access-token",
            refreshToken: "refresh-token"
        )

        let signInTask = Task { await store.setSession(session) }
        await fulfillment(of: [migrationStarted], timeout: 1)

        store.signOut()
        await store.loadHistory()
        XCTAssertNil(store.session)
        XCTAssertEqual(store.history.map(\.id), [entry.id])

        releaseMigration.signal()
        await signInTask.value

        XCTAssertNil(store.session)
        XCTAssertEqual(store.history.map(\.id), [entry.id])
        XCTAssertEqual(try context.fetch(FetchDescriptor<HistoryEntryModel>()).map(\.id), [entry.id])
        XCTAssertEqual(store.toast?.text, "Signed out.")
    }

    private func makeModelContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HistoryEntryModel.self, configurations: configuration)
        return ModelContext(container)
    }

    private func makeRemoteHistoryClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) throws -> RemoteHistoryClient {
        AppStoreMigrationMockURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStoreMigrationMockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration)
        let url = try XCTUnwrap(URL(string: "https://example.supabase.co"))
        let config = AppConfig(supabaseURL: url, anonKey: "anon-test-key")
        return RemoteHistoryClient(session: session, config: config)
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

    private func clearStoredSession() {
        Keychain.delete("appleUserID")
        Keychain.delete("authUserID")
        Keychain.delete("authEmail")
        Keychain.delete("supabaseAccessToken")
        Keychain.delete("supabaseRefreshToken")
    }
}

private final class AppStoreMigrationMockURLProtocol: URLProtocol {
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
