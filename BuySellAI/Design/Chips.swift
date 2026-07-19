import SwiftUI

struct ChipButton: View {
    static let minimumTapTarget: CGFloat = 44

    let title: String
    var tint: Color = Color.brand.primaryText
    var accessibilityLabel: String?
    var accessibilityHint: String?
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.impact(.light)
            action()
        }) {
            Text(title.localized)
                .brandFont(.caption)
                .foregroundStyle(tint)
                .lineLimit(1)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: Self.minimumTapTarget)
                .nativeRoundedButtonBackground(
                    cornerRadius: Radius.pill,
                    tint: tint,
                    tintOpacity: 0.12,
                    strokeOpacity: 0.5
                )
        }
        .buttonStyle(PressButtonStyle())
        .tint(tint)
        .nativeGlassButtonStyle(.standard)
        .accessibilityLabel(Text((accessibilityLabel ?? title).localized))
        .optionalAccessibilityHint(accessibilityHint)
    }
}

enum ChipAccessibilityText {
    static func valueLabel(_ name: String, value: String) -> String {
        String.localizedFormat("%@, %@", name.localized, value.localized)
    }
}
