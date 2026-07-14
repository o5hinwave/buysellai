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
        let normalized = apiValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        self = Category.allCases.first {
            $0.rawValue.replacingOccurrences(of: "_", with: "") == normalized ||
            $0.display.lowercased().replacingOccurrences(of: " ", with: "") == normalized
        } ?? .other
    }

    func next() -> Category {
        Self.allCases.next(after: self)
    }
}

enum Condition: String, Codable, CaseIterable, Sendable, Hashable {
    case new
    case likeNew
    case good
    case fair
    case forParts

    var display: String {
        switch self {
        case .new: "New"
        case .likeNew: "Like New"
        case .good: "Good"
        case .fair: "Fair"
        case .forParts: "For parts"
        }
    }

    init(apiValue: String) {
        let normalized = apiValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
        switch normalized {
        case "new": self = .new
        case "likenew": self = .likeNew
        case "good": self = .good
        case "fair": self = .fair
        case "forparts", "parts", "notworking": self = .forParts
        default: self = .good
        }
    }

    func next() -> Condition {
        Self.allCases.next(after: self)
    }
}

struct MarketplaceEstimate: Identifiable, Hashable, Sendable {
    let id: Marketplace
    let payout: Decimal
    let deltaPct: Double
    var badge: EstimateBadge
}

enum EstimateBadge: String, Sendable {
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
}

struct AuthSession: Codable, Sendable, Hashable {
    let userID: String
    var email: String?
    var accessToken: String?
    var refreshToken: String?

    init(userID: String, email: String? = nil, accessToken: String? = nil, refreshToken: String? = nil) {
        self.userID = userID
        self.email = email
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

enum ThemePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var display: String {
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
        doubleValue.formatted(
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
