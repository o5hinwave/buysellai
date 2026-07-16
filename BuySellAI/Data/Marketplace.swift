import SwiftUI

enum Marketplace: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case ebay
    case craigslist
    case facebook
    case poshmark
    case mercari
    case offerup
    case depop
    case whatnot
    case grailed
    case reverb
    case etsy
    case stockx
    case goat
    case kidizen
    case vinted
    case vestiaire
    case therealreal
    case swappa
    case tradesy
    case chairish
    case bonanza
    case curtsy
    case nextdoor
    case amazon
    case shopify
    case rubylane
    case tcgplayer

    var id: Marketplace { self }

    init(apiValue: String) {
        let normalized = Self.normalizedIdentifier(apiValue)
        self = Marketplace.allCases.first {
            Self.normalizedIdentifier($0.rawValue) == normalized ||
            Self.normalizedIdentifier($0.displayName) == normalized
        } ?? .ebay
    }

    var displayName: String {
        displayNameKey.localized
    }

    var blurb: String {
        blurbKey.localized
    }

    private var displayNameKey: String {
        switch self {
        case .ebay: "eBay"
        case .craigslist: "Craigslist"
        case .facebook: "Facebook"
        case .poshmark: "Poshmark"
        case .mercari: "Mercari"
        case .offerup: "OfferUp"
        case .depop: "Depop"
        case .whatnot: "Whatnot"
        case .grailed: "Grailed"
        case .reverb: "Reverb"
        case .etsy: "Etsy"
        case .stockx: "StockX"
        case .goat: "GOAT"
        case .kidizen: "Kidizen"
        case .vinted: "Vinted"
        case .vestiaire: "Vestiaire"
        case .therealreal: "The RealReal"
        case .swappa: "Swappa"
        case .tradesy: "Tradesy"
        case .chairish: "Chairish"
        case .bonanza: "Bonanza"
        case .curtsy: "Curtsy"
        case .nextdoor: "Nextdoor"
        case .amazon: "Amazon"
        case .shopify: "Shopify"
        case .rubylane: "Ruby Lane"
        case .tcgplayer: "TCGplayer"
        }
    }

    private var blurbKey: String {
        switch self {
        case .ebay: "Broadest audience, small fees"
        case .craigslist: "Local, no fees, cash"
        case .facebook: "Facebook Marketplace — free local reach"
        case .poshmark: "Fashion & closet items"
        case .mercari: "Ship anything, casual buyers"
        case .offerup: "Local pickup, mobile-first"
        case .depop: "Vintage & Gen-Z fashion"
        case .whatnot: "Live-stream selling"
        case .grailed: "Menswear, streetwear, designer"
        case .reverb: "Music gear"
        case .etsy: "Handmade, vintage, craft"
        case .stockx: "Sneakers & collectibles"
        case .goat: "Sneakers, authenticated"
        case .kidizen: "Kids clothes"
        case .vinted: "Fashion, no seller fees"
        case .vestiaire: "Luxury pre-owned"
        case .therealreal: "Authenticated luxury"
        case .swappa: "Used tech & phones"
        case .tradesy: "Designer bags & shoes"
        case .chairish: "Vintage furniture & decor"
        case .bonanza: "General resale, low fees"
        case .curtsy: "Women's fashion (mobile)"
        case .nextdoor: "Neighborhood local sales"
        case .amazon: "Amazon seller — high reach, high fee"
        case .shopify: "Your own storefront"
        case .rubylane: "Antiques & fine art"
        case .tcgplayer: "Trading cards"
        }
    }

    var brandTint: Color {
        switch self {
        case .ebay: Color.brand.platformEbay
        case .mercari: Color.brand.platformMercari
        case .poshmark: Color.brand.platformPoshmark
        case .facebook: Color.brand.platformFacebook
        case .offerup: Color.brand.platformOfferUp
        case .craigslist: Color.brand.platformCraigslist
        case .depop: Color.brand.platformDepop
        case .whatnot: Color.brand.platformWhatnot
        case .etsy: Color.brand.platformEtsy
        case .stockx: Color.brand.platformStockX
        case .grailed: Color.brand.platformGrailed
        case .reverb: Color.brand.platformReverb
        case .vinted: Color.brand.platformVinted
        case .nextdoor: Color.brand.platformNextdoor
        case .amazon: Color.brand.platformAmazon
        case .goat: Color.brand.platformGOAT
        case .kidizen: Color.brand.platformKidizen
        case .vestiaire: Color.brand.platformVestiaire
        case .therealreal: Color.brand.platformTheRealReal
        case .swappa: Color.brand.platformSwappa
        case .tradesy: Color.brand.platformTradesy
        case .chairish: Color.brand.platformChairish
        case .bonanza: Color.brand.platformBonanza
        case .curtsy: Color.brand.platformCurtsy
        case .shopify: Color.brand.platformShopify
        case .rubylane: Color.brand.platformRubyLane
        case .tcgplayer: Color.brand.platformTCGplayer
        }
    }

    var feeMultiplier: Decimal {
        switch self {
        case .craigslist, .nextdoor: Decimal(1.00)
        case .facebook, .vinted: Decimal(0.95)
        case .offerup, .bonanza: Decimal(0.92)
        case .mercari: Decimal(0.90)
        case .stockx, .goat: Decimal(0.905)
        case .ebay: Decimal(0.87)
        case .swappa: Decimal(0.88)
        case .amazon, .etsy, .shopify: Decimal(0.85)
        case .reverb: Decimal(0.91)
        case .poshmark: Decimal(0.80)
        case .depop, .whatnot, .kidizen, .curtsy: Decimal(0.88)
        case .grailed: Decimal(0.84)
        case .vestiaire: Decimal(0.82)
        case .therealreal: Decimal(0.70)
        case .tradesy: Decimal(0.81)
        case .chairish: Decimal(0.78)
        case .rubylane: Decimal(0.86)
        case .tcgplayer: Decimal(0.89)
        }
    }

    var fixedDeduction: Decimal {
        switch self {
        case .craigslist, .facebook, .nextdoor, .offerup: Decimal(0)
        case .shopify: Decimal(2)
        case .amazon: Decimal(3)
        case .therealreal: Decimal(5)
        case .chairish: Decimal(4)
        default: Decimal(1)
        }
    }

    var shortMark: String {
        if self == .tcgplayer { return "TCG" }
        if self == .therealreal { return "TRR" }
        return String(displayName.prefix(1)).uppercased()
    }

    private static func normalizedIdentifier(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "marketplace", with: "")
            .filter { $0.isLetter || $0.isNumber }
    }
}
