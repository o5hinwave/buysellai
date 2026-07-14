import SwiftUI

extension Font {
    static let brandDisplay = Font.custom("Space Grotesk", size: 44, relativeTo: .largeTitle).weight(.bold)
    static let brandTitleXL = Font.custom("Space Grotesk", size: 32, relativeTo: .title).weight(.semibold)
    static let brandTitleLg = Font.custom("Space Grotesk", size: 24, relativeTo: .title2).weight(.semibold)
    static let brandTitle = Font.custom("Space Grotesk", size: 20, relativeTo: .title3).weight(.semibold)
    static let brandBodyLg = Font.custom("Inter", size: 17, relativeTo: .body).weight(.medium)
    static let brandBody = Font.custom("Inter", size: 15, relativeTo: .body)
    static let brandCaption = Font.custom("Inter", size: 13, relativeTo: .caption).weight(.medium)
    static let brandOverline = Font.custom("Inter", size: 11, relativeTo: .caption2).weight(.semibold)
    static let brandButton = Font.custom("Space Grotesk", size: 17, relativeTo: .headline).weight(.semibold)
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
