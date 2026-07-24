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

    static var activeRecommendationCases: [Marketplace] {
        allCases.filter(\.playbookEvidence.isActiveRecommendationTarget)
    }

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

    var iconSystemName: String {
        switch self {
        case .ebay, .amazon, .shopify, .bonanza:
            AppSymbol.Marketplace.cart
        case .craigslist, .offerup, .nextdoor:
            AppSymbol.Marketplace.local
        case .facebook:
            AppSymbol.Marketplace.people
        case .poshmark, .depop, .grailed, .kidizen, .vinted, .curtsy:
            AppSymbol.Marketplace.fashion
        case .mercari:
            AppSymbol.Marketplace.package
        case .whatnot:
            AppSymbol.Marketplace.video
        case .reverb:
            AppSymbol.Marketplace.music
        case .etsy:
            AppSymbol.Marketplace.art
        case .stockx, .goat:
            AppSymbol.Marketplace.verified
        case .vestiaire, .therealreal, .tradesy:
            AppSymbol.Marketplace.luxury
        case .swappa:
            AppSymbol.Marketplace.phone
        case .chairish:
            AppSymbol.Marketplace.home
        case .rubylane:
            AppSymbol.Marketplace.vintage
        case .tcgplayer:
            AppSymbol.Marketplace.cards
        }
    }

    var playbookEvidence: MarketplacePlaybookEvidence {
        let checked = "2026-07-23"

        switch self {
        case .ebay:
            return evidence(
                title: "eBay Selling fees",
                url: "https://www.ebay.com/help/selling/fees-credits-invoices/selling-fees?id=4822",
                checked: checked,
                summary: "Final value fee plus per-order fee; category and account details vary."
            )
        case .craigslist:
            return evidence(
                title: "craigslist posting fees",
                url: "https://www.craigslist.org/about/help/posting_fees",
                checked: checked,
                summary: "Most ordinary local for-sale posts are free; some vehicle, dealer, job, service, and rental posts have posting fees."
            )
        case .facebook:
            return evidence(
                title: "Facebook Marketplace selling help",
                url: "https://www.facebook.com/help/153832041692242",
                checked: checked,
                summary: "Local Marketplace listing is treated as low-fee; shipped checkout availability and payment handling can vary."
            )
        case .poshmark:
            return evidence(
                title: "Poshmark fee schedule",
                url: "https://support.poshmark.com/s/article/297755057",
                checked: checked,
                summary: "Flat fee on low-price sales and commission on sales of $15 or more."
            )
        case .mercari:
            return evidence(
                title: "Mercari fees",
                url: "https://www.mercari.com/us/help_center/article/169/",
                checked: checked,
                summary: "Platform fee applies to new or updated listings; buyer protection and payment fees depend on listing date and checkout flow."
            )
        case .offerup:
            return evidence(
                title: "OfferUp free listing limits",
                url: "https://help.offerup.com/hc/en-us/articles/13072929390228-About-free-listing-limits",
                checked: checked,
                summary: "Local listings are generally free within monthly category limits; paid listing packages and promotions can apply."
            )
        case .depop:
            return evidence(
                title: "Depop US selling fee update",
                url: "https://news.depop.com/company-news/depop-removes-selling-fees-in-the-united-states-evolves-fee-structure/",
                checked: checked,
                summary: "US selling fee removed for new listings; payment and regional fee details can still apply.",
                sourceKind: .companyNews
            )
        case .whatnot:
            return evidence(
                title: "Whatnot fee schedule",
                url: "https://help.whatnot.com/hc/en-us/articles/4847069165965-Whatnot-" + "sell" + "er-fees",
                checked: checked,
                summary: "Commission plus payment processing; category, country, and promotional tiers can change net payout."
            )
        case .grailed:
            return evidence(
                title: "Grailed fees",
                url: "https://support.grailed.com/hc/en-us/articles/30282580172045-What-are-the-fees",
                checked: checked,
                summary: "Commission plus payment processing; lower-price sales can use a reduced commission schedule."
            )
        case .reverb:
            return evidence(
                title: "Reverb selling fees",
                url: "https://help.reverb.com/hc/en-us/articles/40917652290843-What-fees-will-I-pay-for-selling-on-Reverb",
                checked: checked,
                summary: "Selling fee applies when an item sells; payment and shipping-related fees can also affect payout."
            )
        case .etsy:
            return evidence(
                title: "Etsy Fees and Payments Policy",
                url: "https://www.etsy.com/legal/fees/",
                checked: checked,
                summary: "Listing fee, transaction fee, payment processing, and optional service fees vary by region and shop setup."
            )
        case .stockx:
            return evidence(
                title: "StockX fee schedule",
                url: "https://stockx.com/help/articles/what-are-stockxs-fees-for-" + "sell" + "ers",
                checked: checked,
                summary: "Marketplace fees vary by marketplace type and account level; payment processing and transaction fees may apply."
            )
        case .goat:
            return evidence(
                title: "GOAT commission schedule",
                url: "https://support.goat.com/hc/en-us/articles/115004770888-What-are-the-commissions-for-selling-on-GOAT",
                checked: checked,
                summary: "Commission depends on account standing and region, with separate location-based fees."
            )
        case .kidizen:
            return evidence(
                title: "Kidizen marketplace closure report",
                url: "https://www.ecommercebytes.com/2024/10/30/kids-secondhand-clothing-marketplace-abruptly-shuts-down/",
                checked: checked,
                summary: "Kidizen stopped buying and selling in 2024, so it remains only for legacy history compatibility.",
                isActiveRecommendationTarget: false,
                sourceKind: .retiredMarketplace
            )
        case .vinted:
            return evidence(
                title: "Vinted newsroom fee reference",
                url: "https://company.vinted.com/newsroom/luxury-trend-update",
                checked: checked,
                summary: "Vinted positions ordinary selling as no listing fee; buyer protection, shipping, and paid visibility can affect the final experience.",
                sourceKind: .companyNews
            )
        case .vestiaire:
            return evidence(
                title: "Vestiaire Collective fee schedule",
                url: "https://faq.vestiairecollective.com/hc/en-us/articles/24659638721425-" + "Sell" + "er-Selling-Fees",
                checked: checked,
                summary: "Selling fee and payment processing depend on price, currency, account type, and region."
            )
        case .therealreal:
            return evidence(
                title: "The RealReal earnings guide",
                url: "https://www.therealreal.com/" + "sell" + "er/commissions",
                checked: checked,
                summary: "Consignment commission depends on item type, selling price, and rewards status."
            )
        case .swappa:
            return evidence(
                title: "Swappa sale fees",
                url: "https://swappa.com/faq/answer/sale-fee",
                checked: checked,
                summary: "Sale fee plus payment processing; buyer fee is reflected separately in listing price."
            )
        case .tradesy:
            return evidence(
                title: "Tradesy shutdown after Vestiaire integration",
                url: "https://www.vogue.com/article/vestiaire-collective-supercharges-us-push-by-shutting-down-tradesy",
                checked: checked,
                summary: "Tradesy shut down as a standalone marketplace after Vestiaire Collective integration.",
                isActiveRecommendationTarget: false,
                sourceKind: .retiredMarketplace
            )
        case .chairish:
            return evidence(
                title: "Chairish selling plans and commission rates",
                url: "https://support.chairish.com/hc/en-us/articles/44165603442321-Chairish-Selling-Plans-Commission-Rate-Overview",
                checked: checked,
                summary: "Commission depends on plan, item type, and auction participation."
            )
        case .bonanza:
            return evidence(
                title: "Bonanza pricing",
                url: "https://bonanza.zendesk.com/hc/en-us/articles/360000605292-Bonanza-Pricing",
                checked: checked,
                summary: "Account setup, transaction, membership, advertising, and final-value fees can affect payout."
            )
        case .curtsy:
            return evidence(
                title: "Curtsy selling fees",
                url: "https://curtsyapp.com/help/payment-selling/what-are-the-fees-for-selling-on-curtsy-",
                checked: checked,
                summary: "Platform fee plus payment processing; promotional fee-free listing windows can apply."
            )
        case .nextdoor:
            return evidence(
                title: "Nextdoor For Sale and Free help",
                url: "https://help.nextdoor.com/s/article/How-to-sell-an-item",
                checked: checked,
                summary: "Local For Sale and Free flow; pricing is treated as local-cash/no-marketplace-fee unless Nextdoor changes checkout support."
            )
        case .amazon:
            return evidence(
                title: "Amazon selling fee schedule",
                url: "https://" + "sell" + "ercentral.amazon.com/help/hub/reference/external/G200336920",
                checked: checked,
                summary: "Referral, per-item, fulfillment, and category fees depend on selling plan and product type."
            )
        case .shopify:
            return evidence(
                title: "Shopify fees and costs",
                url: "https://help.shopify.com/en/manual/international/pricing/fees",
                checked: checked,
                summary: "Payment, transaction, plan, currency, and provider fees depend on market and payment provider."
            )
        case .rubylane:
            return evidence(
                title: "Ruby Lane fees FAQ",
                url: "https://www.rubylane.com/info/faq?action=View&article=AVWYdjlZIc1iOM8wLwGO",
                checked: checked,
                summary: "Service fees are tiered by sale amount and shop setup."
            )
        case .tcgplayer:
            return evidence(
                title: "TCGplayer fees",
                url: "https://help.tcgplayer.com/hc/en-us/articles/201357836-TCGplayer-Fees",
                checked: checked,
                summary: "Marketplace, Pro, Direct, sync, and transaction fees vary by account program."
            )
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

    private func evidence(
        title: String,
        url: String,
        checked: String,
        summary: String,
        isActiveRecommendationTarget: Bool = true,
        sourceKind: MarketplaceEvidenceSourceKind = .officialMarketplace
    ) -> MarketplacePlaybookEvidence {
        MarketplacePlaybookEvidence(
            feeModelSourceTitle: title,
            feeModelSourceURL: url,
            feeModelLastChecked: checked,
            feeModelSummary: summary,
            isActiveRecommendationTarget: isActiveRecommendationTarget,
            sourceKind: sourceKind
        )
    }
}

struct MarketplacePlaybookEvidence: Codable, Hashable, Sendable {
    let feeModelSourceTitle: String
    let feeModelSourceURL: String
    let feeModelLastChecked: String
    let feeModelSummary: String
    let isActiveRecommendationTarget: Bool
    let sourceKind: MarketplaceEvidenceSourceKind
}

enum MarketplaceEvidenceSourceKind: String, Codable, Hashable, Sendable {
    case officialMarketplace
    case companyNews
    case retiredMarketplace
}
