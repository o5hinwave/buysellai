import Foundation

struct MarketplaceOptimizationProfile: Sendable, Hashable {
    let titleMaxCharacters: Int
    let titleFormula: String
    let searchFocus: String
    let photoGuidance: String
    let featuredGuidance: String

    private let baselineSearchFit: Int
    private let categoryFits: [Category: Int]
    private let preferredConditions: Set<Condition>
    private let conditionPenalty: Int

    init(
        titleMaxCharacters: Int,
        titleFormula: String,
        searchFocus: String,
        photoGuidance: String,
        featuredGuidance: String,
        baselineSearchFit: Int,
        categoryFits: [Category: Int],
        preferredConditions: Set<Condition>? = nil,
        conditionPenalty: Int = 0
    ) {
        self.titleMaxCharacters = titleMaxCharacters
        self.titleFormula = titleFormula
        self.searchFocus = searchFocus
        self.photoGuidance = photoGuidance
        self.featuredGuidance = featuredGuidance
        self.baselineSearchFit = baselineSearchFit
        self.categoryFits = categoryFits
        self.preferredConditions = preferredConditions ?? Set(Condition.allCases)
        self.conditionPenalty = conditionPenalty
    }

    func searchFit(for item: DetectedItem) -> Int {
        let categoryFit = categoryFits[item.category] ?? baselineSearchFit
        let conditionAdjustment = preferredConditions.contains(item.condition) ? 0 : -conditionPenalty
        return min(max(categoryFit + conditionAdjustment, 1), 100)
    }
}

extension Marketplace {
    var optimizationProfile: MarketplaceOptimizationProfile {
        switch self {
        case .ebay:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand or maker + model + item type + key attribute + condition",
                searchFocus: "Good for shippable items with a broad audience and detailed item pages.",
                photoGuidance: "Use a bright lead photo, then show every angle, labels, model numbers, and flaws.",
                featuredGuidance: "Pay for extra placement only after the details, photos, and price look right.",
                baselineSearchFit: 78,
                categoryFits: [
                    .electronics: 92, .collectibles: 92, .media: 88, .books: 86, .music: 82,
                    .tools: 84, .sports: 86, .toys: 84, .home: 78, .art: 78, .jewelry: 78
                ]
            )
        case .craigslist:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 70,
                titleFormula: "plain item type + brand or size + condition",
                searchFocus: "Best for local pickup and bulky everyday goods where no fee keeps more cash.",
                photoGuidance: "Lead with the full item in a clean space; add size, flaws, and pickup-friendly scale shots.",
                featuredGuidance: "Renew only when allowed, and keep pickup details clear.",
                baselineSearchFit: 58,
                categoryFits: [
                    .furniture: 94, .tools: 90, .home: 86, .sports: 82, .electronics: 72,
                    .kids: 72, .toys: 70
                ]
            )
        case .facebook:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + item type + size or color + condition",
                searchFocus: "Good for quick local interest when the category, price, and condition are clear.",
                photoGuidance: "Make the first photo obvious; add close-ups for flaws, tags, and scale.",
                featuredGuidance: "Pay for local placement only when the photos and price already look right.",
                baselineSearchFit: 76,
                categoryFits: [
                    .furniture: 92, .home: 88, .kids: 88, .toys: 86, .tools: 84, .sports: 84,
                    .electronics: 82, .clothing: 72, .shoes: 72
                ]
            )
        case .poshmark:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + style name + item type + color + size",
                searchFocus: "Good for clothing, shoes, bags, and accessories with clear size and condition details.",
                photoGuidance: "Use a crisp cover shot, then tags, fabric, size, measurements, and flaws.",
                featuredGuidance: "Send an offer after people show interest, and keep the item details complete.",
                baselineSearchFit: 38,
                categoryFits: [.clothing: 96, .shoes: 92, .bags: 92, .jewelry: 82, .kids: 74],
                preferredConditions: [.new, .likeNew, .good],
                conditionPenalty: 18
            )
        case .mercari:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + item type + key attribute + condition",
                searchFocus: "Good for easy shipping on everyday items with accurate details and complete photos.",
                photoGuidance: "Use natural light, a plain background, all sides, and clear flaw photos.",
                featuredGuidance: "Lower the price only after the listing has had time to be seen.",
                baselineSearchFit: 80,
                categoryFits: [
                    .electronics: 88, .toys: 88, .collectibles: 88, .home: 84, .clothing: 82,
                    .shoes: 82, .bags: 82, .kids: 82, .books: 80, .media: 80
                ]
            )
        case .offerup:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "clear item type + brand + key local detail",
                searchFocus: "Good for pickup items and quick neighborhood interest.",
                photoGuidance: "Show exactly what is included, the full item, close-ups, and any damage.",
                featuredGuidance: "Pay for local placement only when the price and first photo are strong.",
                baselineSearchFit: 62,
                categoryFits: [.furniture: 90, .tools: 88, .home: 84, .sports: 84, .electronics: 80, .kids: 76]
            )
        case .depop:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + item type + style + color + size",
                searchFocus: "Good for vintage and style-driven clothing when the item details are accurate.",
                photoGuidance: "Use original photos, fit/detail shots, measurements, and visible wear.",
                featuredGuidance: "Use extra placement only for clearly described fashion items.",
                baselineSearchFit: 32,
                categoryFits: [.clothing: 90, .shoes: 88, .bags: 86, .jewelry: 76],
                preferredConditions: [.new, .likeNew, .good, .fair],
                conditionPenalty: 25
            )
        case .whatnot:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand or set + item type + rarity + condition",
                searchFocus: "Good for collectibles that make sense in a live-sale format.",
                photoGuidance: "Show the front, back, edition marks, flaws, and anything that proves the exact item.",
                featuredGuidance: "Put it in a live show only when the category fit is clear.",
                baselineSearchFit: 44,
                categoryFits: [.collectibles: 88, .toys: 78, .sports: 76, .media: 74, .books: 66]
            )
        case .grailed:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "designer or brand + item name + size + color",
                searchFocus: "Good for menswear, streetwear, and designer items with clear brand, size, and condition.",
                photoGuidance: "Show front/back, tags, fabric labels, measurements, and wear.",
                featuredGuidance: "Drop the price after interest appears, and keep details precise.",
                baselineSearchFit: 28,
                categoryFits: [.clothing: 82, .shoes: 80, .bags: 74, .jewelry: 58],
                preferredConditions: [.new, .likeNew, .good],
                conditionPenalty: 18
            )
        case .reverb:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + model + year or series + instrument type + condition",
                searchFocus: "Good for music gear with exact brand, model, year, function, and condition.",
                photoGuidance: "Show serial/model labels, electronics, hardware, finish wear, and the item working if possible.",
                featuredGuidance: "Use extra placement only after specs, condition, and photos are complete.",
                baselineSearchFit: 22,
                categoryFits: [.music: 100, .electronics: 54, .media: 42],
                preferredConditions: [.new, .likeNew, .good, .fair],
                conditionPenalty: 20
            )
        case .etsy:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 140,
                titleFormula: "clear item name + material or era + color or size",
                searchFocus: "Good for handmade, vintage, art, and craft items with accurate details.",
                photoGuidance: "Lead with a clean product photo; add detail, scale, material, and clear close-ups.",
                featuredGuidance: "Pay for placement only after the details and photos are complete.",
                baselineSearchFit: 48,
                categoryFits: [.art: 92, .jewelry: 88, .home: 84, .collectibles: 78, .clothing: 70, .bags: 66]
            )
        case .stockx:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "exact product name + colorway + size + condition",
                searchFocus: "Good for new authenticated sneakers and collectibles with a precise name, size, and colorway.",
                photoGuidance: "Show box, labels, size tag, soles, and any defects before choosing this marketplace.",
                featuredGuidance: "Use the marketplace ask price mechanics rather than extra listing copy.",
                baselineSearchFit: 18,
                categoryFits: [.shoes: 96, .collectibles: 82],
                preferredConditions: [.new, .likeNew],
                conditionPenalty: 65
            )
        case .goat:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "exact sneaker name + colorway + size + condition",
                searchFocus: "Good for sneakers once the account and item are accepted; document every defect clearly.",
                photoGuidance: "Photograph box, labels, soles, uppers, and every defect clearly.",
                featuredGuidance: "Use GOAT pricing and offer mechanics after approval; avoid vague item names.",
                baselineSearchFit: 18,
                categoryFits: [.shoes: 94, .collectibles: 72],
                preferredConditions: [.new, .likeNew, .good],
                conditionPenalty: 35
            )
        case .kidizen:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + kid size + item type + color + condition",
                searchFocus: "Good for kids items with size, brand, condition, and season written plainly.",
                photoGuidance: "Show front/back, size tags, fabric, stains, and wear.",
                featuredGuidance: "Refresh seasonally when the size and photos are complete.",
                baselineSearchFit: 28,
                categoryFits: [.kids: 96, .toys: 78, .clothing: 72, .shoes: 72]
            )
        case .vinted:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + item type + size + color + condition",
                searchFocus: "Good for simple fashion resale with brand, size, color, and honest condition.",
                photoGuidance: "Show the whole item, size label, material tag, and flaws.",
                featuredGuidance: "Use extra placement only for clean, complete fashion listings.",
                baselineSearchFit: 34,
                categoryFits: [.clothing: 76, .shoes: 74, .bags: 72, .kids: 70, .jewelry: 58],
                preferredConditions: [.new, .likeNew, .good],
                conditionPenalty: 18
            )
        case .vestiaire:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "designer + official item name + size + condition",
                searchFocus: "Good for luxury fashion when brand, authenticity, condition, and photos are clear.",
                photoGuidance: "Show labels, serial or authenticity marks, material, hardware, corners, and wear.",
                featuredGuidance: "Drop the price only after authenticity details are complete.",
                baselineSearchFit: 20,
                categoryFits: [.bags: 94, .jewelry: 86, .clothing: 82, .shoes: 82],
                preferredConditions: [.new, .likeNew, .good],
                conditionPenalty: 24
            )
        case .therealreal:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "designer + item type + material + size",
                searchFocus: "Good for consignment-style luxury items with clear brand, material, authenticity, and condition.",
                photoGuidance: "Capture brand marks, serial labels, hardware, fabric, wear, and authenticity details.",
                featuredGuidance: "Follow the consignment flow; complete documentation matters more than extra placement.",
                baselineSearchFit: 16,
                categoryFits: [.bags: 92, .jewelry: 88, .clothing: 78, .shoes: 78, .art: 62],
                preferredConditions: [.new, .likeNew, .good],
                conditionPenalty: 28
            )
        case .swappa:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + model + storage or carrier + condition",
                searchFocus: "Good for used tech with model, storage, carrier, battery, unlock status, and condition.",
                photoGuidance: "Show the screen on, ports, model/settings, battery health if available, and scratches.",
                featuredGuidance: "Set a fair price first; use extra placement only after verification details are complete.",
                baselineSearchFit: 20,
                categoryFits: [.electronics: 98],
                preferredConditions: [.new, .likeNew, .good, .fair],
                conditionPenalty: 20
            )
        case .tradesy:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "designer + item type + size + color + condition",
                searchFocus: "Good for designer bags, shoes, and clothing with brand, size, color, and condition up front.",
                photoGuidance: "Show labels, hardware, soles, fabric, corners, and signs of wear.",
                featuredGuidance: "Drop the price after interest appears, and keep details directly related to the item.",
                baselineSearchFit: 22,
                categoryFits: [.bags: 90, .shoes: 84, .clothing: 78, .jewelry: 72],
                preferredConditions: [.new, .likeNew, .good],
                conditionPenalty: 22
            )
        case .chairish:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 65,
                titleFormula: "era or maker + material + specific furniture or decor type",
                searchFocus: "Good for vintage furniture and decor with era, maker, material, dimensions, and style.",
                photoGuidance: "Lead with the full piece, then scale, texture, maker marks, dimensions, and damage.",
                featuredGuidance: "Use strong main photos and complete details before paying for placement.",
                baselineSearchFit: 22,
                categoryFits: [.furniture: 98, .home: 92, .art: 86, .jewelry: 54, .collectibles: 62]
            )
        case .bonanza:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + item type + key attribute + condition",
                searchFocus: "Good for general resale when the title and details are straightforward.",
                photoGuidance: "Use clear photos with a simple background, detail shots, and flaw photos.",
                featuredGuidance: "Pay for placement only after photos, details, and price are complete.",
                baselineSearchFit: 62,
                categoryFits: [.collectibles: 74, .home: 70, .electronics: 70, .books: 68, .media: 68]
            )
        case .curtsy:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + item type + size + color + style",
                searchFocus: "Good for mobile fashion sales with brand, size, style, and occasion.",
                photoGuidance: "Show cover, fit, size tag, material, and any wear.",
                featuredGuidance: "Use offers or price changes after interest appears.",
                baselineSearchFit: 24,
                categoryFits: [.clothing: 82, .shoes: 76, .bags: 74, .jewelry: 64],
                preferredConditions: [.new, .likeNew, .good],
                conditionPenalty: 18
            )
        case .nextdoor:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "plain item type + size or brand + condition",
                searchFocus: "Neighborhood sales work for pickup-friendly items and practical household goods.",
                photoGuidance: "Show the whole item, scale, pickup condition, and flaws.",
                featuredGuidance: "Refresh when allowed, and keep pickup details clear.",
                baselineSearchFit: 54,
                categoryFits: [.furniture: 88, .home: 84, .tools: 82, .kids: 80, .sports: 78, .toys: 76]
            )
        case .amazon:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + product line + item type + variant",
                searchFocus: "Good for catalog-like new products with a precise brand, model, and variant.",
                photoGuidance: "Use sharp, simple product photos and the exact product details; avoid used one-off ambiguity.",
                featuredGuidance: "Pay for placement only for catalog-ready items, not casual one-off resale.",
                baselineSearchFit: 24,
                categoryFits: [.books: 78, .media: 74, .electronics: 62, .toys: 60],
                preferredConditions: [.new, .likeNew],
                conditionPenalty: 24
            )
        case .shopify:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 70,
                titleFormula: "brand + product name + key attribute",
                searchFocus: "Good when the person already has a storefront and a complete product page.",
                photoGuidance: "Use a clean product photo set with close-up detail shots.",
                featuredGuidance: "Pay for storefront traffic only when the shop, product page, and checkout are ready.",
                baselineSearchFit: 18,
                categoryFits: [.art: 48, .jewelry: 44, .home: 42, .clothing: 40]
            )
        case .rubylane:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "era + maker + material + item type + condition",
                searchFocus: "Good for antiques and fine art with era, maker, material, provenance, and condition.",
                photoGuidance: "Show maker marks, signatures, materials, scale, condition, and any restoration.",
                featuredGuidance: "Use shop placement only after provenance and condition are complete.",
                baselineSearchFit: 18,
                categoryFits: [.art: 94, .jewelry: 90, .collectibles: 86, .home: 78, .books: 58]
            )
        case .tcgplayer:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "card name + set + number + condition + variant",
                searchFocus: "Good for trading cards with the card name, set, number, variant, and condition.",
                photoGuidance: "Show front/back, corners, surface, centering, and any grading slab.",
                featuredGuidance: "Match the catalog item and set a fair price before paying for placement.",
                baselineSearchFit: 10,
                categoryFits: [.collectibles: 90],
                preferredConditions: [.new, .likeNew, .good, .fair],
                conditionPenalty: 24
            )
        }
    }

    func searchFitScore(for item: DetectedItem) -> Int {
        let baseScore = optimizationProfile.searchFit(for: item)
        let itemName = item.name.lowercased()
        let adjustedScore: Int

        switch (self, item.category) {
        case (.poshmark, .clothing), (.poshmark, .shoes), (.poshmark, .bags):
            adjustedScore = baseScore + (itemName.containsFashionClosetSignal ? 8 : 0)
        case (.depop, .clothing), (.depop, .shoes), (.depop, .bags):
            adjustedScore = itemName.containsTrendResaleSignal ? baseScore : baseScore - 16
        default:
            adjustedScore = baseScore
        }

        return min(max(adjustedScore, 1), 100)
    }

    func recommendationReason(for item: DetectedItem) -> String {
        switch (self, item.category) {
        case (.reverb, .music):
            "Good for music gear when brand, model, condition, and playability are clear."
        case (.swappa, .electronics):
            "Good for tech when model, storage, carrier, battery, unlock status, and scratches are clear."
        case (.chairish, .furniture), (.chairish, .home):
            "Good for home pieces when style, era, material, dimensions, and the main photo are clear."
        case (.poshmark, .clothing), (.poshmark, .shoes), (.poshmark, .bags):
            "Good for fashion when brand, size, style, color, material, and condition are clear."
        case (.stockx, .shoes), (.goat, .shoes):
            "Good for sneakers when the name, size, box details, and condition are clear."
        default:
            optimizationProfile.searchFocus
        }
    }
}

private extension String {
    var containsFashionClosetSignal: Bool {
        contains("women") ||
            contains("madewell") ||
            contains("j.crew") ||
            contains("anthropologie") ||
            contains("lululemon") ||
            contains("free people") ||
            contains("zara") ||
            contains("medium") ||
            contains("small") ||
            contains("large")
    }

    var containsTrendResaleSignal: Bool {
        contains("vintage") ||
            contains("y2k") ||
            contains("streetwear") ||
            contains("90s") ||
            contains("00s") ||
            contains("goth") ||
            contains("punk") ||
            contains("harajuku") ||
            contains("rare")
    }
}

enum MarketplaceListingOptimizer {
    static func title(for item: DetectedItem, marketplace: Marketplace) -> String {
        let displayName = cleanItemName(item.name)
        var parts = [displayName]
        let condition = item.condition.display
        if displayName.localizedCaseInsensitiveContains(condition) == false {
            parts.append(condition)
        }
        let category = item.category.display
        if shouldIncludeCategory(item.category, for: marketplace),
           displayName.localizedCaseInsensitiveContains(category) == false {
            parts.append(category)
        }
        return truncate(parts.joined(separator: " - "), maxCharacters: marketplace.optimizationProfile.titleMaxCharacters)
    }

    static func description(for item: DetectedItem, marketplace: Marketplace, currencyCode: String? = nil) -> String {
        let displayName = cleanItemName(item.name)
        let resolvedCurrencyCode = (currencyCode ?? item.currencyCode).trimmingCharacters(in: .whitespacesAndNewlines)
        let price = item.priceEstimate.currency(code: resolvedCurrencyCode.isEmpty ? "USD" : resolvedCurrencyCode)
        let condition = item.condition.display.lowercased()
        return [
            "\(displayName) in \(condition) condition.",
            "Asking \(price).",
            detailSentence(for: item.category, marketplace: marketplace)
        ].joined(separator: " ")
    }

    private static func cleanItemName(_ name: String) -> String {
        let itemName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return itemName.isEmpty ? "Item" : itemName
    }

    private static func shouldIncludeCategory(_ category: Category, for marketplace: Marketplace) -> Bool {
        switch marketplace {
        case .poshmark, .depop, .grailed, .vinted, .vestiaire, .tradesy, .curtsy,
             .stockx, .goat, .reverb, .chairish, .swappa, .tcgplayer:
            false
        default:
            category != .other
        }
    }

    private static func detailSentence(for category: Category, marketplace: Marketplace) -> String {
        switch (marketplace, category) {
        case (.reverb, _):
            "Photos should show the model, hardware, cosmetic wear, and working details."
        case (.swappa, _):
            "Photos should show the screen, ports, model details, and any scratches."
        case (.chairish, _):
            "Photos should show scale, materials, maker marks, dimensions, and wear."
        case (.poshmark, _), (.depop, _), (.grailed, _), (.vinted, _), (.curtsy, _):
            "Photos should show fit, tags, fabric, color, measurements, and wear."
        case (.stockx, _), (.goat, _):
            "Photos should show box, labels, size, soles, and any defects."
        case (_, .furniture), (_, .tools), (_, .home):
            "Photos should show the full item, scale, close-ups, and any flaws."
        default:
            "See photos for condition and details."
        }
    }

    private static func truncate(_ value: String, maxCharacters: Int) -> String {
        guard value.count > maxCharacters else {
            return value
        }
        let prefix = String(value.prefix(maxCharacters))
        let wordBoundary = prefix.split(separator: " ").dropLast().joined(separator: " ")
        return wordBoundary.isEmpty ? prefix : wordBoundary
    }
}
