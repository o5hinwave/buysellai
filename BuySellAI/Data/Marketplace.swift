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

    var displayName: String {
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

    var blurb: String {
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
        case .ebay: Color(hex: 0x0064D2)
        case .mercari: Color(hex: 0xE60023)
        case .poshmark: Color(hex: 0xE51A72)
        case .facebook: Color(hex: 0x1877F2)
        case .offerup: Color(hex: 0x16A34A)
        case .craigslist: Color(hex: 0x6B21A8)
        case .depop: Color(hex: 0xE11D48)
        case .whatnot: Color(hex: 0xFF5722)
        case .etsy: Color(hex: 0xF1641E)
        case .stockx: Color(hex: 0x006340)
        case .grailed: Color(hex: 0x121212)
        case .reverb: Color(hex: 0xF5A623)
        case .vinted: Color(hex: 0x09B1BA)
        case .nextdoor: Color(hex: 0x00B246)
        case .amazon: Color(hex: 0xFF9900)
        case .goat: Color(hex: 0x111111)
        case .kidizen: Color(hex: 0x13A8A8)
        case .vestiaire: Color(hex: 0x6B4F3F)
        case .therealreal: Color(hex: 0x111827)
        case .swappa: Color(hex: 0x2E7D32)
        case .tradesy: Color(hex: 0xB83280)
        case .chairish: Color(hex: 0xC75D2C)
        case .bonanza: Color(hex: 0x2B6CB0)
        case .curtsy: Color(hex: 0xF97316)
        case .shopify: Color(hex: 0x95BF47)
        case .rubylane: Color(hex: 0x8B0000)
        case .tcgplayer: Color(hex: 0x0F766E)
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
}
