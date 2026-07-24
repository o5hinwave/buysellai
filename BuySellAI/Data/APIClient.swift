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
            return AnalyzeResponse(
                name: "Vintage brass table lamp",
                category: "Home",
                condition: "good",
                currentPrice: Decimal(45),
                analysis: AnalyzeIntelligence(
                    itemFacts: [
                        AnalyzeItemFact(label: "Material", value: "Brass", confidence: 0.82)
                    ],
                    missingFacts: ["maker mark"],
                    photoPrompt: "Show the maker mark if there is one.",
                    likelyMatches: [
                        AnalyzeLikelyMatch(
                            name: "Vintage brass table lamp",
                            distinguishingQuestion: "Does the base have a maker mark?",
                            confidence: 0.72
                        )
                    ]
                )
            )
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

    func generateListing(
        item: DetectedItem,
        marketplace: Marketplace,
        details: ItemDetailAnswers? = nil,
        imageData: Data? = nil,
        accessToken: String? = nil
    ) async throws -> String {
        try await generateListingPayload(
            item: item,
            marketplace: marketplace,
            details: details,
            imageData: imageData,
            accessToken: accessToken
        ).listing
    }

    func generateListingPayload(
        item: DetectedItem,
        marketplace: Marketplace,
        details: ItemDetailAnswers? = nil,
        imageData: Data? = nil,
        accessToken: String? = nil
    ) async throws -> GeneratedListing {
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
            return GeneratedListing(
                listing: ListingFixtureText.sample(for: item, marketplace: marketplace, currencyCode: displayCurrencyCode)
            )
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
        let cleanDetails = details?.sanitizedForUse
        let listingPayloadDetails = cleanDetails?.hasListingPayloadDetails == true ? cleanDetails : nil
        let payload = GenerateListingRequest(
            item: itemPayload,
            platform: marketplace.rawValue,
            details: listingPayloadDetails.map(ListingItemDetailsPayload.init(details:)),
            imageDataUrl: listingImageDataURL(from: imageData)
        )
        let request = try makeRequest(
            path: "generate-listing",
            config: config,
            accessToken: accessToken,
            body: payload
        )
        let response = try await perform(request, decoding: GenerateListingResponse.self)
        let draft = response.draft?.sanitizedForDisplay()
        let listing = draft?.copyableListingText ?? response.listing
        return GeneratedListing(
            listing: try ListingTextContract.validatedGenerated(listing),
            draft: draft
        )
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

    private func listingImageDataURL(from imageData: Data?) -> String? {
        guard let imageData, imageData.isEmpty == false else { return nil }
        let compactImageData = ImageTools.jpegDataDownscaled(
            from: imageData,
            maxLongEdge: 900,
            compression: 0.76
        ) ?? imageData
        return "data:image/jpeg;base64,\(compactImageData.base64EncodedString())"
    }

}

struct AnalyzeResponse: Decodable, Sendable {
    let name: String
    let category: String
    let condition: String
    let currentPrice: Decimal
    let analysis: AnalyzeIntelligence?

    init(
        name: String,
        category: String,
        condition: String,
        currentPrice: Decimal,
        analysis: AnalyzeIntelligence? = nil
    ) {
        self.name = name
        self.category = category
        self.condition = condition
        self.currentPrice = currentPrice
        self.analysis = analysis
    }

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
            currentPrice: currentPrice,
            analysis: analysis?.sanitizedForDisplay()
        )
    }
}

struct AnalyzeItemFact: Codable, Equatable, Sendable {
    let label: String
    let value: String
    let confidence: Double

    func sanitizedForDisplay() -> AnalyzeItemFact? {
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanLabel.isEmpty == false, cleanValue.isEmpty == false else {
            return nil
        }
        return AnalyzeItemFact(
            label: String(cleanLabel.prefix(40)),
            value: String(cleanValue.prefix(80)),
            confidence: min(max(confidence, 0), 1)
        )
    }
}

struct AnalyzeLikelyMatch: Codable, Equatable, Sendable {
    let name: String
    let distinguishingQuestion: String
    let confidence: Double

    func sanitizedForDisplay() -> AnalyzeLikelyMatch? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanQuestion = distinguishingQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanName.isEmpty == false else {
            return nil
        }
        return AnalyzeLikelyMatch(
            name: String(cleanName.prefix(80)),
            distinguishingQuestion: String(cleanQuestion.prefix(120)),
            confidence: min(max(confidence, 0), 1)
        )
    }

    var closenessLabel: String {
        switch confidence {
        case 0.8...:
            "Likely".localized
        case 0.55..<0.8:
            "Possible".localized
        default:
            "Maybe".localized
        }
    }
}

struct AnalyzeIntelligence: Codable, Equatable, Sendable {
    let itemFacts: [AnalyzeItemFact]
    let missingFacts: [String]
    let photoPrompt: String?
    let likelyMatches: [AnalyzeLikelyMatch]

    init(
        itemFacts: [AnalyzeItemFact],
        missingFacts: [String],
        photoPrompt: String?,
        likelyMatches: [AnalyzeLikelyMatch] = []
    ) {
        self.itemFacts = itemFacts
        self.missingFacts = missingFacts
        self.photoPrompt = photoPrompt
        self.likelyMatches = likelyMatches
    }

    enum CodingKeys: String, CodingKey {
        case itemFacts
        case missingFacts
        case photoPrompt
        case likelyMatches
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemFacts = try container.decodeIfPresent([AnalyzeItemFact].self, forKey: .itemFacts) ?? []
        missingFacts = try container.decodeIfPresent([String].self, forKey: .missingFacts) ?? []
        photoPrompt = try container.decodeIfPresent(String.self, forKey: .photoPrompt)
        likelyMatches = try container.decodeIfPresent([AnalyzeLikelyMatch].self, forKey: .likelyMatches) ?? []
    }

    func sanitizedForDisplay() -> AnalyzeIntelligence? {
        let cleanFacts = itemFacts.compactMap { $0.sanitizedForDisplay() }.prefix(8)
        let cleanMissingFacts = missingFacts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .map { String($0.prefix(80)) }
            .prefix(5)
        let trimmedPrompt = photoPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleanPrompt = trimmedPrompt.isEmpty ? nil : String(trimmedPrompt.prefix(120))
        let cleanLikelyMatches = likelyMatches
            .compactMap { $0.sanitizedForDisplay() }
            .prefix(3)

        guard cleanFacts.isEmpty == false
            || cleanMissingFacts.isEmpty == false
            || cleanPrompt != nil
            || cleanLikelyMatches.isEmpty == false
        else {
            return nil
        }

        return AnalyzeIntelligence(
            itemFacts: Array(cleanFacts),
            missingFacts: Array(cleanMissingFacts),
            photoPrompt: cleanPrompt,
            likelyMatches: Array(cleanLikelyMatches)
        )
    }

    func acceptingLikelyMatch(_ match: AnalyzeLikelyMatch) -> AnalyzeIntelligence {
        guard let cleanMatch = match.sanitizedForDisplay() else {
            return self
        }

        let selectedFactLabel = "You picked".localized
        let selectedFact = AnalyzeItemFact(
            label: selectedFactLabel,
            value: cleanMatch.name,
            confidence: 1
        )
        let retainedFacts = itemFacts.filter { fact in
            fact.label.localizedCaseInsensitiveCompare(selectedFactLabel) != .orderedSame
        }
        let cleanFacts = ([selectedFact] + retainedFacts)
            .compactMap { $0.sanitizedForDisplay() }
            .prefix(8)
        let cleanLikelyMatches = likelyMatches
            .compactMap { $0.sanitizedForDisplay() }
            .filter { $0.name.localizedCaseInsensitiveCompare(cleanMatch.name) != .orderedSame }
            .prefix(3)

        return AnalyzeIntelligence(
            itemFacts: Array(cleanFacts),
            missingFacts: missingFacts,
            photoPrompt: photoPrompt,
            likelyMatches: Array(cleanLikelyMatches)
        )
    }

    var displayHint: String? {
        if let prompt = photoPrompt?.trimmingCharacters(in: .whitespacesAndNewlines), prompt.isEmpty == false {
            return prompt
        }
        guard let firstMissing = missingFacts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              firstMissing.isEmpty == false
        else { return nil }
        return String.localizedFormat("Check %@ if you know it.".localized, firstMissing)
    }

    var uncertaintyPrompt: String {
        if likelyMatches.isEmpty == false {
            return "Pick what looks closest, or snap a clearer label.".localized
        }
        if let displayHint {
            return displayHint
        }
        return "Try a closer photo of any logo, label, or model number.".localized
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
    let details: ListingItemDetailsPayload?
    let imageDataUrl: String?
}

private struct ListingItemPayload: Encodable {
    let name: String
    let category: String
    let condition: String
    let originalPrice: Decimal
    let currentPrice: Decimal
}

private struct ListingItemDetailsPayload: Encodable {
    let labelOrBrand: String?
    let sizeOrModel: String?
    let flaws: String?
    let included: String?
    let extraDetails: String?
    let isLargeOrFragile: Bool

    init(details: ItemDetailAnswers) {
        labelOrBrand = Self.optional(details.labelOrBrand)
        sizeOrModel = Self.optional(details.sizeOrModel)
        flaws = Self.optional(details.flaws)
        included = Self.optional(details.included)
        extraDetails = Self.optional(details.extraDetails)
        isLargeOrFragile = details.isLargeOrFragile
    }

    private static func optional(_ value: String) -> String? {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanValue.isEmpty ? nil : cleanValue
    }
}

private struct GenerateListingResponse: Decodable {
    let listing: String
    let draft: GeneratedListingDraft?
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
