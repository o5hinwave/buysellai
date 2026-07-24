import Foundation

struct DetectedItem: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    var category: Category
    var condition: Condition
    var priceEstimate: Decimal
    var currencyCode: String

    init(
        id: UUID = UUID(),
        name: String,
        category: Category,
        condition: Condition,
        priceEstimate: Decimal,
        currencyCode: String = "USD"
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.condition = condition
        self.priceEstimate = priceEstimate
        self.currencyCode = currencyCode
    }
}

enum Category: String, Codable, CaseIterable, Sendable, Hashable {
    case electronics
    case furniture
    case clothing
    case shoes
    case bags
    case jewelry
    case toys
    case kids
    case home
    case tools
    case sports
    case books
    case media
    case music
    case collectibles
    case art
    case other

    var display: String {
        displayKey.localized
    }

    var apiValue: String {
        displayKey
    }

    static func knownAPIValue(_ value: String) -> Category? {
        let normalized = normalizedAPIValue(value)
        return Category.allCases.first {
            normalizedAPIValue($0.rawValue) == normalized ||
            normalizedAPIValue($0.displayKey) == normalized
        }
    }

    private var displayKey: String {
        switch self {
        case .electronics: "Electronics"
        case .furniture: "Furniture"
        case .clothing: "Clothing"
        case .shoes: "Shoes"
        case .bags: "Bags"
        case .jewelry: "Jewelry"
        case .toys: "Toys"
        case .kids: "Kids"
        case .home: "Home"
        case .tools: "Tools"
        case .sports: "Sports"
        case .books: "Books"
        case .media: "Media"
        case .music: "Music"
        case .collectibles: "Collectibles"
        case .art: "Art"
        case .other: "Other"
        }
    }

    init(apiValue: String) {
        self = Self.knownAPIValue(apiValue) ?? .other
    }

    var placeholderSystemImage: String {
        switch self {
        case .electronics:
            "iphone"
        case .furniture, .home:
            "house.fill"
        case .clothing:
            "tshirt.fill"
        case .shoes:
            "shoeprints.fill"
        case .bags:
            "handbag.fill"
        case .jewelry:
            "diamond.fill"
        case .toys:
            "gamecontroller.fill"
        case .kids:
            "figure.2"
        case .tools:
            "wrench.and.screwdriver.fill"
        case .sports:
            "sportscourt.fill"
        case .books:
            "books.vertical.fill"
        case .media:
            "play.rectangle.fill"
        case .music:
            "music.note"
        case .collectibles:
            "star.fill"
        case .art:
            "paintpalette.fill"
        case .other:
            "shippingbox.fill"
        }
    }

    func next() -> Category {
        Self.allCases.next(after: self)
    }

    private static func normalizedAPIValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}

enum Condition: String, Codable, CaseIterable, Sendable, Hashable {
    case new
    case likeNew
    case good
    case fair
    case forParts

    var display: String {
        displayKey.localized
    }

    var apiValue: String {
        rawValue
    }

    static func knownAPIValue(_ value: String) -> Condition? {
        switch normalizedAPIValue(value) {
        case "new": .new
        case "likenew": .likeNew
        case "good": .good
        case "fair": .fair
        case "forparts", "parts", "notworking": .forParts
        default: nil
        }
    }

    private var displayKey: String {
        switch self {
        case .new: "New"
        case .likeNew: "Like New"
        case .good: "Good"
        case .fair: "Fair"
        case .forParts: "For parts"
        }
    }

    init(apiValue: String) {
        self = Self.knownAPIValue(apiValue) ?? .good
    }

    func next() -> Condition {
        Self.allCases.next(after: self)
    }

    private static func normalizedAPIValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}

struct MarketplaceEstimate: Codable, Identifiable, Hashable, Sendable {
    let id: Marketplace
    let payout: Decimal
    let deltaPct: Double
    var badge: EstimateBadge
    var fitScore: Int

    init(
        id: Marketplace,
        payout: Decimal,
        deltaPct: Double,
        badge: EstimateBadge,
        fitScore: Int = 0
    ) {
        self.id = id
        self.payout = payout
        self.deltaPct = deltaPct
        self.badge = badge
        self.fitScore = Self.clampedFitScore(fitScore)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Marketplace.self, forKey: .id)
        payout = try container.decode(Decimal.self, forKey: .payout)
        deltaPct = try container.decode(Double.self, forKey: .deltaPct)
        badge = try container.decode(EstimateBadge.self, forKey: .badge)
        fitScore = Self.clampedFitScore(try container.decodeIfPresent(Int.self, forKey: .fitScore) ?? 0)
    }

    var fitSummary: String? {
        guard fitScore > 0 else {
            return nil
        }

        switch fitScore {
        case 82...100:
            return "Strong fit"
        case 64..<82:
            return "Good fit"
        case 46..<64:
            return "Worth a look"
        default:
            return "More work"
        }
    }

    private static func clampedFitScore(_ value: Int) -> Int {
        min(max(value, 0), 100)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case payout
        case deltaPct
        case badge
        case fitScore
    }
}

struct MarketplaceComparisonResponse: Decodable, Equatable, Sendable {
    let checkedAt: String?
    let comparisons: [MarketplaceComparison]

    var comparisonByMarketplace: [Marketplace: MarketplaceComparison] {
        comparisons.reduce(into: [Marketplace: MarketplaceComparison]()) { result, comparison in
            result[comparison.marketplace] = comparison
        }
    }

    func sanitizedForDisplay() -> MarketplaceComparisonResponse {
        MarketplaceComparisonResponse(
            checkedAt: clean(checkedAt, maxLength: 32),
            comparisons: Array(comparisons.compactMap { $0.sanitizedForDisplay() }.prefix(10))
        )
    }

    private func clean(_ value: String?, maxLength: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return String(trimmed.prefix(maxLength))
    }
}

struct MarketplaceComparison: Decodable, Identifiable, Equatable, Sendable, Hashable {
    let marketplace: Marketplace
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
    let evidenceStatus: EvidenceStatus
    let evidenceSources: [ListingEvidenceSource]?

    enum EvidenceStatus: String, Decodable, Sendable, Hashable {
        case grounded
        case limited
        case unavailable

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = (try? container.decode(String.self))?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            switch value {
            case "grounded", "verified":
                self = .grounded
            case "limited", "partial":
                self = .limited
            default:
                self = .unavailable
            }
        }
    }

    var id: Marketplace { marketplace }

    init(
        marketplace: Marketplace,
        recommendationLabel: String? = nil,
        marketplaceFitScore: Int? = nil,
        listPrice: Decimal? = nil,
        likelyRangeLow: Decimal? = nil,
        likelyRangeHigh: Decimal? = nil,
        takeHomeEstimate: Decimal? = nil,
        compLowPrice: Decimal? = nil,
        compMedianPrice: Decimal? = nil,
        compHighPrice: Decimal? = nil,
        expectedSpeed: String? = nil,
        shippingExpectation: String? = nil,
        feeSummary: String? = nil,
        reason: String? = nil,
        evidenceSummary: String? = nil,
        evidenceStatus: EvidenceStatus = .unavailable,
        evidenceSources: [ListingEvidenceSource]? = nil
    ) {
        self.marketplace = marketplace
        self.recommendationLabel = recommendationLabel
        self.marketplaceFitScore = marketplaceFitScore.map { min(max($0, 1), 100) }
        self.listPrice = listPrice
        self.likelyRangeLow = likelyRangeLow
        self.likelyRangeHigh = likelyRangeHigh
        self.takeHomeEstimate = takeHomeEstimate
        self.compLowPrice = compLowPrice
        self.compMedianPrice = compMedianPrice
        self.compHighPrice = compHighPrice
        self.expectedSpeed = expectedSpeed
        self.shippingExpectation = shippingExpectation
        self.feeSummary = feeSummary
        self.reason = reason
        self.evidenceSummary = evidenceSummary
        self.evidenceStatus = evidenceStatus
        self.evidenceSources = evidenceSources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let marketplaceValue = try container.decode(String.self, forKey: .marketplace)
        guard let marketplace = Marketplace(rawValue: marketplaceValue) else {
            throw DecodingError.dataCorruptedError(
                forKey: .marketplace,
                in: container,
                debugDescription: "Unsupported marketplace"
            )
        }
        self.marketplace = marketplace
        recommendationLabel = try container.decodeIfPresent(String.self, forKey: .recommendationLabel)
        marketplaceFitScore = try container.decodeIfPresent(Int.self, forKey: .marketplaceFitScore)
        listPrice = try container.decodeIfPresent(Decimal.self, forKey: .listPrice)
        likelyRangeLow = try container.decodeIfPresent(Decimal.self, forKey: .likelyRangeLow)
        likelyRangeHigh = try container.decodeIfPresent(Decimal.self, forKey: .likelyRangeHigh)
        takeHomeEstimate = try container.decodeIfPresent(Decimal.self, forKey: .takeHomeEstimate)
        compLowPrice = try container.decodeIfPresent(Decimal.self, forKey: .compLowPrice)
        compMedianPrice = try container.decodeIfPresent(Decimal.self, forKey: .compMedianPrice)
        compHighPrice = try container.decodeIfPresent(Decimal.self, forKey: .compHighPrice)
        expectedSpeed = try container.decodeIfPresent(String.self, forKey: .expectedSpeed)
        shippingExpectation = try container.decodeIfPresent(String.self, forKey: .shippingExpectation)
        feeSummary = try container.decodeIfPresent(String.self, forKey: .feeSummary)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        evidenceSummary = try container.decodeIfPresent(String.self, forKey: .evidenceSummary)
        evidenceStatus = try container.decodeIfPresent(EvidenceStatus.self, forKey: .evidenceStatus) ?? .unavailable
        evidenceSources = try container.decodeIfPresent([ListingEvidenceSource].self, forKey: .evidenceSources)
    }

    func sanitizedForDisplay() -> MarketplaceComparison? {
        let sanitizedSources = cleanEvidenceSources(evidenceSources)
        let displayEvidenceStatus: EvidenceStatus
        if evidenceStatus == .grounded, sanitizedSources?.isEmpty != false {
            displayEvidenceStatus = .limited
        } else {
            displayEvidenceStatus = evidenceStatus
        }

        return MarketplaceComparison(
            marketplace: marketplace,
            recommendationLabel: clean(recommendationLabel, maxLength: 32),
            marketplaceFitScore: marketplaceFitScore.map { min(max($0, 1), 100) },
            listPrice: positive(listPrice),
            likelyRangeLow: positive(likelyRangeLow),
            likelyRangeHigh: positive(likelyRangeHigh),
            takeHomeEstimate: positive(takeHomeEstimate),
            compLowPrice: positive(compLowPrice),
            compMedianPrice: positive(compMedianPrice),
            compHighPrice: positive(compHighPrice),
            expectedSpeed: clean(expectedSpeed, maxLength: 80),
            shippingExpectation: clean(shippingExpectation, maxLength: 100),
            feeSummary: clean(feeSummary, maxLength: 180),
            reason: clean(reason, maxLength: 180),
            evidenceSummary: clean(evidenceSummary, maxLength: 220),
            evidenceStatus: displayEvidenceStatus,
            evidenceSources: sanitizedSources
        )
    }

    func rowSignal(currencyCode: String) -> String? {
        guard evidenceStatus != .unavailable else { return nil }
        let price = listPrice.map { String.localizedFormat("List around %@", $0.currency(code: currencyCode)) }
        let range = soldRange(currencyCode: currencyCode)
        let speed = clean(expectedSpeed, maxLength: 80)
        let shipping = clean(shippingExpectation, maxLength: 100)
        let parts = [price, range, speed, shipping].compactMap { $0 }
        guard parts.isEmpty == false else { return nil }
        return parts.prefix(3).joined(separator: " · ")
    }

    func soldRange(currencyCode: String) -> String? {
        if let low = compLowPrice, let high = compHighPrice {
            return String.localizedFormat("Sold %@-%@", low.currency(code: currencyCode), high.currency(code: currencyCode))
        }
        if let median = compMedianPrice {
            return String.localizedFormat("Typical %@", median.currency(code: currencyCode))
        }
        return nil
    }

    private func clean(_ value: String?, maxLength: Int) -> String? {
        guard let value else { return nil }
        let collapsed = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.isEmpty == false,
              collapsed.contains("```") == false
        else { return nil }
        return String(collapsed.prefix(maxLength))
    }

    private func positive(_ value: Decimal?) -> Decimal? {
        guard let value, value > 0 else { return nil }
        return value.rounded(scale: 2)
    }

    private func cleanEvidenceSources(_ values: [ListingEvidenceSource]?) -> [ListingEvidenceSource]? {
        let cleaned = (values ?? [])
            .compactMap { $0.sanitizedForDisplay() }
            .reduce(into: [ListingEvidenceSource]()) { result, value in
                guard result.contains(where: { $0.id == value.id }) == false, result.count < 4 else { return }
                result.append(value)
            }
        return cleaned.isEmpty ? nil : cleaned
    }

    private enum CodingKeys: String, CodingKey {
        case marketplace
        case recommendationLabel
        case marketplaceFitScore
        case listPrice
        case likelyRangeLow
        case likelyRangeHigh
        case takeHomeEstimate
        case compLowPrice
        case compMedianPrice
        case compHighPrice
        case expectedSpeed
        case shippingExpectation
        case feeSummary
        case reason
        case evidenceSummary
        case evidenceStatus
        case evidenceSources
    }
}

enum EstimateBadge: String, Codable, Sendable {
    case best
    case lowest
    case none
}

struct HistoryEntry: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let createdAt: Date
    let itemName: String
    let category: Category?
    let condition: Condition?
    let suggestedPrice: Decimal?
    let imageThumbnail: Data?
    let marketplace: Marketplace
    let listingText: String

    func sanitizedForHistory() -> HistoryEntry? {
        let cleanItemName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanListingText = (try? ListingTextContract.validatedStored(listingText))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard cleanItemName.isEmpty == false, cleanListingText.isEmpty == false else {
            return nil
        }

        let cleanSuggestedPrice = suggestedPrice.flatMap { $0 > 0 ? $0 : nil }
        return HistoryEntry(
            id: id,
            createdAt: createdAt,
            itemName: cleanItemName,
            category: category,
            condition: condition,
            suggestedPrice: cleanSuggestedPrice,
            imageThumbnail: imageThumbnail,
            marketplace: marketplace,
            listingText: cleanListingText
        )
    }
}

struct GeneratedListing: Sendable, Equatable {
    let listing: String
    let draft: GeneratedListingDraft?

    init(listing: String, draft: GeneratedListingDraft? = nil) {
        self.listing = listing
        self.draft = draft
    }
}

struct ListingEvidenceSource: Codable, Identifiable, Sendable, Equatable, Hashable {
    var sourceMarketplace: String? = nil
    var title: String? = nil
    var url: String? = nil
    var dateChecked: String? = nil
    var listingStatus: String? = nil
    var conditionAndVariant: String? = nil
    var comparability: String? = nil
    var price: Decimal? = nil

    var id: String {
        [
            sourceMarketplace,
            title,
            url,
            dateChecked,
            listingStatus,
            conditionAndVariant,
            comparability,
            price.map { NSDecimalNumber(decimal: $0).stringValue }
        ]
            .compactMap { $0 }
            .joined(separator: "|")
    }

    func sanitizedForDisplay() -> ListingEvidenceSource? {
        let sanitized = ListingEvidenceSource(
            sourceMarketplace: clean(sourceMarketplace, maxLength: 48),
            title: clean(title, maxLength: 120),
            url: cleanReferenceURL(url),
            dateChecked: clean(dateChecked, maxLength: 32),
            listingStatus: clean(listingStatus, maxLength: 32),
            conditionAndVariant: clean(conditionAndVariant, maxLength: 100),
            comparability: clean(comparability, maxLength: 72),
            price: positive(price)
        )

        guard sanitized.sourceMarketplace != nil ||
            sanitized.title != nil ||
            sanitized.url != nil ||
            sanitized.dateChecked != nil ||
            sanitized.listingStatus != nil ||
            sanitized.conditionAndVariant != nil ||
            sanitized.comparability != nil ||
            sanitized.price != nil
        else {
            return nil
        }

        return sanitized
    }

    func detailLine(currencyCode: String) -> String {
        [
            listingStatus,
            price.map { $0.currency(code: currencyCode) },
            conditionAndVariant,
            comparability,
            dateChecked.map { String.localizedFormat("Checked %@", $0) }
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func clean(_ value: String?, maxLength: Int) -> String? {
        guard let value else { return nil }
        let collapsedWhitespace = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsedWhitespace.isEmpty == false,
              collapsedWhitespace.contains("```") == false
        else { return nil }
        return String(collapsedWhitespace.prefix(maxLength))
    }

    private func positive(_ value: Decimal?) -> Decimal? {
        guard let value, value > 0 else { return nil }
        return value.rounded(scale: 2)
    }

    private func cleanReferenceURL(_ value: String?) -> String? {
        guard let cleanURL = clean(value, maxLength: 500),
              let url = URL(string: cleanURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host?.isEmpty == false
        else { return nil }
        return cleanURL
    }
}

enum ItemDetailFieldKey: String, Codable, Sendable, Hashable {
    case labelOrBrand
    case sizeOrModel
    case flaws
    case included
    case extraDetails
    case marketplaceNotes
    case largeOrFragile
}

struct ItemDetailAnswers: Codable, Equatable, Sendable, Hashable {
    var labelOrBrand: String
    var sizeOrModel: String
    var flaws: String
    var included: String
    var extraDetails: String
    var marketplaceNotes: [Marketplace: String]
    var isLargeOrFragile: Bool
    var answeredFieldKeys: [ItemDetailFieldKey]
    var answeredMarketplaces: [Marketplace]

    init(
        labelOrBrand: String = "",
        sizeOrModel: String = "",
        flaws: String = "",
        included: String = "",
        extraDetails: String = "",
        marketplaceNotes: [Marketplace: String] = [:],
        isLargeOrFragile: Bool = false,
        answeredFieldKeys: [ItemDetailFieldKey] = [],
        answeredMarketplaces: [Marketplace] = []
    ) {
        self.labelOrBrand = labelOrBrand
        self.sizeOrModel = sizeOrModel
        self.flaws = flaws
        self.included = included
        self.extraDetails = extraDetails
        self.marketplaceNotes = Self.cleanedMarketplaceNotes(marketplaceNotes)
        self.isLargeOrFragile = isLargeOrFragile
        self.answeredFieldKeys = Self.uniqueFieldKeys(answeredFieldKeys)
        self.answeredMarketplaces = Self.uniqueMarketplaces(answeredMarketplaces)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedMarketplaceNotes = Self.cleanedMarketplaceNotes(
            try container.decodeIfPresent([Marketplace: String].self, forKey: .marketplaceNotes) ?? [:]
        )
        let decodedAnsweredMarketplaces = try container.decodeIfPresent([Marketplace].self, forKey: .answeredMarketplaces) ?? []
        let answerMarketplaces = decodedAnsweredMarketplaces.isEmpty
            ? Array(decodedMarketplaceNotes.keys)
            : decodedAnsweredMarketplaces

        self.init(
            labelOrBrand: try container.decodeIfPresent(String.self, forKey: .labelOrBrand) ?? "",
            sizeOrModel: try container.decodeIfPresent(String.self, forKey: .sizeOrModel) ?? "",
            flaws: try container.decodeIfPresent(String.self, forKey: .flaws) ?? "",
            included: try container.decodeIfPresent(String.self, forKey: .included) ?? "",
            extraDetails: try container.decodeIfPresent(String.self, forKey: .extraDetails) ?? "",
            marketplaceNotes: decodedMarketplaceNotes,
            isLargeOrFragile: try container.decodeIfPresent(Bool.self, forKey: .isLargeOrFragile) ?? false,
            answeredFieldKeys: try container.decodeIfPresent([ItemDetailFieldKey].self, forKey: .answeredFieldKeys) ?? [],
            answeredMarketplaces: answerMarketplaces
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(labelOrBrand, forKey: .labelOrBrand)
        try container.encode(sizeOrModel, forKey: .sizeOrModel)
        try container.encode(flaws, forKey: .flaws)
        try container.encode(included, forKey: .included)
        try container.encode(extraDetails, forKey: .extraDetails)
        try container.encode(marketplaceNotes, forKey: .marketplaceNotes)
        try container.encode(isLargeOrFragile, forKey: .isLargeOrFragile)
        try container.encode(answeredFieldKeys, forKey: .answeredFieldKeys)
        try container.encode(answeredMarketplaces, forKey: .answeredMarketplaces)
    }

    var sanitizedForUse: ItemDetailAnswers? {
        let clean = ItemDetailAnswers(
            labelOrBrand: Self.clean(labelOrBrand, maxLength: 80),
            sizeOrModel: Self.clean(sizeOrModel, maxLength: 96),
            flaws: Self.clean(flaws, maxLength: 140),
            included: Self.clean(included, maxLength: 120),
            extraDetails: Self.clean(extraDetails, maxLength: 180),
            marketplaceNotes: Self.cleanedMarketplaceNotes(marketplaceNotes),
            isLargeOrFragile: isLargeOrFragile,
            answeredFieldKeys: Self.uniqueFieldKeys(answeredFieldKeys),
            answeredMarketplaces: Self.uniqueMarketplaces(answeredMarketplaces)
        )
        return clean.hasUsefulDetails ? clean : nil
    }

    var hasUsefulDetails: Bool {
        hasListingPayloadDetails ||
            answeredFieldKeys.isEmpty == false
    }

    var hasListingPayloadDetails: Bool {
        isLargeOrFragile ||
            labelOrBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            sizeOrModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            flaws.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            included.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            extraDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            marketplaceNotes.values.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
    }

    var displayValues: [String] {
        var values: [String] = []
        appendDisplayValue(labelOrBrand, prefix: "Brand", to: &values)
        appendDisplayValue(sizeOrModel, prefix: "Size/model", to: &values)
        appendDisplayValue(flaws, prefix: "Flaws", to: &values)
        appendDisplayValue(included, prefix: "Includes", to: &values)
        appendDisplayValue(extraDetails, prefix: "Other", to: &values)
        appendMarketplaceNotes(to: &values)
        if isLargeOrFragile {
            values.append("Large or fragile")
        }
        answeredFieldKeys.forEach { field in
            appendHandledValue(field, to: &values)
        }
        return values
    }

    var marketplaceFactQualityBonus: Int {
        min(confirmedDetailCount * 4, 16)
    }

    var localPickupBoost: Int {
        isLargeOrFragile ? 18 : 0
    }

    var shippingPenalty: Int {
        isLargeOrFragile ? 18 : 0
    }

    mutating func markAnswered(_ field: ItemDetailFieldKey) {
        guard answeredFieldKeys.contains(field) == false else { return }
        answeredFieldKeys.append(field)
    }

    mutating func clearAnswered(_ field: ItemDetailFieldKey) {
        answeredFieldKeys.removeAll { $0 == field }
    }

    mutating func setMarketplaceNote(_ value: String, for marketplace: Marketplace) {
        let cleanValue = Self.clean(value, maxLength: 220)
        if cleanValue.isEmpty {
            marketplaceNotes[marketplace] = nil
            answeredMarketplaces.removeAll { $0 == marketplace }
        } else {
            marketplaceNotes[marketplace] = cleanValue
            markMarketplaceAnswered(marketplace)
        }
    }

    mutating func markMarketplaceAnswered(_ marketplace: Marketplace) {
        guard answeredMarketplaces.contains(marketplace) == false else { return }
        answeredMarketplaces.append(marketplace)
    }

    func hasAnsweredOrSkipped(_ field: ItemDetailFieldKey) -> Bool {
        let hasConcreteAnswer: Bool
        switch field {
        case .labelOrBrand:
            hasConcreteAnswer = labelOrBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .sizeOrModel:
            hasConcreteAnswer = sizeOrModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .flaws:
            hasConcreteAnswer = flaws.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .included:
            hasConcreteAnswer = included.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .extraDetails:
            hasConcreteAnswer = extraDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .marketplaceNotes:
            hasConcreteAnswer = marketplaceNotes.values.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        case .largeOrFragile:
            hasConcreteAnswer = false
        }
        return hasConcreteAnswer || answeredFieldKeys.contains(field)
    }

    func marketplaceNote(for marketplace: Marketplace) -> String {
        marketplaceNotes[marketplace] ?? ""
    }

    func hasMarketplaceNoteOrSkipped(_ marketplace: Marketplace) -> Bool {
        marketplaceNote(for: marketplace).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            answeredMarketplaces.contains(marketplace)
    }

    private var confirmedDetailCount: Int {
        [
            labelOrBrand,
            sizeOrModel,
            flaws,
            included,
            extraDetails
        ]
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .count + marketplaceNotes.values.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }.count +
            (isLargeOrFragile ? 1 : 0)
    }

    private static func clean(_ value: String, maxLength: Int) -> String {
        let collapsedWhitespace = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsedWhitespace.prefix(maxLength))
    }

    private static func uniqueFieldKeys(_ values: [ItemDetailFieldKey]) -> [ItemDetailFieldKey] {
        values.reduce(into: [ItemDetailFieldKey]()) { result, value in
            guard result.contains(value) == false else { return }
            result.append(value)
        }
    }

    private static func uniqueMarketplaces(_ values: [Marketplace]) -> [Marketplace] {
        values.reduce(into: [Marketplace]()) { result, value in
            guard result.contains(value) == false else { return }
            result.append(value)
        }
    }

    private static func cleanedMarketplaceNotes(_ values: [Marketplace: String]) -> [Marketplace: String] {
        values.reduce(into: [Marketplace: String]()) { result, entry in
            let cleanValue = clean(entry.value, maxLength: 220)
            guard cleanValue.isEmpty == false else { return }
            result[entry.key] = cleanValue
        }
    }

    private func appendDisplayValue(_ value: String, prefix: String, to values: inout [String]) {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanValue.isEmpty == false else { return }
        values.append("\(prefix): \(cleanValue)")
    }

    private func appendMarketplaceNotes(to values: inout [String]) {
        Marketplace.allCases.forEach { marketplace in
            let cleanValue = marketplaceNote(for: marketplace).trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanValue.isEmpty == false {
                values.append("\(marketplace.displayName): \(cleanValue)")
            } else if answeredMarketplaces.contains(marketplace) {
                values.append("\(marketplace.displayName): \("I don't know".localized)")
            }
        }
    }

    private func appendHandledValue(_ field: ItemDetailFieldKey, to values: inout [String]) {
        guard hasConcreteValue(for: field) == false else { return }
        let value = field == .largeOrFragile ? "No".localized : "I don't know".localized
        values.append("\(displayPrefix(for: field)): \(value)")
    }

    private func hasConcreteValue(for field: ItemDetailFieldKey) -> Bool {
        switch field {
        case .labelOrBrand:
            labelOrBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .sizeOrModel:
            sizeOrModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .flaws:
            flaws.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .included:
            included.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .extraDetails:
            extraDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .marketplaceNotes:
            marketplaceNotes.values.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        case .largeOrFragile:
            isLargeOrFragile
        }
    }

    private func displayPrefix(for field: ItemDetailFieldKey) -> String {
        switch field {
        case .labelOrBrand:
            "Brand"
        case .sizeOrModel:
            "Size/model"
        case .flaws:
            "Flaws"
        case .included:
            "Includes"
        case .extraDetails:
            "Other"
        case .marketplaceNotes:
            "Marketplace"
        case .largeOrFragile:
            "Large or fragile"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case labelOrBrand
        case sizeOrModel
        case flaws
        case included
        case extraDetails
        case marketplaceNotes
        case isLargeOrFragile
        case answeredFieldKeys
        case answeredMarketplaces
    }
}

struct GeneratedListingDraft: Codable, Sendable, Equatable {
    var title: String?
    var description: String?
    var listPrice: Decimal?
    var likelySalePrice: Decimal?
    var takeHomeEstimate: Decimal?
    var firstPhoto: String?
    var missingPhotoPrompt: String?
    var fitReason: String?
    var postingNotes: [String]?
    var itemSpecifics: [String]?
    var tags: [String]?
    var compLowPrice: Decimal? = nil
    var compHighPrice: Decimal? = nil
    var compMedianPrice: Decimal? = nil
    var feeSummary: String? = nil
    var pricingStrategy: String? = nil
    var evidenceSummary: String? = nil
    var referenceImageURL: String? = nil
    var publicImageQuery: String? = nil
    var evidenceSources: [ListingEvidenceSource]? = nil

    var copyableListingText: String? {
        guard let title = clean(title, maxLength: 120),
              let description = clean(description, maxLength: 1_500)
        else { return nil }
        return """
        TITLE:
        \(title)

        DESCRIPTION:
        \(description)
        """
    }

    func sanitizedForDisplay() -> GeneratedListingDraft? {
        let sanitized = GeneratedListingDraft(
            title: clean(title, maxLength: 120),
            description: clean(description, maxLength: 1_500),
            listPrice: positive(listPrice),
            likelySalePrice: positive(likelySalePrice),
            takeHomeEstimate: positive(takeHomeEstimate),
            firstPhoto: clean(firstPhoto, maxLength: 180),
            missingPhotoPrompt: clean(missingPhotoPrompt, maxLength: 140),
            fitReason: clean(fitReason, maxLength: 220),
            postingNotes: cleanList(postingNotes, maxItems: 3, maxLength: 160),
            itemSpecifics: cleanList(itemSpecifics, maxItems: 6, maxLength: 80),
            tags: cleanList(tags, maxItems: 8, maxLength: 40),
            compLowPrice: positive(compLowPrice),
            compHighPrice: positive(compHighPrice),
            compMedianPrice: positive(compMedianPrice),
            feeSummary: clean(feeSummary, maxLength: 180),
            pricingStrategy: clean(pricingStrategy, maxLength: 220),
            evidenceSummary: clean(evidenceSummary, maxLength: 260),
            referenceImageURL: cleanReferenceURL(referenceImageURL),
            publicImageQuery: clean(publicImageQuery, maxLength: 140),
            evidenceSources: cleanEvidenceSources(evidenceSources)
        )

        if sanitized.title == nil,
           sanitized.description == nil,
           sanitized.listPrice == nil,
           sanitized.likelySalePrice == nil,
           sanitized.takeHomeEstimate == nil,
           sanitized.compLowPrice == nil,
           sanitized.compHighPrice == nil,
           sanitized.compMedianPrice == nil,
           sanitized.firstPhoto == nil,
           sanitized.missingPhotoPrompt == nil,
           sanitized.fitReason == nil,
           sanitized.feeSummary == nil,
           sanitized.pricingStrategy == nil,
           sanitized.evidenceSummary == nil,
           sanitized.referenceImageURL == nil,
           sanitized.publicImageQuery == nil,
           sanitized.evidenceSources?.isEmpty ?? true,
           sanitized.postingNotes?.isEmpty ?? true,
           sanitized.itemSpecifics?.isEmpty ?? true,
           sanitized.tags?.isEmpty ?? true {
            return nil
        }

        return sanitized
    }

    private func clean(_ value: String?, maxLength: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              trimmed.contains("```") == false,
              trimmed.range(of: #"^(TITLE|DESCRIPTION)\s*:"#, options: [.regularExpression, .caseInsensitive]) == nil
        else {
            return nil
        }
        return String(trimmed.prefix(maxLength))
    }

    private func cleanList(_ values: [String]?, maxItems: Int, maxLength: Int) -> [String]? {
        let cleaned = (values ?? [])
            .compactMap { clean($0, maxLength: maxLength) }
            .reduce(into: [String]()) { result, value in
                guard result.contains(value) == false, result.count < maxItems else { return }
                result.append(value)
        }
        return cleaned.isEmpty ? nil : cleaned
    }

    private func cleanEvidenceSources(_ values: [ListingEvidenceSource]?) -> [ListingEvidenceSource]? {
        let cleaned = (values ?? [])
            .compactMap { $0.sanitizedForDisplay() }
            .reduce(into: [ListingEvidenceSource]()) { result, value in
                guard result.contains(where: { $0.id == value.id }) == false, result.count < 4 else { return }
                result.append(value)
            }
        return cleaned.isEmpty ? nil : cleaned
    }

    private func positive(_ value: Decimal?) -> Decimal? {
        guard let value, value > 0 else { return nil }
        return value.rounded(scale: 2)
    }

    private func cleanReferenceURL(_ value: String?) -> String? {
        guard let cleanURL = clean(value, maxLength: 500),
              let url = URL(string: cleanURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host?.isEmpty == false
        else { return nil }
        return cleanURL
    }
}

enum ListingTextContract {
    static func validatedGenerated(_ text: String) throws -> String {
        try validated(text, requiresSections: true)
    }

    static func validatedStored(_ text: String) throws -> String {
        try validated(text, requiresSections: true)
    }

    private static func validated(_ text: String, requiresSections: Bool) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              startsWithTitle(trimmed),
              hasMarkdownFence(trimmed) == false,
              hasPreamble(trimmed) == false
        else {
            throw APIError.decoding
        }

        if requiresSections {
            guard hasRequiredListingSections(trimmed) else {
                throw APIError.decoding
            }
        }

        return trimmed
    }

    private static func hasMarkdownFence(_ text: String) -> Bool {
        text.contains("```")
    }

    private static func startsWithTitle(_ text: String) -> Bool {
        text.range(of: #"^TITLE\s*:"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func hasPreamble(_ text: String) -> Bool {
        let normalized = text
            .prefix(96)
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
        return normalized.range(
            of: #"^here(?:'s| is)\s+(?:your\s+)?listing\s*[:\-]"#,
            options: .regularExpression
        ) != nil
    }

    private static func hasRequiredListingSections(_ text: String) -> Bool {
        guard let titleRange = text.range(
            of: #"(?m)^TITLE\s*:"#,
            options: [.regularExpression, .caseInsensitive]
        ),
            let descriptionRange = text[titleRange.upperBound...].range(
                of: #"(?m)^DESCRIPTION\s*:"#,
                options: [.regularExpression, .caseInsensitive]
            )
        else {
            return false
        }

        let titleBody = text[titleRange.upperBound..<descriptionRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionBody = text[descriptionRange.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return titleBody.isEmpty == false && descriptionBody.isEmpty == false
    }
}

#if DEBUG
enum ListingFixtureText {
    static func sample(
        for item: DetectedItem,
        marketplace: Marketplace = .ebay,
        currencyCode: String? = nil
    ) -> String {
        return """
        TITLE:
        \(MarketplaceListingOptimizer.title(for: item, marketplace: marketplace))

        DESCRIPTION:
        \(MarketplaceListingOptimizer.description(for: item, marketplace: marketplace, currencyCode: currencyCode))
        """
    }
}
#endif

struct AuthSession: Codable, Identifiable, Sendable, Hashable {
    let userID: String
    var email: String?
    var accessToken: String?
    var refreshToken: String?
    var appleUserID: String?

    var id: String { userID }

    init(
        userID: String,
        email: String? = nil,
        accessToken: String? = nil,
        refreshToken: String? = nil,
        appleUserID: String? = nil
    ) {
        self.userID = userID
        self.email = email
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.appleUserID = appleUserID
    }
}

enum ThemePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var display: String {
        displayKey.localized
    }

    private var displayKey: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

struct SnapResultContext: Identifiable, Equatable {
    let id = UUID()
    let imageData: Data
    var preferredMarketplace: Marketplace?
}

struct ItemQuestionsContext: Identifiable, Equatable {
    let id = UUID()
    let item: DetectedItem
    let imageData: Data?
    let preferredMarketplace: Marketplace?
    let analysis: AnalyzeIntelligence?
    let answers: ItemDetailAnswers?
}

struct MarketplacePickerContext: Identifiable, Equatable {
    let id = UUID()
    let item: DetectedItem
    let imageData: Data?
    let details: ItemDetailAnswers?
    let analysis: AnalyzeIntelligence?
}

struct ListingContext: Identifiable, Equatable {
    let id = UUID()
    let item: DetectedItem
    let imageData: Data?
    let marketplace: Marketplace
    let details: ItemDetailAnswers?
    let existingListingText: String?
    let existingHistoryEntry: HistoryEntry?
}

extension Array where Element: Equatable {
    func next(after element: Element) -> Element {
        guard let index = firstIndex(of: element) else { return self[0] }
        let nextIndex = self.index(after: index)
        return nextIndex == endIndex ? self[0] : self[nextIndex]
    }
}

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }

    func currency(code: String = "USD", fractionLength: Int = 0) -> String {
        formatted(
            .currency(code: code)
                .precision(.fractionLength(fractionLength))
        )
    }

    func rounded(scale: Int = 0) -> Decimal {
        var input = self
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, .plain)
        return output
    }
}
