import SwiftUI

struct ChipButton: View {
    let title: String
    var tint: Color = Color.brand.primary
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
                .frame(minHeight: 40)
                .background(tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(Text((accessibilityLabel ?? title).localized))
        .optionalAccessibilityHint(accessibilityHint)
    }
}

enum ChipAccessibilityText {
    static func valueLabel(_ name: String, value: String) -> String {
        String.localizedFormat("%@, %@", name.localized, value.localized)
    }
}
