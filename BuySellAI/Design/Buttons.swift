import SwiftUI

struct PrimaryPillButton: View {
    let title: String
    var systemImage: String?
    var fillsWidth = true
    var accessibilityHint: String?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appReduceMotion) private var appReduceMotion
    @State private var pressed = false

    var body: some View {
        Button(action: {
            Haptics.impact(.medium)
            action()
        }) {
            HStack(spacing: Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                }
                Text(String(localized: String.LocalizationValue(title)))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.82)
            }
            .font(.brandButton)
            .foregroundStyle(Color.brand.primaryForeground)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 56)
            .padding(.horizontal, fillsWidth ? 0 : Spacing.xl)
            .background(Color.brand.primary, in: Capsule())
            .shadow(color: Color.brand.primary.opacity(0.35), radius: 30, x: 0, y: 12)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed && !shouldReduceMotion ? 0.96 : 1)
        .animation(AppMotion.animation(reduceMotion: shouldReduceMotion), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(accessibilityHint ?? ""))
    }

    private var shouldReduceMotion: Bool { reduceMotion || appReduceMotion }
}

struct SecondaryPillButton: View {
    let title: String
    var systemImage: String?
    var minHeight: CGFloat = 48
    var fillsWidth = true
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appReduceMotion) private var appReduceMotion
    @State private var pressed = false

    var body: some View {
        Button(action: {
            Haptics.impact(.light)
            action()
        }) {
            HStack(spacing: Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(String(localized: String.LocalizationValue(title)))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .font(.brandButton)
            .foregroundStyle(Color.brand.foreground)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: minHeight)
            .padding(.horizontal, fillsWidth ? 0 : Spacing.lg)
            .background(Color.brand.secondary, in: Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed && !(reduceMotion || appReduceMotion) ? 0.96 : 1)
        .animation(AppMotion.animation(reduceMotion: reduceMotion || appReduceMotion), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .accessibilityLabel(Text(title))
    }
}

struct GhostButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        Button(action: {
            Haptics.impact(.light)
            action()
        }) {
            HStack(spacing: Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(String(localized: String.LocalizationValue(title)))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .font(.brandCaption)
            .foregroundStyle(Color.brand.foreground)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, Spacing.sm)
            .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(differentiateWithoutColor ? Color.brand.borderStrong : Color.brand.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(Text(title))
    }
}

struct IconCircleButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var size: CGFloat = 44
    var material = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.impact(.light)
            action()
        }) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(material ? Color.brand.primaryForeground : Color.brand.foreground)
                .frame(width: size, height: size)
                .background {
                    if material {
                        Circle().fill(.ultraThinMaterial)
                    } else {
                        Circle().fill(Color.brand.secondary)
                    }
                }
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

struct PressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appReduceMotion) private var appReduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !(reduceMotion || appReduceMotion) ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(AppMotion.animation(reduceMotion: reduceMotion || appReduceMotion), value: configuration.isPressed)
    }
}
