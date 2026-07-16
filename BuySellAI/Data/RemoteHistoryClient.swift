import Foundation

actor RemoteHistoryClient {
    private let session: URLSession
    private let injectedConfig: AppConfig?

    init(session: URLSession? = nil, config: AppConfig? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 20
            self.session = URLSession(configuration: configuration)
        }
        self.injectedConfig = config
    }

    func fetchHistory(accessToken: String) async throws -> [HistoryEntry] {
        let config = try loadConfig()
        var request = URLRequest(url: try historyURL(config: config, queryItems: [
            URLQueryItem(name: "select", value: RemoteHistoryRecord.selectColumns),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]))
        request.httpMethod = "GET"
        applyCommonHeaders(to: &request, config: config, accessToken: accessToken)
        let records = try await perform(request, decoding: [RemoteHistoryRecord].self)
        return deduplicatedEntries(from: records)
    }

    func upsertHistory(_ entries: [HistoryEntry], accessToken: String) async throws {
        guard entries.isEmpty == false else { return }
        let config = try loadConfig()
        var request = URLRequest(url: try historyURL(config: config, queryItems: [
            URLQueryItem(name: "on_conflict", value: "id")
        ]))
        request.httpMethod = "POST"
        applyCommonHeaders(to: &request, config: config, accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.remoteHistory.encode(entries.map(RemoteHistoryRecord.init(entry:)))
        try await performVoid(request)
    }

    func deleteHistory(id: UUID, accessToken: String) async throws {
        let config = try loadConfig()
        var request = URLRequest(url: try historyURL(config: config, queryItems: [
            URLQueryItem(name: "id", value: "eq.\(id.uuidString)")
        ]))
        request.httpMethod = "DELETE"
        applyCommonHeaders(to: &request, config: config, accessToken: accessToken)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        try await performVoid(request)
    }

    func clearHistory(accessToken: String) async throws {
        let config = try loadConfig()
        var request = URLRequest(url: try historyURL(config: config, queryItems: [
            URLQueryItem(name: "id", value: "not.is.null")
        ]))
        request.httpMethod = "DELETE"
        applyCommonHeaders(to: &request, config: config, accessToken: accessToken)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        try await performVoid(request)
    }

    private func loadConfig() throws -> AppConfig {
        if let injectedConfig {
            return injectedConfig
        }
        return try AppConfig.load()
    }

    private func historyURL(config: AppConfig, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents(
            url: config.supabaseURL.appending(path: "rest").appending(path: "v1").appending(path: "history"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw APIError.unknown
        }
        return url
    }

    private func applyCommonHeaders(to request: inout URLRequest, config: AppConfig, accessToken: String) {
        request.timeoutInterval = 20
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func perform<Response: Decodable>(_ request: URLRequest, decoding: Response.Type) async throws -> Response {
        do {
            return try await send(request, decoding: decoding)
        } catch APIError.server(let code) where (500...599).contains(code) {
            return try await sendMapped(request, decoding: decoding)
        } catch let error as URLError where error.code == .networkConnectionLost {
            return try await sendMapped(request, decoding: decoding)
        } catch {
            throw APIError.mapTransport(error)
        }
    }

    private func performVoid(_ request: URLRequest) async throws {
        do {
            try await sendVoid(request)
        } catch APIError.server(let code) where (500...599).contains(code) {
            try await sendVoidMapped(request)
        } catch let error as URLError where error.code == .networkConnectionLost {
            try await sendVoidMapped(request)
        } catch {
            throw APIError.mapTransport(error)
        }
    }

    private func sendMapped<Response: Decodable>(_ request: URLRequest, decoding: Response.Type) async throws -> Response {
        do {
            return try await send(request, decoding: decoding)
        } catch {
            throw APIError.mapTransport(error)
        }
    }

    private func sendVoidMapped(_ request: URLRequest) async throws {
        do {
            try await sendVoid(request)
        } catch {
            throw APIError.mapTransport(error)
        }
    }

    private func send<Response: Decodable>(_ request: URLRequest, decoding: Response.Type) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        do {
            return try JSONDecoder.remoteHistory.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func sendVoid(_ request: URLRequest) async throws {
        let (_, response) = try await session.data(for: request)
        try validate(response: response)
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.server(httpResponse.statusCode)
        }
    }

    private func deduplicatedEntries(from records: [RemoteHistoryRecord]) -> [HistoryEntry] {
        var seenIDs = Set<UUID>()
        var entries: [HistoryEntry] = []
        entries.reserveCapacity(records.count)

        for record in records where seenIDs.insert(record.id).inserted {
            entries.append(record.entry)
        }

        return entries
    }

}

private struct RemoteHistoryRecord: Codable {
    static let selectColumns = "id,created_at,item_name,category,condition,suggested_price,image_thumbnail_base64,marketplace,listing_text"

    let id: UUID
    let createdAt: Date
    let itemName: String
    let category: String?
    let condition: String?
    let suggestedPrice: Decimal?
    let imageThumbnailBase64: String?
    let marketplace: String
    let listingText: String

    init(entry: HistoryEntry) {
        self.id = entry.id
        self.createdAt = entry.createdAt
        self.itemName = entry.itemName
        self.category = entry.category?.rawValue
        self.condition = entry.condition?.rawValue
        self.suggestedPrice = entry.suggestedPrice
        self.imageThumbnailBase64 = entry.imageThumbnail?.base64EncodedString()
        self.marketplace = entry.marketplace.rawValue
        self.listingText = entry.listingText
    }

    var entry: HistoryEntry {
        HistoryEntry(
            id: id,
            createdAt: createdAt,
            itemName: itemName,
            category: category.map(Category.init(apiValue:)),
            condition: condition.map(Condition.init(apiValue:)),
            suggestedPrice: suggestedPrice,
            imageThumbnail: imageThumbnailBase64.flatMap { Data(base64Encoded: $0) },
            marketplace: Marketplace(apiValue: marketplace),
            listingText: listingText
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case itemName = "item_name"
        case category
        case condition
        case suggestedPrice = "suggested_price"
        case imageThumbnailBase64 = "image_thumbnail_base64"
        case marketplace
        case listingText = "listing_text"
    }
}

private extension JSONEncoder {
    static var remoteHistory: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601DateFormatter().string(from: date))
        }
        return encoder
    }
}

private extension JSONDecoder {
    static var remoteHistory: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) {
                return date
            }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: value) {
                return date
            }
            throw APIError.decoding
        }
        return decoder
    }
}
