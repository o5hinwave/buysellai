import SwiftUI

enum BrandSymbolStyle: Sendable {
    case smallChevron
    case chevron
    case rowIcon
    case controlIcon
    case heroIcon

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
        case .heroIcon:
            44
        }
    }

    var weight: Font.Weight {
        switch self {
        case .smallChevron:
            .bold
        case .chevron, .rowIcon, .controlIcon, .heroIcon:
            .semibold
        }
    }

    var font: Font {
        .system(size: size, weight: weight)
    }
}

extension View {
    func brandSymbol(_ style: BrandSymbolStyle) -> some View {
        font(style.font)
    }
}

struct BrandWordmark: View {
    var includeAI = false
    var showsPeriod = true
    var size: WordmarkSize = .regular
    var foreground = Color.brand.foreground
    var periodColor = Color.brand.primaryText
    @Environment(\.legibilityWeight) private var legibilityWeight

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
        .font(size.font(legibilityWeight: legibilityWeight))
        .accessibilityLabel((includeAI ? "BuySell AI" : "BuySell").localized)
    }
}

enum WordmarkSize {
    case regular
    case large
    case display

    func font(legibilityWeight: LegibilityWeight? = nil) -> Font {
        .system(textStyle, design: .default, weight: weight(legibilityWeight: legibilityWeight))
    }

    var textStyle: Font.TextStyle {
        switch self {
        case .regular:
            .title3
        case .large:
            .title
        case .display:
            .largeTitle
        }
    }

    func weight(legibilityWeight: LegibilityWeight? = nil) -> Font.Weight {
        if legibilityWeight == .bold {
            return .bold
        }
        switch self {
        case .regular, .large:
            return .semibold
        case .display:
            return .bold
        }
    }
}
