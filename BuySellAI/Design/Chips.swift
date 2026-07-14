import SwiftUI

struct ChipButton: View {
    let title: String
    var tint: Color = Color.brand.primary
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
        .accessibilityLabel(Text(title.localized))
    }
}
