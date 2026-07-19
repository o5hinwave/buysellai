import SwiftUI

enum BrandTextStyle: CaseIterable, Sendable {
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
        .system(textStyle, design: .default, weight: weight(legibilityWeight: legibilityWeight))
    }

    var textStyle: Font.TextStyle {
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

    func weight(legibilityWeight: LegibilityWeight? = nil) -> Font.Weight {
        if legibilityWeight == .bold {
            return boldTextWeight
        }
        return standardWeight
    }

    private var standardWeight: Font.Weight {
        switch self {
        case .display:
            .bold
        case .titleXL, .titleLg, .title, .button, .bodyLg, .caption, .overline:
            .semibold
        case .body:
            .regular
        }
    }

    private var boldTextWeight: Font.Weight {
        switch self {
        case .display, .titleXL, .titleLg, .title, .button:
            .bold
        case .bodyLg, .body, .caption, .overline:
            .semibold
        }
    }
}

enum BrandSymbolStyle: Sendable {
    case smallChevron
    case chevron
    case rowIcon
    case controlIcon

    var size: CGFloat {
        switch self {
        case .smallChevron:
            11
        case .chevron:
            13
        case .rowIcon:
            15
        case .controlIcon:
            17
        }
    }

    var weight: Font.Weight {
        switch self {
        case .smallChevron:
            .bold
        case .chevron, .rowIcon, .controlIcon:
            .semibold
        }
    }

    var font: Font {
        .system(size: size, weight: weight)
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

    func brandSymbol(_ style: BrandSymbolStyle) -> some View {
        font(style.font)
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
    var showsPeriod = true
    var size: WordmarkSize = .regular
    var foreground = Color.brand.foreground
    var periodColor = Color.brand.primaryText

    var body: some View {
        HStack(spacing: 0) {
            Text("BuySell".localized)
                .foregroundStyle(foreground)
            Text(includeAI ? " AI".localized : "")
                .foregroundStyle(foreground)
            if showsPeriod {
                Text(".".localized)
                    .foregroundStyle(periodColor)
            }
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
