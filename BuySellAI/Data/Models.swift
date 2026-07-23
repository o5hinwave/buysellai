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

struct MarketplacePickerContext: Identifiable, Equatable {
    let id = UUID()
    let item: DetectedItem
    let imageData: Data
}

struct ListingContext: Identifiable, Equatable {
    let id = UUID()
    let item: DetectedItem
    let imageData: Data?
    let marketplace: Marketplace
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
