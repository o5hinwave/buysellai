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

struct ItemDetailAnswers: Codable, Equatable, Sendable, Hashable {
    var labelOrBrand: String
    var sizeOrModel: String
    var flaws: String
    var included: String
    var extraDetails: String
    var isLargeOrFragile: Bool

    init(
        labelOrBrand: String = "",
        sizeOrModel: String = "",
        flaws: String = "",
        included: String = "",
        extraDetails: String = "",
        isLargeOrFragile: Bool = false
    ) {
        self.labelOrBrand = labelOrBrand
        self.sizeOrModel = sizeOrModel
        self.flaws = flaws
        self.included = included
        self.extraDetails = extraDetails
        self.isLargeOrFragile = isLargeOrFragile
    }

    var sanitizedForUse: ItemDetailAnswers? {
        let clean = ItemDetailAnswers(
            labelOrBrand: Self.clean(labelOrBrand, maxLength: 80),
            sizeOrModel: Self.clean(sizeOrModel, maxLength: 96),
            flaws: Self.clean(flaws, maxLength: 140),
            included: Self.clean(included, maxLength: 120),
            extraDetails: Self.clean(extraDetails, maxLength: 180),
            isLargeOrFragile: isLargeOrFragile
        )
        return clean.hasUsefulDetails ? clean : nil
    }

    var hasUsefulDetails: Bool {
        isLargeOrFragile ||
            labelOrBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            sizeOrModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            flaws.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            included.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            extraDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var displayValues: [String] {
        var values: [String] = []
        appendDisplayValue(labelOrBrand, prefix: "Brand", to: &values)
        appendDisplayValue(sizeOrModel, prefix: "Size/model", to: &values)
        appendDisplayValue(flaws, prefix: "Flaws", to: &values)
        appendDisplayValue(included, prefix: "Includes", to: &values)
        appendDisplayValue(extraDetails, prefix: "Other", to: &values)
        if isLargeOrFragile {
            values.append("Large or fragile")
        }
        return values
    }

    var marketplaceFactQualityBonus: Int {
        min(displayValues.count * 4, 16)
    }

    var localPickupBoost: Int {
        isLargeOrFragile ? 18 : 0
    }

    var shippingPenalty: Int {
        isLargeOrFragile ? 18 : 0
    }

    private static func clean(_ value: String, maxLength: Int) -> String {
        let collapsedWhitespace = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsedWhitespace.prefix(maxLength))
    }

    private func appendDisplayValue(_ value: String, prefix: String, to values: inout [String]) {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanValue.isEmpty == false else { return }
        values.append("\(prefix): \(cleanValue)")
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
            publicImageQuery: clean(publicImageQuery, maxLength: 140)
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
