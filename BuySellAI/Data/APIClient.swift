import Foundation
import os

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let injectedConfig: AppConfig?
    private let isUITesting: Bool
    private let logger = Logger(subsystem: "BuySellAI", category: "API")
    private var marketplaceComparisonCache: [MarketplaceComparisonCacheKey: MarketplaceComparisonCacheEntry] = [:]
    private let marketplaceComparisonCacheTTL: TimeInterval = 15 * 60
    private let now: @Sendable () -> Date

    init(
        session: URLSession? = nil,
        config: AppConfig? = nil,
        isUITesting: Bool = LaunchArguments.isUITesting,
        now: @escaping @Sendable () -> Date = { Date() }
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
        self.now = now
    }

    func analyze(
        image: Data,
        nativeScanEvidence: NativeScanEvidence? = nil,
        accessToken: String? = nil
    ) async throws -> AnalyzeResponse {
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
        let analysisImage = analysisImageData(from: image)
        let payload = AnalyzeRequest(
            imageDataUrl: "data:image/jpeg;base64,\(analysisImage.base64EncodedString())",
            nativeScanEvidence: nativeScanEvidence?.sanitizedForPayload
        )
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
        marketplaceComparison: MarketplaceComparison? = nil,
        identificationProfile: AnalyzeIdentificationProfile? = nil,
        imageData: Data? = nil,
        accessToken: String? = nil
    ) async throws -> String {
        try await generateListingPayload(
            item: item,
            marketplace: marketplace,
            details: details,
            marketplaceComparison: marketplaceComparison,
            identificationProfile: identificationProfile,
            imageData: imageData,
            accessToken: accessToken
        ).listing
    }

    func compareMarketplaces(
        item: DetectedItem,
        details: ItemDetailAnswers? = nil,
        candidateMarketplaces: [Marketplace],
        identificationProfile: AnalyzeIdentificationProfile? = nil,
        accessToken: String? = nil
    ) async throws -> MarketplaceComparisonResponse {
        let itemName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard itemName.isEmpty == false, item.priceEstimate > 0 else {
            throw APIError.decoding
        }

        let candidates = Array(candidateMarketplaces.prefix(10))
        guard candidates.isEmpty == false else {
            throw APIError.decoding
        }

        let cacheKey = MarketplaceComparisonCacheKey(
            item: item,
            details: details,
            identificationProfile: identificationProfile,
            candidateMarketplaces: candidates
        )
        if let cachedResponse = cachedMarketplaceComparison(for: cacheKey) {
            ProductAnalytics.recordEstimatedCost(
                event: .groundedResearchCompleted,
                endpoint: "compare-marketplaces",
                estimatedAICostCents: 0,
                groundedSearchCount: 0,
                extra: [
                    "category": item.category.rawValue,
                    "candidate_count": "\(candidates.count)",
                    "cache_hit": "true",
                    "grounded_marketplace_count": "\(cachedResponse.groundedMarketplaceCount)"
                ].merging(cachedResponse.entitlement?.analyticsProperties ?? [:]) { current, _ in current }
            )
            return cachedResponse
        }

        ProductAnalytics.record(
            .groundedResearchStarted,
            properties: [
                "category": item.category.rawValue,
                "candidate_count": "\(candidates.count)"
            ]
        )

#if DEBUG
        if isUITesting {
            try await Task.sleep(nanoseconds: 250_000_000)
            let response = MarketplaceComparisonResponse(
                checkedAt: "2026-07-24T00:00:00Z",
                comparisons: candidates.enumerated().map { index, marketplace in
                    MarketplaceComparison(
                        marketplace: marketplace,
                        recommendationLabel: index == 0 ? MarketplaceSummaryKind.bestOverall.label : nil,
                        marketplaceFitScore: max(90 - index * 6, 48),
                        listPrice: item.priceEstimate,
                        likelyRangeLow: item.priceEstimate * Decimal(8) / Decimal(10),
                        likelyRangeHigh: item.priceEstimate * Decimal(11) / Decimal(10),
                        takeHomeEstimate: MarketplaceEstimator.estimates(for: item, details: details).first { $0.id == marketplace }?.payout,
                        compLowPrice: nil,
                        compMedianPrice: nil,
                        compHighPrice: nil,
                        expectedSpeed: "Steady sale",
                        shippingExpectation: marketplace.optimizationProfile.shippingEaseScore >= marketplace.optimizationProfile.localPickupScore ? "Easy shipping" : "Local pickup",
                        feeSummary: marketplace.playbookEvidence.feeModelSummary,
                        reason: marketplace.recommendationReason(for: item),
                        evidenceSummary: "Quick test estimate only; no verified sold comps.",
                        evidenceStatus: .limited,
                        evidenceSources: [
                            ListingEvidenceSource(
                                sourceMarketplace: marketplace.displayName,
                                title: marketplace.playbookEvidence.feeModelSourceTitle,
                                url: marketplace.playbookEvidence.feeModelSourceURL,
                                dateChecked: marketplace.playbookEvidence.feeModelLastChecked,
                                listingStatus: "Official",
                                conditionAndVariant: nil,
                                comparability: "Marketplace guidance",
                                price: nil
                            )
                        ]
                    )
                }
            )
            ProductAnalytics.recordEstimatedCost(
                event: .groundedResearchCompleted,
                endpoint: "compare-marketplaces",
                estimatedAICostCents: Decimal(string: "0.2") ?? 0,
                groundedSearchCount: response.groundedEvidenceSourceCount,
                extra: [
                    "category": item.category.rawValue,
                    "candidate_count": "\(candidates.count)",
                    "grounded_marketplace_count": "\(response.groundedMarketplaceCount)"
                ]
            )
            return response
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
        let detailsPayload: ListingItemDetailsPayload?
        if let cleanDetails, cleanDetails.hasListingPayloadDetails {
            detailsPayload = ListingItemDetailsPayload(details: cleanDetails)
        } else {
            detailsPayload = nil
        }
        let payload = CompareMarketplacesRequest(
            item: itemPayload,
            details: detailsPayload,
            identificationProfile: IdentificationProfilePayload(profile: identificationProfile),
            candidateMarketplaces: candidates.map(\.rawValue)
        )
        let request = try makeRequest(
            path: "compare-marketplaces",
            config: config,
            accessToken: accessToken,
            body: payload
        )
        let response = try await perform(request, decoding: MarketplaceComparisonResponse.self)
            .sanitizedForDisplay()
        ProductAnalytics.recordEstimatedCost(
            event: .groundedResearchCompleted,
            endpoint: "compare-marketplaces",
            estimatedAICostCents: Decimal(string: "0.2") ?? 0,
            groundedSearchCount: response.groundedEvidenceSourceCount,
            extra: [
                "category": item.category.rawValue,
                "candidate_count": "\(candidates.count)",
                "grounded_marketplace_count": "\(response.groundedMarketplaceCount)"
            ].merging(response.entitlement?.analyticsProperties ?? [:]) { current, _ in current }
        )
        storeMarketplaceComparison(response, for: cacheKey)
        return response
    }

    private func cachedMarketplaceComparison(
        for key: MarketplaceComparisonCacheKey
    ) -> MarketplaceComparisonResponse? {
        guard let entry = marketplaceComparisonCache[key] else { return nil }
        guard now().timeIntervalSince(entry.storedAt) <= marketplaceComparisonCacheTTL else {
            marketplaceComparisonCache[key] = nil
            return nil
        }
        return entry.response
    }

    private func storeMarketplaceComparison(
        _ response: MarketplaceComparisonResponse,
        for key: MarketplaceComparisonCacheKey
    ) {
        guard response.hasReusableMarketplaceEvidence else { return }
        marketplaceComparisonCache[key] = MarketplaceComparisonCacheEntry(
            response: response,
            storedAt: now()
        )
        trimMarketplaceComparisonCache()
    }

    private func trimMarketplaceComparisonCache() {
        guard marketplaceComparisonCache.count > 20 else { return }
        let keysToRemove = marketplaceComparisonCache
            .sorted { $0.value.storedAt < $1.value.storedAt }
            .prefix(marketplaceComparisonCache.count - 20)
            .map(\.key)
        keysToRemove.forEach { marketplaceComparisonCache[$0] = nil }
    }

    func generateListingPayload(
        item: DetectedItem,
        marketplace: Marketplace,
        details: ItemDetailAnswers? = nil,
        marketplaceComparison: MarketplaceComparison? = nil,
        identificationProfile: AnalyzeIdentificationProfile? = nil,
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
            marketplacePlaybook: MarketplaceListingPlaybookPayload(playbook: marketplace.listingPlaybook),
            details: listingPayloadDetails.map(ListingItemDetailsPayload.init(details:)),
            marketplaceComparison: marketplaceComparison.flatMap {
                MarketplaceComparisonPayload(comparison: $0, selectedMarketplace: marketplace)
            },
            identificationProfile: IdentificationProfilePayload(profile: identificationProfile),
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
            draft: draft,
            entitlement: response.entitlement
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
        request.setValue(installationIdentifier, forHTTPHeaderField: "X-BuySell-Device-ID")
        if let accessToken, accessToken.isEmpty == false {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder.api.encode(body)
        return request
    }

    private func analysisImageData(from image: Data) -> Data {
        ImageTools.jpegDataDownscaled(
            from: image,
            maxLongEdge: 1280,
            compression: 0.74
        ) ?? image
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
            ProductAnalytics.recordRateLimit(endpoint: request.url?.lastPathComponent ?? "unknown")
            throw APIError.rateLimited
        default:
            throw APIError.server(httpResponse.statusCode)
        }
    }

    private func listingImageDataURL(from imageData: Data?) -> String? {
        guard let imageData, imageData.isEmpty == false else { return nil }
        guard let compactImageData = ImageTools.jpegDataDownscaled(
            from: imageData,
            maxLongEdge: 900,
            compression: 0.76
        ) else { return nil }
        return "data:image/jpeg;base64,\(compactImageData.base64EncodedString())"
    }

    private var installationIdentifier: String {
        let key = "BuySell.installationIdentifier"
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key),
           UUID(uuidString: existing) != nil {
            return existing
        }

        let created = UUID().uuidString
        defaults.set(created, forKey: key)
        return created
    }

}

private extension MarketplaceComparisonResponse {
    var hasReusableMarketplaceEvidence: Bool {
        comparisons.contains { comparison in
            comparison.evidenceStatus != .unavailable &&
                comparison.evidenceSources?.isEmpty == false
        }
    }

    var groundedMarketplaceCount: Int {
        comparisons.filter { $0.evidenceStatus == .grounded }.count
    }

    var groundedEvidenceSourceCount: Int {
        comparisons.reduce(0) { count, comparison in
            count + (comparison.evidenceSources?.count ?? 0)
        }
    }
}

private struct MarketplaceComparisonCacheKey: Hashable {
    let itemName: String
    let category: Category
    let condition: Condition
    let price: String
    let currencyCode: String
    let details: [String]
    let identificationProfile: [String]
    let candidateMarketplaces: [Marketplace]

    init(
        item: DetectedItem,
        details: ItemDetailAnswers?,
        identificationProfile: AnalyzeIdentificationProfile?,
        candidateMarketplaces: [Marketplace]
    ) {
        itemName = Self.normalized(item.name)
        category = item.category
        condition = item.condition
        price = NSDecimalNumber(decimal: item.priceEstimate.rounded(scale: 2)).stringValue
        currencyCode = Self.normalized(item.currencyCode.isEmpty ? "USD" : item.currencyCode)
        self.details = (details?.sanitizedForUse?.displayValues ?? [])
            .map(Self.normalized)
            .filter { $0.isEmpty == false }
            .sorted()
        self.identificationProfile = Self.profileValues(identificationProfile)
        self.candidateMarketplaces = candidateMarketplaces
    }

    private static func normalized(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func profileValues(_ profile: AnalyzeIdentificationProfile?) -> [String] {
        guard let profile = profile?.sanitizedForDisplay() else { return [] }
        var values: [String] = []
        values.append(contentsOf: profile.confirmedFacts.map { "confirmed:\($0)" })
        values.append(contentsOf: profile.likelyFacts.map { "likely:\($0)" })
        values.append(contentsOf: profile.conflictingClues.map { "conflict:\($0)" })
        values.append(contentsOf: profile.unknownDetails.map { "unknown:\($0)" })
        values.append(contentsOf: profile.possibleMatches.map { "match:\($0)" })
        values.append(contentsOf: profile.potentiallyValuableVariants.map { "variant:\($0)" })
        values.append(contentsOf: profile.evidenceNeeded.map { "needed:\($0)" })
        values.append(contentsOf: profile.previousCorrections.map { "correction:\($0)" })
        values.append("confidence:\(profile.confidenceState.rawValue)")
        return values
            .map(normalized)
            .filter { $0.isEmpty == false }
            .sorted()
    }
}

private struct MarketplaceComparisonCacheEntry {
    let response: MarketplaceComparisonResponse
    let storedAt: Date
}

struct NativeScanBarcode: Codable, Equatable, Sendable, Hashable {
    let payload: String
    let symbology: String

    var sanitizedForPayload: NativeScanBarcode? {
        let cleanPayload = Self.clean(payload, maxLength: 120)
        let cleanSymbology = Self.clean(symbology, maxLength: 40)
        guard cleanPayload.isEmpty == false else { return nil }
        return NativeScanBarcode(
            payload: cleanPayload,
            symbology: cleanSymbology.isEmpty ? "unknown" : cleanSymbology
        )
    }

    private static func clean(_ value: String, maxLength: Int) -> String {
        let cleaned = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(maxLength))
    }
}

struct NativeScanEvidence: Codable, Equatable, Sendable, Hashable {
    let recognizedText: [String]
    let barcodes: [NativeScanBarcode]
    let modelOrSerialCandidates: [String]
    let photoQuality: PhotoQualityAssessment?

    init(
        recognizedText: [String],
        barcodes: [NativeScanBarcode],
        modelOrSerialCandidates: [String],
        photoQuality: PhotoQualityAssessment? = nil
    ) {
        self.recognizedText = recognizedText
        self.barcodes = barcodes
        self.modelOrSerialCandidates = modelOrSerialCandidates
        self.photoQuality = photoQuality
    }

    var sanitizedForPayload: NativeScanEvidence? {
        let cleanText = Self.cleanList(recognizedText, maxItems: 8, maxLength: 140)
        let cleanBarcodes = barcodes
            .compactMap(\.sanitizedForPayload)
            .prefix(4)
        let cleanCandidates = Self.cleanList(modelOrSerialCandidates, maxItems: 6, maxLength: 120)
        let cleanQuality = photoQuality?.sanitizedForPayload
        guard cleanText.isEmpty == false || cleanBarcodes.isEmpty == false || cleanCandidates.isEmpty == false || cleanQuality != nil else {
            return nil
        }
        return NativeScanEvidence(
            recognizedText: cleanText,
            barcodes: Array(cleanBarcodes),
            modelOrSerialCandidates: cleanCandidates,
            photoQuality: cleanQuality
        )
    }

    static func modelOrSerialCandidates(from recognizedText: [String]) -> [String] {
        let highValueMarkers = [
            "model",
            "serial",
            "s/n",
            "sku",
            "upc",
            "style",
            "size"
        ]
        let markedLines = recognizedText.filter { line in
            let lowercased = line.lowercased()
            return highValueMarkers.contains { lowercased.contains($0) }
        }
        let codeLikeLines = recognizedText.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasLetter = trimmed.rangeOfCharacter(from: .letters) != nil
            let hasDigit = trimmed.rangeOfCharacter(from: .decimalDigits) != nil
            return hasLetter && hasDigit && (4...40).contains(trimmed.count)
        }
        return cleanList(markedLines + codeLikeLines, maxItems: 6, maxLength: 120)
    }

    private static func cleanList(_ values: [String], maxItems: Int, maxLength: Int) -> [String] {
        var cleanValues: [String] = []
        for value in values {
            let cleaned = value
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.isEmpty == false else { continue }
            let limited = String(cleaned.prefix(maxLength))
            guard cleanValues.contains(limited) == false else { continue }
            cleanValues.append(limited)
            if cleanValues.count >= maxItems { break }
        }
        return cleanValues
    }
}

enum PhotoQualityIssue: String, Codable, Equatable, Sendable, Hashable {
    case tooDark
    case glare
    case lowContrast
    case tooSmall
}

struct PhotoQualityAssessment: Codable, Equatable, Sendable, Hashable {
    let brightness: Double
    let contrast: Double
    let glareRatio: Double
    let width: Int
    let height: Int
    let issue: PhotoQualityIssue?

    var isListingReady: Bool {
        issue == nil
    }

    var fixPrompt: String? {
        switch issue {
        case .tooDark:
            "Move it into better light."
        case .glare:
            "Tilt the item to remove glare."
        case .lowContrast:
            "Use more light."
        case .tooSmall:
            "Step back so the whole item fits."
        case nil:
            nil
        }
    }

    var sanitizedForPayload: PhotoQualityAssessment? {
        guard width > 0, height > 0 else { return nil }
        return PhotoQualityAssessment(
            brightness: Self.roundedUnit(brightness),
            contrast: Self.roundedUnit(contrast),
            glareRatio: Self.roundedUnit(glareRatio),
            width: min(max(width, 1), 8_000),
            height: min(max(height, 1), 8_000),
            issue: issue
        )
    }

    private static func roundedUnit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return (min(max(value, 0), 1) * 100).rounded() / 100
    }
}

struct AnalyzeResponse: Decodable, Sendable {
    let name: String
    let category: String
    let condition: String
    let currentPrice: Decimal
    let analysis: AnalyzeIntelligence?
    let entitlement: EntitlementSnapshot?

    init(
        name: String,
        category: String,
        condition: String,
        currentPrice: Decimal,
        analysis: AnalyzeIntelligence? = nil,
        entitlement: EntitlementSnapshot? = nil
    ) {
        self.name = name
        self.category = category
        self.condition = condition
        self.currentPrice = currentPrice
        self.analysis = analysis
        self.entitlement = entitlement?.sanitizedForUse
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
            analysis: analysis?.sanitizedForDisplay(),
            entitlement: entitlement?.sanitizedForUse
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

struct AnalyzeValueQuestion: Codable, Equatable, Sendable {
    enum AnswerField: String, Codable, Equatable, Sendable {
        case brand
        case spec
        case condition
        case included
        case extra
    }

    let question: String
    let reason: String
    let answerField: AnswerField
    let choices: [String]
    let unknownFollowUpQuestion: String?
    let unknownFollowUpChoices: [String]

    enum CodingKeys: String, CodingKey {
        case question
        case reason
        case answerField
        case choices
        case unknownFollowUpQuestion
        case unknownFollowUpChoices
    }

    init(
        question: String,
        reason: String,
        answerField: AnswerField,
        choices: [String],
        unknownFollowUpQuestion: String? = nil,
        unknownFollowUpChoices: [String] = []
    ) {
        self.question = question
        self.reason = reason
        self.answerField = answerField
        self.choices = choices
        self.unknownFollowUpQuestion = unknownFollowUpQuestion
        self.unknownFollowUpChoices = unknownFollowUpChoices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        question = try container.decode(String.self, forKey: .question)
        reason = try container.decode(String.self, forKey: .reason)
        answerField = try container.decode(AnswerField.self, forKey: .answerField)
        choices = try container.decodeIfPresent([String].self, forKey: .choices) ?? []
        unknownFollowUpQuestion = try container.decodeIfPresent(String.self, forKey: .unknownFollowUpQuestion)
        unknownFollowUpChoices = try container.decodeIfPresent([String].self, forKey: .unknownFollowUpChoices) ?? []
    }

    func sanitizedForDisplay() -> AnalyzeValueQuestion? {
        let cleanQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanChoices = choices
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .reduce(into: [String]()) { result, choice in
                guard result.contains(where: { $0.localizedCaseInsensitiveCompare(choice) == .orderedSame }) == false else { return }
                result.append(String(choice.prefix(60)))
            }
            .prefix(4)
        let cleanFollowUpQuestion = unknownFollowUpQuestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleanFollowUpChoices = unknownFollowUpChoices
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .reduce(into: [String]()) { result, choice in
                guard result.contains(where: { $0.localizedCaseInsensitiveCompare(choice) == .orderedSame }) == false else { return }
                result.append(String(choice.prefix(44)))
            }
            .prefix(3)
        guard cleanQuestion.isEmpty == false else { return nil }
        return AnalyzeValueQuestion(
            question: String(cleanQuestion.prefix(120)),
            reason: cleanReason.isEmpty ? "This can change the price." : String(cleanReason.prefix(120)),
            answerField: answerField,
            choices: Array(cleanChoices),
            unknownFollowUpQuestion: cleanFollowUpQuestion.isEmpty ? nil : String(cleanFollowUpQuestion.prefix(100)),
            unknownFollowUpChoices: Array(cleanFollowUpChoices)
        )
    }
}

struct AnalyzeReferenceImage: Codable, Equatable, Sendable {
    let title: String
    let url: String
    let source: String?

    func sanitizedForDisplay() -> AnalyzeReferenceImage? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSource = source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard cleanTitle.isEmpty == false,
              let parsedURL = URL(string: cleanURL),
              ["http", "https"].contains(parsedURL.scheme?.lowercased() ?? "")
        else {
            return nil
        }

        return AnalyzeReferenceImage(
            title: String(cleanTitle.prefix(80)),
            url: cleanURL,
            source: cleanSource.isEmpty ? nil : String(cleanSource.prefix(80))
        )
    }

    var urlValue: URL? {
        URL(string: url)
    }
}

struct AnalyzeIdentificationProfile: Codable, Equatable, Hashable, Sendable {
    enum ConfidenceState: String, Codable, Equatable, Hashable, Sendable {
        case confirmed
        case likely
        case stillChecking
        case notEnoughEvidence
    }

    let confirmedFacts: [String]
    let likelyFacts: [String]
    let conflictingClues: [String]
    let unknownDetails: [String]
    let possibleMatches: [String]
    let potentiallyValuableVariants: [String]
    let evidenceNeeded: [String]
    let previousCorrections: [String]
    let confidenceState: ConfidenceState

    init(
        confirmedFacts: [String] = [],
        likelyFacts: [String] = [],
        conflictingClues: [String] = [],
        unknownDetails: [String] = [],
        possibleMatches: [String] = [],
        potentiallyValuableVariants: [String] = [],
        evidenceNeeded: [String] = [],
        previousCorrections: [String] = [],
        confidenceState: ConfidenceState = .stillChecking
    ) {
        self.confirmedFacts = confirmedFacts
        self.likelyFacts = likelyFacts
        self.conflictingClues = conflictingClues
        self.unknownDetails = unknownDetails
        self.possibleMatches = possibleMatches
        self.potentiallyValuableVariants = potentiallyValuableVariants
        self.evidenceNeeded = evidenceNeeded
        self.previousCorrections = previousCorrections
        self.confidenceState = confidenceState
    }

    func sanitizedForDisplay() -> AnalyzeIdentificationProfile? {
        let cleanConfirmedFacts = Self.cleanList(confirmedFacts, limit: 6)
        let cleanLikelyFacts = Self.cleanList(likelyFacts, limit: 6)
        let cleanConflictingClues = Self.cleanList(conflictingClues, limit: 4)
        let cleanUnknownDetails = Self.cleanList(unknownDetails, limit: 6)
        let cleanPossibleMatches = Self.cleanList(possibleMatches, limit: 3)
        let cleanValuableVariants = Self.cleanList(potentiallyValuableVariants, limit: 4)
        let cleanEvidenceNeeded = Self.cleanList(evidenceNeeded, limit: 5)
        let cleanPreviousCorrections = Self.cleanList(previousCorrections, limit: 4)

        guard cleanConfirmedFacts.isEmpty == false
            || cleanLikelyFacts.isEmpty == false
            || cleanConflictingClues.isEmpty == false
            || cleanUnknownDetails.isEmpty == false
            || cleanPossibleMatches.isEmpty == false
            || cleanValuableVariants.isEmpty == false
            || cleanEvidenceNeeded.isEmpty == false
            || cleanPreviousCorrections.isEmpty == false
        else {
            return nil
        }

        return AnalyzeIdentificationProfile(
            confirmedFacts: cleanConfirmedFacts,
            likelyFacts: cleanLikelyFacts,
            conflictingClues: cleanConflictingClues,
            unknownDetails: cleanUnknownDetails,
            possibleMatches: cleanPossibleMatches,
            potentiallyValuableVariants: cleanValuableVariants,
            evidenceNeeded: cleanEvidenceNeeded,
            previousCorrections: cleanPreviousCorrections,
            confidenceState: confidenceState
        )
    }

    static func synthesized(
        itemFacts: [AnalyzeItemFact],
        missingFacts: [String],
        likelyMatches: [AnalyzeLikelyMatch],
        valueQuestions: [AnalyzeValueQuestion]
    ) -> AnalyzeIdentificationProfile? {
        let cleanFacts = itemFacts.compactMap { $0.sanitizedForDisplay() }
        let confirmedFacts = cleanFacts
            .filter { $0.confidence >= 0.82 }
            .map { "\($0.label): \($0.value)" }
        let likelyFacts = cleanFacts
            .filter { $0.confidence < 0.82 }
            .map { "\($0.label): \($0.value)" }
        let unknownDetails = cleanList(missingFacts, limit: 6)
        let cleanMatches = likelyMatches.compactMap { $0.sanitizedForDisplay() }
        let possibleMatches = cleanMatches.map(\.name)
        let evidenceNeeded = cleanList(
            cleanMatches.map(\.distinguishingQuestion) + missingFacts.map { "Check \($0)" },
            limit: 5
        )
        let valuableVariants = cleanList(
            valueQuestions.compactMap { question in
                let text = "\(question.question) \(question.reason)".lowercased()
                let signals = [
                    "edition", "limited", "numbered", "signed", "signature",
                    "maker", "mark", "stamp", "hallmark", "authentic", "certificate",
                    "vintage", "antique", "year", "serial", "material", "sterling",
                    "style code", "sku", "oled", "storage", "capacity"
                ]
                guard signals.contains(where: { text.contains($0) }) else { return nil }
                return question.question
            },
            limit: 4
        )
        let confidenceState: ConfidenceState
        if confirmedFacts.isEmpty == false && unknownDetails.isEmpty && possibleMatches.count <= 1 {
            confidenceState = .confirmed
        } else if confirmedFacts.isEmpty == false || possibleMatches.count == 1 || likelyFacts.isEmpty == false {
            confidenceState = .likely
        } else if possibleMatches.isEmpty == false || unknownDetails.isEmpty == false {
            confidenceState = .stillChecking
        } else {
            confidenceState = .notEnoughEvidence
        }

        return AnalyzeIdentificationProfile(
            confirmedFacts: confirmedFacts,
            likelyFacts: likelyFacts,
            unknownDetails: unknownDetails,
            possibleMatches: possibleMatches,
            potentiallyValuableVariants: valuableVariants,
            evidenceNeeded: evidenceNeeded,
            confidenceState: confidenceState
        ).sanitizedForDisplay()
    }

    func acceptingLikelyMatch(_ match: AnalyzeLikelyMatch) -> AnalyzeIdentificationProfile {
        let selected = "Selected match: \(match.name)"
        return AnalyzeIdentificationProfile(
            confirmedFacts: Self.prepending(selected, to: confirmedFacts, limit: 6),
            likelyFacts: likelyFacts,
            conflictingClues: conflictingClues,
            unknownDetails: unknownDetails,
            possibleMatches: possibleMatches.filter { $0.localizedCaseInsensitiveCompare(match.name) != .orderedSame },
            potentiallyValuableVariants: potentiallyValuableVariants,
            evidenceNeeded: evidenceNeeded.filter { $0.localizedCaseInsensitiveCompare(match.distinguishingQuestion) != .orderedSame },
            previousCorrections: Self.prepending(selected, to: previousCorrections, limit: 4),
            confidenceState: .confirmed
        )
    }

    func applyingScannedFact(_ fact: AnalyzeItemFact, request: TargetedScanRequest) -> AnalyzeIdentificationProfile {
        let scannedFact = "\(fact.label): \(fact.value)"
        return AnalyzeIdentificationProfile(
            confirmedFacts: Self.prepending(scannedFact, to: confirmedFacts, limit: 6),
            likelyFacts: likelyFacts,
            conflictingClues: conflictingClues,
            unknownDetails: unknownDetails.filter { request.answersMissingFact($0) == false },
            possibleMatches: possibleMatches,
            potentiallyValuableVariants: potentiallyValuableVariants,
            evidenceNeeded: evidenceNeeded.filter { request.answersMissingFact($0) == false },
            previousCorrections: previousCorrections,
            confidenceState: confidenceState == .notEnoughEvidence ? .stillChecking : confidenceState
        )
    }

    func applyingUserAnswers(
        _ answers: ItemDetailAnswers?,
        item: DetectedItem,
        marketplace: Marketplace?
    ) -> AnalyzeIdentificationProfile? {
        guard let answers = answers?.sanitizedForUse else {
            return sanitizedForDisplay()
        }

        var userFacts: [String] = []
        var answeredSignals: [String] = []

        func appendUserFact(
            _ label: String,
            value: String,
            answers signals: [String]
        ) {
            let cleanValue = Self.cleanAnswer(value, limit: 160)
            guard cleanValue.isEmpty == false else { return }
            userFacts.append("\(label): \(cleanValue)")
            answeredSignals.append(contentsOf: signals)
        }

        appendUserFact(
            "User confirmed brand or mark",
            value: answers.labelOrBrand,
            answers: ["brand", "maker", "make", "mark", "logo", "label", "hallmark", "manufacturer"]
        )
        appendUserFact(
            "User confirmed model or size",
            value: answers.sizeOrModel,
            answers: [
                "model", "serial", "sku", "style code", "size", "measurement", "dimension",
                "capacity", "storage", "carrier", "set", "edition", "number"
            ]
        )
        appendUserFact(
            "User confirmed condition",
            value: answers.flaws,
            answers: ["condition", "flaw", "damage", "wear", "scratch", "tested", "working", "broken", "battery"]
        )
        appendUserFact(
            "User confirmed included items",
            value: answers.included,
            answers: ["included", "accessory", "accessories", "box", "packaging", "certificate", "receipt", "parts"]
        )
        appendUserFact(
            "User added detail",
            value: answers.extraDetails,
            answers: ["detail", "rare", "limited", "vintage", "antique", "handmade", "material", "year", "age"]
        )

        if answers.isLargeOrFragile {
            userFacts.append("User confirmed item is large or fragile")
            answeredSignals.append(contentsOf: ["large", "fragile", "shipping", "pickup", "delivery", "local"])
        } else if answers.answeredFieldKeys.contains(.largeOrFragile) {
            userFacts.append("User confirmed item is not large or fragile")
            answeredSignals.append(contentsOf: ["large", "fragile", "shipping", "pickup", "delivery", "local"])
        }

        let marketplaceNotes = Self.marketplaceFacts(from: answers, preferredMarketplace: marketplace)
        if marketplaceNotes.isEmpty == false {
            userFacts.append(contentsOf: marketplaceNotes)
            answeredSignals.append(contentsOf: ["marketplace", "shipping", "pickup", "delivery", "local", "price", "offer", "auction", "fixed"])
        }

        let itemSummary = Self.cleanAnswer(item.name, limit: 80)
        if itemSummary.isEmpty == false, userFacts.isEmpty == false {
            userFacts.append("Question context: \(itemSummary)")
        }

        let cleanUserFacts = Self.cleanList(userFacts, limit: 6)
        guard cleanUserFacts.isEmpty == false else {
            return sanitizedForDisplay()
        }

        let cleanSignals = Self.cleanList(answeredSignals, limit: 32).map { $0.lowercased() }
        let remainingUnknowns = Self.unresolvedValues(unknownDetails, answeredSignals: cleanSignals, limit: 6)
        let remainingEvidence = Self.unresolvedValues(evidenceNeeded, answeredSignals: cleanSignals, limit: 5)

        return AnalyzeIdentificationProfile(
            confirmedFacts: Self.cleanList(cleanUserFacts + confirmedFacts, limit: 6),
            likelyFacts: likelyFacts,
            conflictingClues: conflictingClues,
            unknownDetails: remainingUnknowns,
            possibleMatches: possibleMatches,
            potentiallyValuableVariants: potentiallyValuableVariants,
            evidenceNeeded: remainingEvidence,
            previousCorrections: previousCorrections,
            confidenceState: Self.confidenceAfterUserAnswers(
                current: confidenceState,
                hasRemainingUnknowns: remainingUnknowns.isEmpty == false || remainingEvidence.isEmpty == false,
                possibleMatchCount: possibleMatches.count,
                hasConflicts: conflictingClues.isEmpty == false
            )
        ).sanitizedForDisplay()
    }

    var primaryKnownSummary: String? {
        confirmedFacts.first ?? likelyFacts.first ?? possibleMatches.first
    }

    var primaryUnresolvedSummary: String? {
        if let conflict = conflictingClues.first {
            return String.localizedFormat("Conflicting clue: %@".localized, conflict)
        }
        if possibleMatches.count > 1 {
            return "A few similar matches are still possible.".localized
        }
        if let evidence = evidenceNeeded.first {
            return evidence
        }
        if let unknown = unknownDetails.first {
            return String.localizedFormat("Check %@ only if you can see it.".localized, unknown)
        }
        if let valuableVariant = potentiallyValuableVariants.first {
            return String.localizedFormat("Checked for value clue: %@".localized, valuableVariant)
        }
        return nil
    }

    var confidenceLabel: String {
        switch confidenceState {
        case .confirmed:
            "Confirmed".localized
        case .likely:
            "Likely".localized
        case .stillChecking:
            "Still checking".localized
        case .notEnoughEvidence:
            "Not enough evidence".localized
        }
    }

    private static func cleanList(_ values: [String], limit: Int) -> [String] {
        let cleanedValues = values
            .map { value in
                value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { $0.isEmpty == false }

        var uniqueValues: [String] = []
        for value in cleanedValues {
            let alreadyIncluded = uniqueValues.contains { existingValue in
                existingValue.localizedCaseInsensitiveCompare(value) == .orderedSame
            }
            guard alreadyIncluded == false else { continue }
            uniqueValues.append(String(value.prefix(100)))
            if uniqueValues.count >= limit { break }
        }
        return uniqueValues
    }

    private static func prepending(_ value: String, to values: [String], limit: Int) -> [String] {
        cleanList([value] + values, limit: limit)
    }

    private static func cleanAnswer(_ value: String, limit: Int) -> String {
        String(
            value
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(limit)
        )
    }

    private static func marketplaceFacts(
        from answers: ItemDetailAnswers,
        preferredMarketplace: Marketplace?
    ) -> [String] {
        if let preferredMarketplace {
            let note = cleanAnswer(answers.marketplaceNote(for: preferredMarketplace), limit: 160)
            guard note.isEmpty == false else { return [] }
            return ["\(preferredMarketplace.displayName) detail: \(note)"]
        }

        return Marketplace.allCases.compactMap { marketplace in
            let note = cleanAnswer(answers.marketplaceNote(for: marketplace), limit: 160)
            guard note.isEmpty == false else { return nil }
            return "\(marketplace.displayName) detail: \(note)"
        }
    }

    private static func unresolvedValues(
        _ values: [String],
        answeredSignals: [String],
        limit: Int
    ) -> [String] {
        guard answeredSignals.isEmpty == false else {
            return cleanList(values, limit: limit)
        }

        return cleanList(
            values.filter { value in
                let lowercasedValue = value.lowercased()
                return answeredSignals.contains { signal in
                    lowercasedValue.contains(signal) || signal.contains(lowercasedValue)
                } == false
            },
            limit: limit
        )
    }

    private static func confidenceAfterUserAnswers(
        current: ConfidenceState,
        hasRemainingUnknowns: Bool,
        possibleMatchCount: Int,
        hasConflicts: Bool
    ) -> ConfidenceState {
        switch current {
        case .confirmed:
            .confirmed
        case .likely:
            .likely
        case .stillChecking:
            hasRemainingUnknowns == false && possibleMatchCount <= 1 && hasConflicts == false
                ? .likely
                : .stillChecking
        case .notEnoughEvidence:
            .stillChecking
        }
    }
}

struct AnalyzeIntelligence: Codable, Equatable, Sendable {
    let itemFacts: [AnalyzeItemFact]
    let missingFacts: [String]
    let photoPrompt: String?
    let likelyMatches: [AnalyzeLikelyMatch]
    let valueQuestions: [AnalyzeValueQuestion]
    let referenceImages: [AnalyzeReferenceImage]
    let identificationProfile: AnalyzeIdentificationProfile?

    init(
        itemFacts: [AnalyzeItemFact],
        missingFacts: [String],
        photoPrompt: String?,
        likelyMatches: [AnalyzeLikelyMatch] = [],
        valueQuestions: [AnalyzeValueQuestion] = [],
        referenceImages: [AnalyzeReferenceImage] = [],
        identificationProfile: AnalyzeIdentificationProfile? = nil
    ) {
        self.itemFacts = itemFacts
        self.missingFacts = missingFacts
        self.photoPrompt = photoPrompt
        self.likelyMatches = likelyMatches
        self.valueQuestions = valueQuestions
        self.referenceImages = referenceImages
        self.identificationProfile = identificationProfile
    }

    enum CodingKeys: String, CodingKey {
        case itemFacts
        case missingFacts
        case photoPrompt
        case likelyMatches
        case valueQuestions
        case referenceImages
        case identificationProfile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemFacts = try container.decodeIfPresent([AnalyzeItemFact].self, forKey: .itemFacts) ?? []
        missingFacts = try container.decodeIfPresent([String].self, forKey: .missingFacts) ?? []
        photoPrompt = try container.decodeIfPresent(String.self, forKey: .photoPrompt)
        likelyMatches = try container.decodeIfPresent([AnalyzeLikelyMatch].self, forKey: .likelyMatches) ?? []
        valueQuestions = try container.decodeIfPresent([AnalyzeValueQuestion].self, forKey: .valueQuestions) ?? []
        referenceImages = try container.decodeIfPresent([AnalyzeReferenceImage].self, forKey: .referenceImages) ?? []
        identificationProfile = try container.decodeIfPresent(AnalyzeIdentificationProfile.self, forKey: .identificationProfile)
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
        let cleanValueQuestions = valueQuestions
            .compactMap { $0.sanitizedForDisplay() }
            .prefix(4)
        let cleanReferenceImages = referenceImages
            .compactMap { $0.sanitizedForDisplay() }
            .prefix(3)
        let cleanProfile = identificationProfile?.sanitizedForDisplay()
            ?? AnalyzeIdentificationProfile.synthesized(
                itemFacts: Array(cleanFacts),
                missingFacts: Array(cleanMissingFacts),
                likelyMatches: Array(cleanLikelyMatches),
                valueQuestions: Array(cleanValueQuestions)
            )

        guard cleanFacts.isEmpty == false
            || cleanMissingFacts.isEmpty == false
            || cleanPrompt != nil
            || cleanLikelyMatches.isEmpty == false
            || cleanValueQuestions.isEmpty == false
            || cleanReferenceImages.isEmpty == false
            || cleanProfile != nil
        else {
            return nil
        }

        return AnalyzeIntelligence(
            itemFacts: Array(cleanFacts),
            missingFacts: Array(cleanMissingFacts),
            photoPrompt: cleanPrompt,
            likelyMatches: Array(cleanLikelyMatches),
            valueQuestions: Array(cleanValueQuestions),
            referenceImages: Array(cleanReferenceImages),
            identificationProfile: cleanProfile
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
            likelyMatches: Array(cleanLikelyMatches),
            valueQuestions: valueQuestions.compactMap { $0.sanitizedForDisplay() },
            referenceImages: referenceImages.compactMap { $0.sanitizedForDisplay() },
            identificationProfile: currentIdentificationProfile?
                .acceptingLikelyMatch(cleanMatch)
                .sanitizedForDisplay()
        )
    }

    func applyingTargetedScanEvidence(
        _ evidence: NativeScanEvidence?,
        request: TargetedScanRequest
    ) -> AnalyzeIntelligence {
        guard let scanFact = AnalyzeItemFact.targetedScanFact(
            evidence: evidence,
            request: request
        ) else {
            return self
        }

        let retainedFacts = itemFacts.filter { fact in
            fact.label.localizedCaseInsensitiveCompare(scanFact.label) != .orderedSame
        }
        let retainedMissingFacts = missingFacts.filter {
            request.answersMissingFact($0) == false
        }
        let cleanFacts = ([scanFact] + retainedFacts)
            .compactMap { $0.sanitizedForDisplay() }
            .prefix(8)

        return AnalyzeIntelligence(
            itemFacts: Array(cleanFacts),
            missingFacts: retainedMissingFacts,
            photoPrompt: photoPrompt,
            likelyMatches: likelyMatches.compactMap { $0.sanitizedForDisplay() },
            valueQuestions: valueQuestions.compactMap { $0.sanitizedForDisplay() },
            referenceImages: referenceImages.compactMap { $0.sanitizedForDisplay() },
            identificationProfile: currentIdentificationProfile?
                .applyingScannedFact(scanFact, request: request)
                .sanitizedForDisplay()
        )
    }

    func applyingUserAnswers(
        _ answers: ItemDetailAnswers?,
        item: DetectedItem,
        marketplace: Marketplace?
    ) -> AnalyzeIntelligence? {
        let cleanProfile = (currentIdentificationProfile ?? AnalyzeIdentificationProfile())
            .applyingUserAnswers(answers, item: item, marketplace: marketplace)

        return AnalyzeIntelligence(
            itemFacts: itemFacts.compactMap { $0.sanitizedForDisplay() },
            missingFacts: missingFacts,
            photoPrompt: photoPrompt,
            likelyMatches: likelyMatches.compactMap { $0.sanitizedForDisplay() },
            valueQuestions: valueQuestions.compactMap { $0.sanitizedForDisplay() },
            referenceImages: referenceImages.compactMap { $0.sanitizedForDisplay() },
            identificationProfile: cleanProfile
        ).sanitizedForDisplay()
    }

    static func enriching(
        _ analysis: AnalyzeIntelligence?,
        with answers: ItemDetailAnswers?,
        item: DetectedItem,
        marketplace: Marketplace?
    ) -> AnalyzeIntelligence? {
        if let analysis {
            return analysis.applyingUserAnswers(answers, item: item, marketplace: marketplace)
        }

        return AnalyzeIntelligence(
            itemFacts: [],
            missingFacts: [],
            photoPrompt: nil,
            identificationProfile: AnalyzeIdentificationProfile()
                .applyingUserAnswers(answers, item: item, marketplace: marketplace)
        ).sanitizedForDisplay()
    }

    private var currentIdentificationProfile: AnalyzeIdentificationProfile? {
        identificationProfile?.sanitizedForDisplay()
            ?? AnalyzeIdentificationProfile.synthesized(
                itemFacts: itemFacts,
                missingFacts: missingFacts,
                likelyMatches: likelyMatches,
                valueQuestions: valueQuestions
            )
    }

    var photoGuidance: String? {
        if let prompt = photoPrompt?.trimmingCharacters(in: .whitespacesAndNewlines), prompt.isEmpty == false {
            return prompt
        }
        return nil
    }

    var detailGuidance: String? {
        guard let firstMissing = missingFacts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              firstMissing.isEmpty == false
        else { return nil }
        return String.localizedFormat("Check %@ if you know it.".localized, firstMissing)
    }

    var displayHint: String? {
        photoGuidance ?? detailGuidance
    }

    var uncertaintyPrompt: String {
        if referenceImages.isEmpty == false {
            return "Compare these references, then pick what looks closest.".localized
        }
        if likelyMatches.isEmpty == false {
            return "Pick what looks closest, or snap a clearer label.".localized
        }
        if let displayHint {
            return displayHint
        }
        return "Try a closer photo of any logo, label, or model number.".localized
    }

    var targetedScanRequest: TargetedScanRequest? {
        guard let guidance = photoGuidance else { return nil }
        return TargetedScanRequest(
            prompt: guidance,
            benefit: TargetedScanRequest.benefit(for: guidance),
            role: TargetedScanRequest.role(for: guidance)
        )
    }
}

struct TargetedScanRequest: Codable, Equatable, Sendable, Hashable {
    let prompt: String
    let benefit: String
    let role: TargetedScanPhotoRole

    init(prompt: String, benefit: String, role: TargetedScanPhotoRole) {
        self.prompt = Self.clean(prompt, fallback: "Scan the important detail.")
        self.benefit = Self.clean(benefit, fallback: "This can improve the listing.")
        self.role = role
    }

    var title: String {
        let lowercased = prompt.lowercased()
        if lowercased.hasPrefix("scan ") || lowercased.hasPrefix("show ") {
            return prompt
        }
        if lowercased.contains("barcode") {
            return "Scan the barcode".localized
        }
        if lowercased.contains("serial") {
            return "Scan the serial plate".localized
        }
        if lowercased.contains("label") || lowercased.contains("model") {
            return "Scan the model label".localized
        }
        if lowercased.contains("tag") || lowercased.contains("size") {
            return "Scan the size tag".localized
        }
        if lowercased.contains("damage") || lowercased.contains("scratch") || lowercased.contains("flaw") {
            return "Show the damaged area".localized
        }
        return "Scan one more detail".localized
    }

    var systemImage: String {
        switch role {
        case .barcode:
            "barcode.viewfinder"
        case .label, .serial, .sizeTag, .authenticity:
            "text.viewfinder"
        case .condition:
            AppSymbol.Condition.fair
        case .accessories:
            AppSymbol.Marketplace.package
        case .fullItem:
            AppSymbol.Flow.snapPhotoCompact
        }
    }

    static func benefit(for prompt: String) -> String {
        let lowercased = prompt.lowercased()
        if lowercased.contains("price") || lowercased.contains("sold") {
            return "This helps us find closer sold listings.".localized
        }
        if lowercased.contains("flaw") || lowercased.contains("damage") || lowercased.contains("scratch") {
            return "Buyers will want to see this.".localized
        }
        if lowercased.contains("model") || lowercased.contains("barcode") || lowercased.contains("serial") {
            return "This can confirm the exact model.".localized
        }
        return "This may improve your price estimate.".localized
    }

    static func role(for prompt: String) -> TargetedScanPhotoRole {
        let lowercased = prompt.lowercased()
        if lowercased.contains("barcode") || lowercased.contains("qr") {
            return .barcode
        }
        if lowercased.contains("serial") {
            return .serial
        }
        if lowercased.contains("size") || lowercased.contains("tag") {
            return .sizeTag
        }
        if lowercased.contains("authentic") || lowercased.contains("certificate") {
            return .authenticity
        }
        if lowercased.contains("flaw") || lowercased.contains("damage") || lowercased.contains("scratch") {
            return .condition
        }
        if lowercased.contains("box") || lowercased.contains("included") || lowercased.contains("accessor") {
            return .accessories
        }
        if lowercased.contains("label") || lowercased.contains("model") {
            return .label
        }
        return .fullItem
    }

    func answersMissingFact(_ missingFact: String) -> Bool {
        let lowercasedFact = missingFact.lowercased()
        let lowercasedPrompt = prompt.lowercased()
        let tokens = answerTokens + lowercasedPrompt
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
        return tokens.contains { lowercasedFact.contains($0) }
    }

    private var answerTokens: [String] {
        switch role {
        case .barcode:
            return ["barcode", "upc", "ean", "qr"]
        case .label:
            return ["label", "brand", "maker", "model", "logo", "tag"]
        case .serial:
            return ["serial", "s/n", "model", "number"]
        case .sizeTag:
            return ["size", "tag", "label", "material"]
        case .accessories:
            return ["included", "accessories", "box", "charger", "case", "parts"]
        case .condition:
            return ["condition", "damage", "flaw", "scratch", "wear"]
        case .authenticity:
            return ["authentic", "certificate", "edition", "mark", "hallmark", "signature", "serial"]
        case .fullItem:
            return ["full", "whole", "overall", "dimension", "measurement", "size"]
        }
    }

    private static func clean(_ value: String, fallback: String) -> String {
        let cleanValue = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanValue.isEmpty ? fallback.localized : String(cleanValue.prefix(120))
    }
}

private extension AnalyzeItemFact {
    static func targetedScanFact(
        evidence: NativeScanEvidence?,
        request: TargetedScanRequest
    ) -> AnalyzeItemFact? {
        let value: String?
        switch request.role {
        case .barcode:
            let payloads = evidence?.barcodes.map(\.payload).filter { $0.isEmpty == false } ?? []
            value = payloads.isEmpty ? nil : payloads.prefix(2).joined(separator: ", ")
        case .label, .serial, .sizeTag, .authenticity:
            let candidates = evidence?.modelOrSerialCandidates.isEmpty == false
                ? evidence?.modelOrSerialCandidates
                : evidence?.recognizedText
            value = candidates?.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        case .accessories:
            value = "Photo attached."
        case .condition:
            value = "Condition photo attached."
        case .fullItem:
            value = "Full item photo attached."
        }

        guard let value, value.isEmpty == false else { return nil }
        return AnalyzeItemFact(
            label: request.factLabel,
            value: value,
            confidence: 0.95
        ).sanitizedForDisplay()
    }
}

private extension TargetedScanRequest {
    var factLabel: String {
        switch role {
        case .barcode:
            return "Scanned barcode"
        case .label, .serial, .sizeTag, .authenticity:
            return "Scanned detail"
        case .accessories:
            return "Included items"
        case .condition:
            return "Condition detail"
        case .fullItem:
            return "Full item photo"
        }
    }
}

enum TargetedScanPhotoRole: String, Codable, Sendable, Hashable {
    case fullItem
    case label
    case barcode
    case serial
    case sizeTag
    case accessories
    case condition
    case authenticity
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
            "You've analyzed a lot of items today. BuySell needs a little time before the next one. Your saved listings are still available.".localized
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
    let nativeScanEvidence: NativeScanEvidence?
}

private struct GenerateListingRequest: Encodable {
    let item: ListingItemPayload
    let platform: String
    let marketplacePlaybook: MarketplaceListingPlaybookPayload
    let details: ListingItemDetailsPayload?
    let marketplaceComparison: MarketplaceComparisonPayload?
    let identificationProfile: IdentificationProfilePayload?
    let imageDataUrl: String?
}

private struct IdentificationProfilePayload: Encodable {
    let confirmedFacts: [String]
    let likelyFacts: [String]
    let conflictingClues: [String]
    let unknownDetails: [String]
    let possibleMatches: [String]
    let potentiallyValuableVariants: [String]
    let evidenceNeeded: [String]
    let previousCorrections: [String]
    let confidenceState: String

    init?(profile: AnalyzeIdentificationProfile?) {
        guard let profile = profile?.sanitizedForDisplay() else { return nil }
        confirmedFacts = profile.confirmedFacts
        likelyFacts = profile.likelyFacts
        conflictingClues = profile.conflictingClues
        unknownDetails = profile.unknownDetails
        possibleMatches = profile.possibleMatches
        potentiallyValuableVariants = profile.potentiallyValuableVariants
        evidenceNeeded = profile.evidenceNeeded
        previousCorrections = profile.previousCorrections
        confidenceState = profile.confidenceState.rawValue
    }
}

private struct MarketplaceComparisonPayload: Encodable {
    let marketplace: String
    let recommendationLabel: String?
    let marketplaceFitScore: Int?
    let listPrice: Decimal?
    let likelyRangeLow: Decimal?
    let likelyRangeHigh: Decimal?
    let takeHomeEstimate: Decimal?
    let compLowPrice: Decimal?
    let compMedianPrice: Decimal?
    let compHighPrice: Decimal?
    let expectedSpeed: String?
    let shippingExpectation: String?
    let feeSummary: String?
    let reason: String?
    let evidenceSummary: String?
    let evidenceStatus: String
    let evidenceSources: [ListingEvidenceSourcePayload]?

    init?(comparison: MarketplaceComparison, selectedMarketplace: Marketplace) {
        guard comparison.marketplace == selectedMarketplace,
              let sanitized = comparison.sanitizedForDisplay()
        else { return nil }

        marketplace = sanitized.marketplace.rawValue
        recommendationLabel = sanitized.recommendationLabel
        marketplaceFitScore = sanitized.marketplaceFitScore
        listPrice = sanitized.listPrice
        likelyRangeLow = sanitized.likelyRangeLow
        likelyRangeHigh = sanitized.likelyRangeHigh
        takeHomeEstimate = sanitized.takeHomeEstimate
        compLowPrice = sanitized.compLowPrice
        compMedianPrice = sanitized.compMedianPrice
        compHighPrice = sanitized.compHighPrice
        expectedSpeed = sanitized.expectedSpeed
        shippingExpectation = sanitized.shippingExpectation
        feeSummary = sanitized.feeSummary
        reason = sanitized.reason
        evidenceSummary = sanitized.evidenceSummary
        evidenceStatus = sanitized.evidenceStatus.rawValue
        let sources = sanitized.evidenceSources?.map(ListingEvidenceSourcePayload.init(source:))
        evidenceSources = sources?.isEmpty == false ? sources : nil
    }
}

private struct ListingEvidenceSourcePayload: Encodable {
    let sourceMarketplace: String?
    let title: String?
    let url: String?
    let dateChecked: String?
    let listingStatus: String?
    let conditionAndVariant: String?
    let comparability: String?
    let price: Decimal?

    init(source: ListingEvidenceSource) {
        sourceMarketplace = source.sourceMarketplace
        title = source.title
        url = source.url
        dateChecked = source.dateChecked
        listingStatus = source.listingStatus
        conditionAndVariant = source.conditionAndVariant
        comparability = source.comparability
        price = source.price
    }
}

private struct MarketplaceListingPlaybookPayload: Encodable {
    let titleCharacterLimit: Int
    let titleFormula: String
    let descriptionGuidance: String
    let requiredFields: [String]
    let highImpactOptionalFields: [String]
    let recommendedPhotoSequence: [String]
    let pricingFormat: String
    let shippingOrPickupGuidance: String
    let officialPostURLString: String
    let officialHowToURLString: String
    let ruleSourceURLs: [String]
    let ruleSourceLastVerified: String
    let postingSurface: String

    init(playbook: MarketplaceListingPlaybook) {
        titleCharacterLimit = playbook.titleCharacterLimit
        titleFormula = playbook.titleFormula
        descriptionGuidance = playbook.descriptionGuidance
        requiredFields = playbook.requiredFields
        highImpactOptionalFields = playbook.highImpactOptionalFields
        recommendedPhotoSequence = playbook.recommendedPhotoSequence.map(\.rawValue)
        pricingFormat = playbook.pricingFormat
        shippingOrPickupGuidance = playbook.shippingOrPickupGuidance
        officialPostURLString = playbook.officialPostURLString
        officialHowToURLString = playbook.officialHowToURLString
        ruleSourceURLs = playbook.ruleSourceURLs
        ruleSourceLastVerified = playbook.ruleSourceLastVerified
        postingSurface = playbook.postingSurface.rawValue
    }
}

private struct CompareMarketplacesRequest: Encodable {
    let item: ListingItemPayload
    let details: ListingItemDetailsPayload?
    let identificationProfile: IdentificationProfilePayload?
    let candidateMarketplaces: [String]
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
    let marketplaceNotes: [String: String]?
    let isLargeOrFragile: Bool

    init(details: ItemDetailAnswers) {
        labelOrBrand = Self.optional(details.labelOrBrand)
        sizeOrModel = Self.optional(details.sizeOrModel)
        flaws = Self.optional(details.flaws)
        included = Self.optional(details.included)
        extraDetails = Self.optional(details.extraDetails)
        marketplaceNotes = Self.marketplaceNotes(details.marketplaceNotes)
        isLargeOrFragile = details.isLargeOrFragile
    }

    private static func optional(_ value: String) -> String? {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanValue.isEmpty ? nil : cleanValue
    }

    private static func marketplaceNotes(_ values: [Marketplace: String]) -> [String: String]? {
        let cleanValues = values.reduce(into: [String: String]()) { result, entry in
            guard let cleanValue = optional(entry.value) else { return }
            result[entry.key.rawValue] = cleanValue
        }
        return cleanValues.isEmpty ? nil : cleanValues
    }
}

private struct GenerateListingResponse: Decodable {
    let listing: String
    let draft: GeneratedListingDraft?
    let entitlement: EntitlementSnapshot?
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
