import SwiftUI

enum BrandTextStyle: Sendable {
    case display
    case titleXL
    case titleLg
    case title
    case bodyLg
    case body
    case caption
    case overline
    case button

    func font(legibilityWeight: LegibilityWeight? = nil) -> Font {
        Font.custom(fontName, size: size, relativeTo: relativeTo)
            .weight(weight(legibilityWeight: legibilityWeight))
    }

    private var fontName: String {
        switch self {
        case .display, .titleXL, .titleLg, .title, .button:
            "Space Grotesk"
        case .bodyLg, .body, .caption, .overline:
            "Inter"
        }
    }

    private var size: CGFloat {
        switch self {
        case .display: 44
        case .titleXL: 32
        case .titleLg: 24
        case .title: 20
        case .bodyLg, .button: 17
        case .body: 15
        case .caption: 13
        case .overline: 11
        }
    }

    private var relativeTo: Font.TextStyle {
        switch self {
        case .display:
            .largeTitle
        case .titleXL:
            .title
        case .titleLg:
            .title2
        case .title:
            .title3
        case .bodyLg, .body:
            .body
        case .caption:
            .caption
        case .overline:
            .caption2
        case .button:
            .headline
        }
    }

    private func weight(legibilityWeight: LegibilityWeight?) -> Font.Weight {
        if legibilityWeight == .bold {
            return .bold
        }

        switch self {
        case .display:
            return .bold
        case .titleXL, .titleLg, .title, .overline, .button:
            return .semibold
        case .bodyLg, .caption:
            return .medium
        case .body:
            return .regular
        }
    }
}

extension Font {
    static let brandDisplay = BrandTextStyle.display.font()
    static let brandTitleXL = BrandTextStyle.titleXL.font()
    static let brandTitleLg = BrandTextStyle.titleLg.font()
    static let brandTitle = BrandTextStyle.title.font()
    static let brandBodyLg = BrandTextStyle.bodyLg.font()
    static let brandBody = BrandTextStyle.body.font()
    static let brandCaption = BrandTextStyle.caption.font()
    static let brandOverline = BrandTextStyle.overline.font()
    static let brandButton = BrandTextStyle.button.font()
}

extension View {
    func brandFont(_ style: BrandTextStyle) -> some View {
        modifier(BrandFontModifier(style: style))
    }
}

private struct BrandFontModifier: ViewModifier {
    let style: BrandTextStyle
    @Environment(\.legibilityWeight) private var legibilityWeight

    func body(content: Content) -> some View {
        content.font(style.font(legibilityWeight: legibilityWeight))
    }
}

struct BrandWordmark: View {
    var includeAI = false
    var size: WordmarkSize = .regular

    var body: some View {
        HStack(spacing: 0) {
            Text("BuySell".localized)
                .foregroundStyle(Color.brand.foreground)
            Text(includeAI ? " AI".localized : "")
                .foregroundStyle(Color.brand.foreground)
            Text(".".localized)
                .foregroundStyle(Color.brand.primary)
        }
        .brandFont(size.style)
        .accessibilityLabel((includeAI ? "BuySell AI" : "BuySell").localized)
    }
}

enum WordmarkSize {
    case regular
    case large
    case display

    var style: BrandTextStyle {
        switch self {
        case .regular: .title
        case .large: .titleXL
        case .display: .display
        }
    }
}
