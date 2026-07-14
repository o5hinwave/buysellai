import SwiftUI

extension Font {
    static let brandDisplay = Font.custom("SpaceGrotesk-Bold", size: 44, relativeTo: .largeTitle)
    static let brandTitleXL = Font.custom("SpaceGrotesk-SemiBold", size: 32, relativeTo: .title)
    static let brandTitleLg = Font.custom("SpaceGrotesk-SemiBold", size: 24, relativeTo: .title2)
    static let brandTitle = Font.custom("SpaceGrotesk-SemiBold", size: 20, relativeTo: .title3)
    static let brandBodyLg = Font.custom("Inter-Medium", size: 17, relativeTo: .body)
    static let brandBody = Font.custom("Inter-Regular", size: 15, relativeTo: .body)
    static let brandCaption = Font.custom("Inter-Medium", size: 13, relativeTo: .caption)
    static let brandOverline = Font.custom("Inter-SemiBold", size: 11, relativeTo: .caption2)
    static let brandButton = Font.custom("SpaceGrotesk-SemiBold", size: 17, relativeTo: .headline)
}

struct BrandWordmark: View {
    var includeAI = false
    var size: WordmarkSize = .regular

    var body: some View {
        HStack(spacing: 0) {
            Text("BuySell")
                .foregroundStyle(Color.brand.foreground)
            Text(includeAI ? " AI" : "")
                .foregroundStyle(Color.brand.foreground)
            Text(".")
                .foregroundStyle(Color.brand.primary)
        }
        .font(size.font)
        .accessibilityLabel(includeAI ? "BuySell AI" : "BuySell")
    }
}

enum WordmarkSize {
    case regular
    case large
    case display

    var font: Font {
        switch self {
        case .regular: .brandTitle
        case .large: .brandTitleXL
        case .display: .brandDisplay
        }
    }
}

