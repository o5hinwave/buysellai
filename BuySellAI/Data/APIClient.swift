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
        isUITesting: Bool = LaunchArguments.isUITesting
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
        guard image.isEmpty == false else {
            throw APIError.decoding
        }

        if LaunchArguments.contains(LaunchArguments.uiTestingAnalyzeOffline) {
            try await Task.sleep(nanoseconds: 250_000_000)
            throw APIError.offline
        }

#if DEBUG
        if isUITesting {
            try await Task.sleep(nanoseconds: 250_000_000)
            return AnalyzeResponse(name: "Vintage brass table lamp", category: "Home", condition: "good", currentPrice: Decimal(45))
        }
#endif

        let config = try loadConfig()
        let payload = AnalyzeRequest(imageDataUrl: "data:image/jpeg;base64,\(image.base64EncodedString())")
        let request = try makeRequest(
            path: "analyze-image",
            config: config,
            accessToken: accessToken,
            body: payload
        )
        let response = try await perform(request, decoding: AnalyzeResponse.self)
        return try response.validatedForDisplay()
    }

    func generateListing(item: DetectedItem, marketplace: Marketplace, accessToken: String? = nil) async throws -> String {
        if LaunchArguments.contains(LaunchArguments.uiTestingGenerateOffline) {
            throw APIError.offline
        }

        let itemName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard itemName.isEmpty == false, item.priceEstimate > 0 else {
            throw APIError.decoding
        }
        let currencyCode = item.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayCurrencyCode = currencyCode.isEmpty ? "USD" : currencyCode

#if DEBUG
        if isUITesting {
            try await Task.sleep(nanoseconds: 250_000_000)
            return ListingFixtureText.sample(for: item, marketplace: marketplace, currencyCode: displayCurrencyCode)
        }
#endif

        let config = try loadConfig()
        let itemPayload = ListingItemPayload(
            name: itemName,
            category: item.category.apiValue,
            condition: item.condition.apiValue,
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
        return try ListingTextContract.validatedGenerated(response.listing)
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
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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
            return try await sendMapped(request, decoding: decoding)
        } catch let error as URLError where error.code == .networkConnectionLost {
            logger.warning("Retrying network connection lost")
            return try await sendMapped(request, decoding: decoding)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            try APIError.rethrowCancellation(error)
            throw APIError.mapTransport(error)
        }
    }

    private func sendMapped<Response: Decodable>(_ request: URLRequest, decoding: Response.Type) async throws -> Response {
        do {
            return try await send(request, decoding: decoding)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            try APIError.rethrowCancellation(error)
            throw APIError.mapTransport(error)
        }
    }

    private func send<Response: Decodable>(_ request: URLRequest, decoding: Response.Type) async throws -> Response {
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
    }

}

struct AnalyzeResponse: Decodable, Sendable {
    let name: String
    let category: String
    let condition: String
    let currentPrice: Decimal

    func validatedForDisplay() throws -> AnalyzeResponse {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCondition = condition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false,
              Category.knownAPIValue(trimmedCategory) != nil,
              Condition.knownAPIValue(trimmedCondition) != nil,
              currentPrice > 0
        else {
            throw APIError.decoding
        }
        return AnalyzeResponse(
            name: trimmedName,
            category: trimmedCategory,
            condition: trimmedCondition,
            currentPrice: currentPrice
        )
    }
}

enum APIError: LocalizedError, Equatable {
    case offline
    case timeout
    case rateLimited
    case server(Int)
    case decoding
    case notConfigured
    case sessionExpired
    case accountAlreadyLinked
    case unknown

    var errorDescription: String? {
        switch self {
        case .offline:
            "You're offline. Reconnect and try again.".localized
        case .timeout:
            "That took too long. Try again.".localized
        case .rateLimited:
            "Too many tries right now. Give it a minute.".localized
        case .server:
            "BuySell is having trouble. Try again.".localized
        case .decoding:
            "BuySell got an answer it couldn't read.".localized
        case .notConfigured:
            "BuySell isn't ready yet. Try again later.".localized
        case .sessionExpired:
            "Sign in again to continue.".localized
        case .accountAlreadyLinked:
            "That Apple account is already linked to another BuySell account.".localized
        case .unknown:
            "Something went wrong. Try again.".localized
        }
    }

    static func mapTransport(_ error: Error) -> APIError {
        if let error = error as? APIError {
            return error
        }
        if let error = error as? URLError {
            switch error.code {
            case .cancelled:
                return .unknown
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .dataNotAllowed,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed,
                 .internationalRoamingOff:
                return .offline
            case .timedOut:
                return .timeout
            default:
                return .unknown
            }
        }
        return .unknown
    }

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let error = error as? URLError, error.code == .cancelled {
            return true
        }
        return false
    }

    static func rethrowCancellation(_ error: Error) throws {
        if isCancellation(error) {
            throw CancellationError()
        }
    }

    static func userMessage(for error: Error) -> String {
        mapTransport(error).localizedDescription
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
