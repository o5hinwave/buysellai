import Foundation
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
        let normalized = apiValue
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        let normalizedWithoutMarketplace = normalized.hasSuffix("marketplace")
            ? String(normalized.dropLast("marketplace".count))
            : normalized

        self = Marketplace.allCases.first { marketplace in
            let displayName = marketplace.displayName.lowercased().filter { $0.isLetter || $0.isNumber }
            return marketplace.rawValue == normalized
                || marketplace.rawValue == normalizedWithoutMarketplace
                || displayName == normalized
                || displayName == normalizedWithoutMarketplace
        } ?? .ebay
    }

    var displayName: String {
        switch self {
        case .ebay:
            String(localized: "eBay")
        case .craigslist:
            String(localized: "Craigslist")
        case .facebook:
            String(localized: "Facebook")
        case .poshmark:
            String(localized: "Poshmark")
        case .mercari:
            String(localized: "Mercari")
        case .offerup:
            String(localized: "OfferUp")
        case .depop:
            String(localized: "Depop")
        case .whatnot:
            String(localized: "Whatnot")
        case .grailed:
            String(localized: "Grailed")
        case .reverb:
            String(localized: "Reverb")
        case .etsy:
            String(localized: "Etsy")
        case .stockx:
            String(localized: "StockX")
        case .goat:
            String(localized: "GOAT")
        case .kidizen:
            String(localized: "Kidizen")
        case .vinted:
            String(localized: "Vinted")
        case .vestiaire:
            String(localized: "Vestiaire")
        case .therealreal:
            String(localized: "The RealReal")
        case .swappa:
            String(localized: "Swappa")
        case .tradesy:
            String(localized: "Tradesy")
        case .chairish:
            String(localized: "Chairish")
        case .bonanza:
            String(localized: "Bonanza")
        case .curtsy:
            String(localized: "Curtsy")
        case .nextdoor:
            String(localized: "Nextdoor")
        case .amazon:
            String(localized: "Amazon")
        case .shopify:
            String(localized: "Shopify")
        case .rubylane:
            String(localized: "Ruby Lane")
        case .tcgplayer:
            String(localized: "TCGplayer")
        }
    }

    var blurb: String {
        switch self {
        case .ebay:
            String(localized: "Broadest audience, small fees")
        case .craigslist:
            String(localized: "Local, no fees, cash")
        case .facebook:
            String(localized: "Facebook Marketplace — free local reach")
        case .poshmark:
            String(localized: "Fashion & closet items")
        case .mercari:
            String(localized: "Easy shipping for everyday items")
        case .offerup:
            String(localized: "Local pickup, mobile-first")
        case .depop:
            String(localized: "Vintage & Gen-Z fashion")
        case .whatnot:
            String(localized: "Live-stream selling")
        case .grailed:
            String(localized: "Menswear, streetwear, designer")
        case .reverb:
            String(localized: "Music gear")
        case .etsy:
            String(localized: "Handmade, vintage, craft")
        case .stockx:
            String(localized: "Sneakers & collectibles")
        case .goat:
            String(localized: "Sneakers, authenticated")
        case .kidizen:
            String(localized: "Kids clothes")
        case .vinted:
            String(localized: "Fashion, no listing fees")
        case .vestiaire:
            String(localized: "Luxury pre-owned")
        case .therealreal:
            String(localized: "Authenticated luxury")
        case .swappa:
            String(localized: "Used tech & phones")
        case .tradesy:
            String(localized: "Designer bags & shoes")
        case .chairish:
            String(localized: "Vintage furniture & decor")
        case .bonanza:
            String(localized: "General resale, low fees")
        case .curtsy:
            String(localized: "Women's fashion (mobile)")
        case .nextdoor:
            String(localized: "Neighborhood local sales")
        case .amazon:
            String(localized: "Amazon marketplace — high reach, high fee")
        case .shopify:
            String(localized: "Your own storefront")
        case .rubylane:
            String(localized: "Antiques & fine art")
        case .tcgplayer:
            String(localized: "Trading cards")
        }
    }

    var brandTint: Color {
        switch self {
        case .ebay:
            Color.brand.platformEbay
        case .craigslist:
            Color.brand.platformCraigslist
        case .facebook:
            Color.brand.platformFacebook
        case .poshmark:
            Color.brand.platformPoshmark
        case .mercari:
            Color.brand.platformMercari
        case .offerup:
            Color.brand.platformOfferUp
        case .depop:
            Color.brand.platformDepop
        case .whatnot:
            Color.brand.platformWhatnot
        case .grailed:
            Color.brand.platformGrailed
        case .reverb:
            Color.brand.platformReverb
        case .etsy:
            Color.brand.platformEtsy
        case .stockx:
            Color.brand.platformStockX
        case .goat:
            Color.brand.platformGOAT
        case .kidizen:
            Color.brand.platformKidizen
        case .vinted:
            Color.brand.platformVinted
        case .vestiaire:
            Color.brand.platformVestiaire
        case .therealreal:
            Color.brand.platformTheRealReal
        case .swappa:
            Color.brand.platformSwappa
        case .tradesy:
            Color.brand.platformTradesy
        case .chairish:
            Color.brand.platformChairish
        case .bonanza:
            Color.brand.platformBonanza
        case .curtsy:
            Color.brand.platformCurtsy
        case .nextdoor:
            Color.brand.platformNextdoor
        case .amazon:
            Color.brand.platformAmazon
        case .shopify:
            Color.brand.platformShopify
        case .rubylane:
            Color.brand.platformRubyLane
        case .tcgplayer:
            Color.brand.platformTCGplayer
        }
    }

    var shortMark: String {
        switch self {
        case .therealreal:
            "TRR"
        case .tcgplayer:
            "TCG"
        default:
            String(displayName.prefix(1))
        }
    }

    var feeMultiplier: Decimal {
        switch self {
        case .ebay:
            decimal("0.87")
        case .craigslist, .nextdoor:
            decimal("1")
        case .facebook, .vinted:
            decimal("0.95")
        case .poshmark:
            decimal("0.8")
        case .mercari:
            decimal("0.9")
        case .offerup, .bonanza:
            decimal("0.92")
        case .depop, .whatnot, .kidizen, .swappa, .curtsy:
            decimal("0.88")
        case .grailed:
            decimal("0.84")
        case .reverb:
            decimal("0.91")
        case .etsy, .amazon, .shopify:
            decimal("0.85")
        case .stockx, .goat:
            decimal("0.905")
        case .vestiaire:
            decimal("0.82")
        case .therealreal:
            decimal("0.7")
        case .tradesy:
            decimal("0.81")
        case .chairish:
            decimal("0.78")
        case .rubylane:
            decimal("0.86")
        case .tcgplayer:
            decimal("0.89")
        }
    }

    var fixedDeduction: Decimal {
        switch self {
        case .craigslist, .facebook, .offerup, .nextdoor:
            decimal("0")
        case .therealreal:
            decimal("5")
        case .chairish:
            decimal("4")
        case .amazon:
            decimal("3")
        case .shopify:
            decimal("2")
        default:
            decimal("1")
        }
    }

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }
}
