import Foundation

struct MarketplaceOptimizationProfile: Sendable, Hashable {
    let titleMaxCharacters: Int
    let titleFormula: String
    let searchFocus: String
    let photoGuidance: String
    let featuredGuidance: String
    let listingEffortScore: Int
    let buyerTrustScore: Int
    let localPickupScore: Int
    let shippingEaseScore: Int
    let speedScore: Int

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
        listingEffortScore: Int = 68,
        buyerTrustScore: Int = 68,
        localPickupScore: Int = 18,
        shippingEaseScore: Int = 72,
        speedScore: Int = 62,
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
        self.listingEffortScore = Self.clamped(listingEffortScore)
        self.buyerTrustScore = Self.clamped(buyerTrustScore)
        self.localPickupScore = Self.clamped(localPickupScore)
        self.shippingEaseScore = Self.clamped(shippingEaseScore)
        self.speedScore = Self.clamped(speedScore)
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

    func listingEffort(for item: DetectedItem) -> Int {
        let categoryAdjustment: Int
        switch item.category {
        case .other:
            categoryAdjustment = -8
        case .collectibles, .art, .jewelry:
            categoryAdjustment = -4
        default:
            categoryAdjustment = 0
        }

        return Self.clamped(listingEffortScore + categoryAdjustment)
    }

    func buyerTrust(for item: DetectedItem) -> Int {
        let conditionAdjustment: Int
        switch item.condition {
        case .new, .likeNew:
            conditionAdjustment = 4
        case .good:
            conditionAdjustment = 0
        case .fair:
            conditionAdjustment = -6
        case .forParts:
            conditionAdjustment = -16
        }

        return Self.clamped(buyerTrustScore + conditionAdjustment)
    }

    func localPickupFit(for item: DetectedItem) -> Int {
        weightedScore(neutral: 58, target: localPickupScore, intensity: item.localPickupNeedScore)
    }

    func shippingFit(for item: DetectedItem) -> Int {
        let platformAndItemFit = Int((Double(shippingEaseScore) * 0.56 + Double(item.shippingEaseScore) * 0.44).rounded())

        if item.localPickupNeedScore >= 74, localPickupScore >= 82 {
            return max(platformAndItemFit, 88)
        }

        if item.localPickupNeedScore >= 74, localPickupScore <= 24 {
            return min(platformAndItemFit, 48)
        }

        return Self.clamped(platformAndItemFit)
    }

    private func weightedScore(neutral: Int, target: Int, intensity: Int) -> Int {
        let clampedIntensity = Double(Self.clamped(intensity)) / 100
        let value = Double(neutral) + (Double(target - neutral) * clampedIntensity)
        return Self.clamped(Int(value.rounded()))
    }

    private static func clamped(_ value: Int) -> Int {
        min(max(value, 1), 100)
    }
}

struct MarketplaceListingPlaybook: Sendable, Hashable {
    let version: MarketplacePlaybookVersion
    let marketplace: Marketplace
    let titleCharacterLimit: Int
    let titleFormula: String
    let descriptionGuidance: String
    let requiredFields: [String]
    let highImpactOptionalFields: [String]
    let recommendedPhotoSequence: [ItemPhotoRole]
    let pricingFormat: String
    let shippingOrPickupGuidance: String
    let feeModelSourceTitle: String
    let feeModelLastChecked: String
    let officialPostURLString: String
    let officialHowToURLString: String
    let ruleSourceURLs: [String]
    let ruleSourceLastVerified: String
    let postingSurface: MarketplacePostingSurface
}

struct MarketplacePlaybookVersion: Sendable, Hashable {
    static let current = MarketplacePlaybookVersion(
        identifier: "marketplace-playbook-v1-2026-07-25",
        schemaVersion: 1,
        feeSourcesLastChecked: "2026-07-23",
        ruleSourcesLastVerified: "2026-07-25"
    )

    let identifier: String
    let schemaVersion: Int
    let feeSourcesLastChecked: String
    let ruleSourcesLastVerified: String
}

extension Marketplace {
    var listingPlaybook: MarketplaceListingPlaybook {
        let profile = optimizationProfile
        let evidence = playbookEvidence
        let destination = postingDestination

        return MarketplaceListingPlaybook(
            version: .current,
            marketplace: self,
            titleCharacterLimit: profile.titleMaxCharacters,
            titleFormula: profile.titleFormula,
            descriptionGuidance: profile.featuredGuidance,
            requiredFields: listingRequiredFields,
            highImpactOptionalFields: highImpactListingFields,
            recommendedPhotoSequence: recommendedPhotoSequence,
            pricingFormat: "List at, likely sells for, take-home estimate, and lowest fair offer.",
            shippingOrPickupGuidance: listingShippingOrPickupGuidance,
            feeModelSourceTitle: evidence.feeModelSourceTitle,
            feeModelLastChecked: evidence.feeModelLastChecked,
            officialPostURLString: destination.postURLString,
            officialHowToURLString: destination.howToURLString,
            ruleSourceURLs: Self.uniqueSourceURLs([
                destination.howToURLString,
                evidence.feeModelSourceURL
            ]),
            ruleSourceLastVerified: destination.lastChecked,
            postingSurface: destination.postingSurface
        )
    }

    private var listingRequiredFields: [String] {
        switch self {
        case .ebay:
            ["Title", "Category", "Condition", "Item specifics", "Model or product identifier", "Shipping or pickup"]
        case .craigslist:
            ["Title", "Price", "Pickup area", "Condition", "Full-item photo"]
        case .facebook:
            ["Title", "Price", "Category", "Condition", "Pickup area", "Photos"]
        case .poshmark:
            ["Brand", "Category", "Size", "Condition", "Cover photo", "Description"]
        case .mercari:
            ["Title", "Category", "Brand when known", "Condition", "Price", "Shipping choice", "Photos"]
        case .offerup:
            ["Title", "Price", "Category", "Condition", "Pickup or shipping preference", "Photos"]
        case .depop:
            ["Brand when known", "Size", "Condition", "Category", "Price", "Photos"]
        case .whatnot:
            ["Category", "Item identity", "Condition", "Starting price", "Photo or live-sale asset"]
        case .grailed:
            ["Designer or brand", "Size", "Condition", "Category", "Measurements or fit notes", "Photos"]
        case .reverb:
            ["Brand", "Model", "Year when known", "Condition", "Working status", "Shipping safety", "Photos"]
        case .etsy:
            ["Handmade, vintage, or supply fit", "Title", "Category", "Materials", "Price", "Photos"]
        case .stockx:
            ["Exact model", "Style code or SKU", "Size", "Box condition", "Authenticity details"]
        case .goat:
            ["Exact model", "Style code or SKU", "Size", "Box condition", "Authenticity details"]
        case .kidizen:
            ["Marketplace unavailable"]
        case .vinted:
            ["Brand when known", "Size", "Condition", "Category", "Price", "Photos"]
        case .vestiaire:
            ["Brand", "Category", "Condition", "Authenticity details", "Materials", "Photos"]
        case .therealreal:
            ["Brand", "Category", "Condition", "Authenticity details", "Consignment handoff details"]
        case .swappa:
            ["Exact device", "Storage", "Carrier or unlocked status", "Battery condition", "Functional checks", "Photos"]
        case .tradesy:
            ["Marketplace unavailable"]
        case .chairish:
            ["Title", "Dimensions", "Materials", "Maker or period when known", "Condition", "Freight or pickup notes", "Photos"]
        case .bonanza:
            ["Title", "Category", "Condition", "Price", "Shipping", "Photos"]
        case .curtsy:
            ["Brand", "Size", "Condition", "Category", "Price", "Photos"]
        case .nextdoor:
            ["Title", "Price", "Pickup area", "Condition", "Photos"]
        case .amazon:
            ["Product identifier", "Condition", "Category", "Fulfillment choice", "Account fit"]
        case .shopify:
            ["Product title", "Price", "Description", "Photos", "Fulfillment notes"]
        case .rubylane:
            ["Title", "Category", "Age or maker", "Condition", "Materials", "Photos"]
        case .tcgplayer:
            ["Set", "Card number", "Printing or finish", "Language", "Condition", "Photos"]
        }
    }

    private var highImpactListingFields: [String] {
        switch self {
        case .facebook, .craigslist, .offerup, .nextdoor:
            ["Negotiability", "Delivery availability", "Dimensions", "Flaw notes"]
        case .poshmark, .depop, .grailed, .vinted, .curtsy:
            ["Measurements", "Fabric or material", "Style keywords", "Flaws"]
        case .stockx, .goat:
            ["Receipt or provenance", "Original box photos", "Sole and label photos"]
        case .reverb:
            ["Serial number", "Included accessories", "Cosmetic wear", "Packing plan"]
        case .swappa:
            ["IMEI-safe verification", "Battery health", "Activation lock status", "Ports and scratches"]
        case .chairish, .rubylane:
            ["Maker marks", "Period", "Restoration notes", "Scale photo"]
        case .tcgplayer:
            ["Centering", "Surface flaws", "Grading slab", "Edition notes"]
        default:
            ["Brand", "Model", "Dimensions", "Included accessories", "Visible flaws"]
        }
    }

    private var recommendedPhotoSequence: [ItemPhotoRole] {
        switch self {
        case .stockx, .goat:
            [.cover, .label, .included, .condition]
        case .swappa, .reverb:
            [.cover, .label, .condition, .included]
        case .chairish, .rubylane:
            [.cover, .fullItem, .label, .condition]
        case .facebook, .craigslist, .offerup, .nextdoor:
            [.cover, .fullItem, .condition]
        case .tcgplayer:
            [.cover, .condition, .label]
        default:
            [.cover, .fullItem, .label, .included, .condition]
        }
    }

    private var listingShippingOrPickupGuidance: String {
        switch self {
        case .facebook, .craigslist, .offerup, .nextdoor:
            "Use pickup first. Add nearby area, delivery availability, and whether price is firm."
        case .chairish:
            "Call out dimensions and whether local pickup, freight, or buyer-arranged shipping is best."
        case .therealreal:
            "Treat as consignment handoff rather than a normal self-posted listing."
        case .stockx, .goat, .swappa, .reverb, .tcgplayer:
            "Package carefully and include platform-required condition or authenticity details before posting."
        default:
            "Use the marketplace shipping flow unless the item is large, fragile, or local-pickup friendly."
        }
    }

    private static func uniqueSourceURLs(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { result, value in
            guard result.contains(value) == false else { return }
            result.append(value)
        }
    }
}

extension DetectedItem {
    var localPickupNeedScore: Int {
        switch category {
        case .furniture:
            96
        case .tools:
            nameContainsAny(["ladder", "saw", "compressor", "tool box", "bench"]) ? 86 : 72
        case .home:
            nameContainsAny(["mirror", "lamp", "vase", "glass", "ceramic", "frame", "large", "set"])
                ? 72
                : 56
        case .sports:
            nameContainsAny(["bike", "bicycle", "treadmill", "bench", "weights", "golf bag"]) ? 82 : 52
        case .music:
            nameContainsAny(["guitar", "amp", "amplifier", "keyboard", "drum"]) ? 58 : 34
        case .art:
            nameContainsAny(["framed", "canvas", "large", "glass"]) ? 62 : 42
        case .electronics:
            nameContainsAny(["tv", "television", "monitor", "speaker", "receiver"]) ? 60 : 24
        case .kids, .toys:
            nameContainsAny(["stroller", "crib", "bike", "playhouse", "wagon"]) ? 84 : 38
        case .books, .media, .clothing, .shoes, .bags, .jewelry, .collectibles:
            16
        case .other:
            nameContainsAny(["large", "heavy", "fragile", "glass", "set"]) ? 66 : 44
        }
    }

    var shippingEaseScore: Int {
        switch category {
        case .clothing, .shoes, .bags:
            92
        case .books, .media:
            84
        case .jewelry:
            82
        case .electronics:
            nameContainsAny(["tv", "television", "monitor", "speaker", "receiver"]) ? 46 : 74
        case .collectibles:
            nameContainsAny(["graded", "card", "coin", "pin"]) ? 86 : 66
        case .kids, .toys:
            nameContainsAny(["stroller", "crib", "bike", "playhouse", "wagon"]) ? 36 : 70
        case .music:
            nameContainsAny(["guitar", "amp", "amplifier", "keyboard", "drum"]) ? 42 : 64
        case .sports:
            nameContainsAny(["bike", "bicycle", "treadmill", "bench", "weights", "golf bag"]) ? 34 : 62
        case .home:
            nameContainsAny(["mirror", "lamp", "vase", "glass", "ceramic", "frame", "large", "set"]) ? 38 : 62
        case .tools:
            nameContainsAny(["ladder", "compressor", "tool box", "bench"]) ? 36 : 54
        case .art:
            nameContainsAny(["framed", "canvas", "large", "glass"]) ? 36 : 58
        case .furniture:
            18
        case .other:
            nameContainsAny(["large", "heavy", "fragile", "glass", "set"]) ? 38 : 56
        }
    }

    var marketplaceFactQualityScore: Int {
        let words = normalizedMarketplaceName
            .split { $0.isWhitespace || $0.isPunctuation }
            .count
        let wordScore: Int
        switch words {
        case 0:
            wordScore = 28
        case 1:
            wordScore = 46
        case 2:
            wordScore = 62
        case 3:
            wordScore = 76
        default:
            wordScore = 88
        }

        let categoryScore = category == .other ? -14 : 0
        let conditionScore = condition == .forParts ? -8 : 0
        return min(max(wordScore + categoryScore + conditionScore, 1), 100)
    }

    private var normalizedMarketplaceName: String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func nameContainsAny(_ fragments: [String]) -> Bool {
        let normalized = normalizedMarketplaceName
        return fragments.contains { normalized.contains($0) }
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
                featuredGuidance: "Post once the photos, details, and price feel clear.",
                listingEffortScore: 64,
                buyerTrustScore: 82,
                shippingEaseScore: 78,
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
                listingEffortScore: 96,
                buyerTrustScore: 56,
                localPickupScore: 96,
                shippingEaseScore: 92,
                speedScore: 86,
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
                featuredGuidance: "Post once the first photo and price feel clear.",
                listingEffortScore: 90,
                buyerTrustScore: 64,
                localPickupScore: 92,
                shippingEaseScore: 88,
                speedScore: 86,
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
                featuredGuidance: "Send an offer later if needed, and keep the item details complete.",
                listingEffortScore: 74,
                buyerTrustScore: 74,
                localPickupScore: 12,
                shippingEaseScore: 82,
                speedScore: 68,
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
                featuredGuidance: "Wait a bit before lowering the price, then keep the change small.",
                listingEffortScore: 82,
                buyerTrustScore: 70,
                localPickupScore: 14,
                shippingEaseScore: 86,
                speedScore: 74,
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
                featuredGuidance: "Post once the price and first photo feel clear.",
                listingEffortScore: 88,
                buyerTrustScore: 58,
                localPickupScore: 94,
                shippingEaseScore: 88,
                speedScore: 84,
                baselineSearchFit: 62,
                categoryFits: [.furniture: 90, .tools: 88, .home: 84, .sports: 84, .electronics: 80, .kids: 76]
            )
        case .depop:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + item type + style + color + size",
                searchFocus: "Good for vintage and style-driven clothing when the item details are accurate.",
                photoGuidance: "Use original photos, fit/detail shots, measurements, and visible wear.",
                featuredGuidance: "Post style items only when the photos and details are clear.",
                listingEffortScore: 70,
                buyerTrustScore: 62,
                localPickupScore: 10,
                shippingEaseScore: 82,
                speedScore: 66,
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
                listingEffortScore: 42,
                buyerTrustScore: 62,
                localPickupScore: 8,
                shippingEaseScore: 54,
                speedScore: 38,
                baselineSearchFit: 44,
                categoryFits: [.collectibles: 88, .toys: 78, .sports: 76, .media: 74, .books: 66]
            )
        case .grailed:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "designer or brand + item name + size + color",
                searchFocus: "Good for menswear, streetwear, and designer items with clear brand, size, and condition.",
                photoGuidance: "Show front/back, tags, fabric labels, measurements, and wear.",
                featuredGuidance: "Keep details precise, then lower the price later if needed.",
                listingEffortScore: 58,
                buyerTrustScore: 70,
                localPickupScore: 8,
                shippingEaseScore: 76,
                speedScore: 54,
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
                featuredGuidance: "Post after specs, condition, and photos are complete.",
                listingEffortScore: 62,
                buyerTrustScore: 80,
                localPickupScore: 8,
                shippingEaseScore: 68,
                speedScore: 58,
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
                featuredGuidance: "Post after the details and photos are complete.",
                listingEffortScore: 56,
                buyerTrustScore: 72,
                localPickupScore: 8,
                shippingEaseScore: 66,
                speedScore: 52,
                baselineSearchFit: 48,
                categoryFits: [.art: 92, .jewelry: 88, .home: 84, .collectibles: 78, .clothing: 70, .bags: 66]
            )
        case .stockx:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "exact product name + colorway + size + condition",
                searchFocus: "Good for new authenticated sneakers and collectibles with a precise name, size, and colorway.",
                photoGuidance: "Show box, labels, size tag, soles, and any defects before choosing this marketplace.",
                featuredGuidance: "Use the marketplace price tools instead of adding extra copy.",
                listingEffortScore: 66,
                buyerTrustScore: 88,
                localPickupScore: 4,
                shippingEaseScore: 78,
                speedScore: 58,
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
                featuredGuidance: "Use GOAT price and offer tools after approval; keep item names exact.",
                listingEffortScore: 62,
                buyerTrustScore: 86,
                localPickupScore: 4,
                shippingEaseScore: 76,
                speedScore: 54,
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
                listingEffortScore: 72,
                buyerTrustScore: 66,
                localPickupScore: 12,
                shippingEaseScore: 80,
                speedScore: 64,
                baselineSearchFit: 28,
                categoryFits: [.kids: 96, .toys: 78, .clothing: 72, .shoes: 72]
            )
        case .vinted:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + item type + size + color + condition",
                searchFocus: "Good for simple fashion resale with brand, size, color, and honest condition.",
                photoGuidance: "Show the whole item, size label, material tag, and flaws.",
                featuredGuidance: "Post only when the fashion details and photos are complete.",
                listingEffortScore: 82,
                buyerTrustScore: 64,
                localPickupScore: 10,
                shippingEaseScore: 82,
                speedScore: 70,
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
                listingEffortScore: 50,
                buyerTrustScore: 86,
                localPickupScore: 6,
                shippingEaseScore: 72,
                speedScore: 46,
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
                featuredGuidance: "Follow the consignment flow; complete documentation matters most.",
                listingEffortScore: 46,
                buyerTrustScore: 88,
                localPickupScore: 4,
                shippingEaseScore: 70,
                speedScore: 40,
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
                featuredGuidance: "Set a fair price first; include verification details before posting.",
                listingEffortScore: 76,
                buyerTrustScore: 82,
                localPickupScore: 8,
                shippingEaseScore: 82,
                speedScore: 68,
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
                featuredGuidance: "Keep details directly related to the item, then adjust price later if needed.",
                listingEffortScore: 58,
                buyerTrustScore: 74,
                localPickupScore: 8,
                shippingEaseScore: 76,
                speedScore: 54,
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
                featuredGuidance: "Use strong main photos and complete details before posting.",
                listingEffortScore: 54,
                buyerTrustScore: 78,
                localPickupScore: 62,
                shippingEaseScore: 44,
                speedScore: 52,
                baselineSearchFit: 22,
                categoryFits: [.furniture: 98, .home: 92, .art: 86, .jewelry: 54, .collectibles: 62]
            )
        case .bonanza:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + item type + key attribute + condition",
                searchFocus: "Good for general resale when the title and details are straightforward.",
                photoGuidance: "Use clear photos with a simple background, detail shots, and flaw photos.",
                featuredGuidance: "Post after photos, details, and price are complete.",
                listingEffortScore: 66,
                buyerTrustScore: 64,
                localPickupScore: 10,
                shippingEaseScore: 72,
                speedScore: 56,
                baselineSearchFit: 62,
                categoryFits: [.collectibles: 74, .home: 70, .electronics: 70, .books: 68, .media: 68]
            )
        case .curtsy:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + item type + size + color + style",
                searchFocus: "Good for mobile fashion sales with brand, size, style, and occasion.",
                photoGuidance: "Show cover, fit, size tag, material, and any wear.",
                featuredGuidance: "Use offers or price changes later if needed.",
                listingEffortScore: 76,
                buyerTrustScore: 62,
                localPickupScore: 10,
                shippingEaseScore: 82,
                speedScore: 68,
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
                listingEffortScore: 86,
                buyerTrustScore: 60,
                localPickupScore: 94,
                shippingEaseScore: 88,
                speedScore: 82,
                baselineSearchFit: 54,
                categoryFits: [.furniture: 88, .home: 84, .tools: 82, .kids: 80, .sports: 78, .toys: 76]
            )
        case .amazon:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "brand + product line + item type + variant",
                searchFocus: "Good for catalog-like new products with a precise brand, model, and variant.",
                photoGuidance: "Use sharp, simple product photos and the exact product details; avoid used one-off ambiguity.",
                featuredGuidance: "Use Amazon only for catalog-ready items, not casual one-off resale.",
                listingEffortScore: 28,
                buyerTrustScore: 62,
                localPickupScore: 2,
                shippingEaseScore: 58,
                speedScore: 42,
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
                featuredGuidance: "Use this only when the shop, product page, and checkout are ready.",
                listingEffortScore: 18,
                buyerTrustScore: 55,
                localPickupScore: 2,
                shippingEaseScore: 54,
                speedScore: 28,
                baselineSearchFit: 18,
                categoryFits: [.art: 48, .jewelry: 44, .home: 42, .clothing: 40]
            )
        case .rubylane:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "era + maker + material + item type + condition",
                searchFocus: "Good for antiques and fine art with era, maker, material, provenance, and condition.",
                photoGuidance: "Show maker marks, signatures, materials, scale, condition, and any restoration.",
                featuredGuidance: "Post only after provenance and condition are complete.",
                listingEffortScore: 44,
                buyerTrustScore: 76,
                localPickupScore: 8,
                shippingEaseScore: 58,
                speedScore: 42,
                baselineSearchFit: 18,
                categoryFits: [.art: 94, .jewelry: 90, .collectibles: 86, .home: 78, .books: 58]
            )
        case .tcgplayer:
            MarketplaceOptimizationProfile(
                titleMaxCharacters: 80,
                titleFormula: "card name + set + number + condition + variant",
                searchFocus: "Good for trading cards with the card name, set, number, variant, and condition.",
                photoGuidance: "Show front/back, corners, surface, centering, and any grading slab.",
                featuredGuidance: "Match the catalog item and set a fair price before posting.",
                listingEffortScore: 68,
                buyerTrustScore: 78,
                localPickupScore: 4,
                shippingEaseScore: 88,
                speedScore: 62,
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
