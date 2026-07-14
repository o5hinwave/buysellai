import Foundation
import os

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let injectedConfig: AppConfig?
    private let isUITesting: Bool
    private let logger = Logger(subsystem: "BuySellAI", category: "API")

    init(
        session: URLSession? = nil,
        config: AppConfig? = nil,
        isUITesting: Bool = ProcessInfo.processInfo.arguments.contains("--ui-testing")
    ) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 20
            self.session = URLSession(configuration: configuration)
        }
        self.injectedConfig = config
        self.isUITesting = isUITesting
    }

    func analyze(image: Data, accessToken: String? = nil) async throws -> AnalyzeResponse {
        if isUITesting {
            try await Task.sleep(nanoseconds: 250_000_000)
            return AnalyzeResponse(name: "Vintage brass table lamp", category: "Home", condition: "good", currentPrice: Decimal(45))
        }

        let config = try loadConfig()
        let payload = AnalyzeRequest(imageDataUrl: "data:image/jpeg;base64,\(image.base64EncodedString())")
        let request = try makeRequest(
            path: "analyze-image",
            config: config,
            accessToken: accessToken,
            body: payload
        )
        return try await perform(request, decoding: AnalyzeResponse.self)
    }

    func generateListing(item: DetectedItem, marketplace: Marketplace, accessToken: String? = nil) async throws -> String {
        if isUITesting {
            try await Task.sleep(nanoseconds: 250_000_000)
            return """
            TITLE:
            \(item.name) - \(item.condition.display)

            DESCRIPTION:
            Selling a \(item.name.lowercased()) in \(item.condition.display.lowercased()) condition. Asking \(item.priceEstimate.currency(code: item.currencyCode)). Pickup or shipping depends on the marketplace.
            """
        }

        let config = try loadConfig()
        let itemPayload = ListingItemPayload(
            name: item.name,
            category: item.category.display,
            condition: item.condition.rawValue,
            originalPrice: item.priceEstimate,
            currentPrice: item.priceEstimate
        )
        let payload = GenerateListingRequest(item: itemPayload, platform: marketplace.rawValue)
        let request = try makeRequest(
            path: "generate-listing",
            config: config,
            accessToken: accessToken,
            body: payload
        )
        let response = try await perform(request, decoding: GenerateListingResponse.self)
        return response.listing
    }

    private func loadConfig() throws -> AppConfig {
        if let injectedConfig {
            return injectedConfig
        }
        return try AppConfig.load()
    }

    private func makeRequest<Body: Encodable>(
        path: String,
        config: AppConfig,
        accessToken: String?,
        body: Body
    ) throws -> URLRequest {
        let url = config.functionsBaseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let accessToken, accessToken.isEmpty == false {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder.api.encode(body)
        return request
    }

    private func perform<Response: Decodable>(_ request: URLRequest, decoding: Response.Type) async throws -> Response {
        do {
            return try await send(request, decoding: decoding)
        } catch APIError.server(let code) where (500...599).contains(code) {
            logger.warning("Retrying transient server error \(code)")
            return try await send(request, decoding: decoding)
        } catch let error as URLError where error.code == .networkConnectionLost {
            logger.warning("Retrying network connection lost")
            return try await send(request, decoding: decoding)
        }
    }

    private func send<Response: Decodable>(_ request: URLRequest, decoding: Response.Type) async throws -> Response {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.unknown
            }
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try JSONDecoder.api.decode(Response.self, from: data)
                } catch {
                    throw APIError.decoding
                }
            case 429:
                throw APIError.rateLimited
            default:
                throw APIError.server(httpResponse.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                throw APIError.offline
            case .timedOut:
                throw APIError.timeout
            default:
                throw APIError.unknown
            }
        } catch {
            throw APIError.unknown
        }
    }
}

struct AnalyzeResponse: Decodable, Sendable {
    let name: String
    let category: String
    let condition: String
    let currentPrice: Decimal
}

enum APIError: LocalizedError, Equatable {
    case offline
    case timeout
    case rateLimited
    case server(Int)
    case decoding
    case notConfigured
    case unknown

    var errorDescription: String? {
        switch self {
        case .offline:
            "You're offline. Reconnect and try again."
        case .timeout:
            "That took too long. Try again."
        case .rateLimited:
            "Too many tries right now. Give it a minute."
        case .server:
            "BuySell is having trouble. Try again."
        case .decoding:
            "BuySell got an answer it couldn't read."
        case .notConfigured:
            "Backend is not configured yet."
        case .unknown:
            "Something went wrong. Try again."
        }
    }
}

private struct AnalyzeRequest: Encodable {
    let imageDataUrl: String
}

private struct GenerateListingRequest: Encodable {
    let item: ListingItemPayload
    let platform: String
}

private struct ListingItemPayload: Encodable {
    let name: String
    let category: String
    let condition: String
    let originalPrice: Decimal
    let currentPrice: Decimal
}

private struct GenerateListingResponse: Decodable {
    let listing: String
}

private extension JSONEncoder {
    static var api: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }
}

private extension JSONDecoder {
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
