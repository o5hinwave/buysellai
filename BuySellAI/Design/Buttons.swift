import SwiftUI
import UIKit

struct PrimaryPillButton: View {
    let title: String
    var systemImage: String?
    var fillsWidth = true
    var accessibilityHint: String?
    var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle? = .medium
    var showsGlow = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appReduceMotion) private var appReduceMotion
    @State private var pressed = false

    var body: some View {
        Button(action: {
            if let hapticStyle {
                Haptics.impact(hapticStyle)
            }
            action()
        }) {
            HStack(spacing: Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                }
                Text(title.localized)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.82)
            }
            .brandFont(.button)
            .foregroundStyle(Color.brand.primaryForeground)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 56)
            .padding(.horizontal, fillsWidth ? 0 : Spacing.xl)
            .background(Color.brand.primary, in: Capsule())
            .modifier(PrimaryGlowModifier(isEnabled: showsGlow))
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed && !shouldReduceMotion ? 0.96 : 1)
        .animation(AppMotion.animation(reduceMotion: shouldReduceMotion), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .accessibilityLabel(Text(title.localized))
        .optionalAccessibilityHint(accessibilityHint)
    }

    private var shouldReduceMotion: Bool {
        AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)
    }
}

private struct PrimaryGlowModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.modifier(AppShadow.primaryGlow())
        } else {
            content
        }
    }
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
                Text(title.localized)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .brandFont(.button)
            .foregroundStyle(Color.brand.foreground)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: minHeight)
            .padding(.horizontal, fillsWidth ? 0 : Spacing.lg)
            .background(Color.brand.secondary, in: Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed && !shouldReduceMotion ? 0.96 : 1)
        .animation(AppMotion.animation(reduceMotion: shouldReduceMotion), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .accessibilityLabel(Text(title.localized))
    }

    private var shouldReduceMotion: Bool {
        AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)
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
                Text(title.localized)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .brandFont(.caption)
            .foregroundStyle(Color.brand.foreground)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, Spacing.sm)
            .background(Color.brand.surface, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor), lineWidth: 1)
            )
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(Text(title.localized))
    }
}

struct IconCircleButton: View {
    static let minimumTapTarget: CGFloat = 44

    let systemImage: String
    let accessibilityLabel: String
    var size: CGFloat = 44
    var material = false
    let action: () -> Void

    static func tapTargetSize(for visualSize: CGFloat) -> CGFloat {
        max(visualSize, minimumTapTarget)
    }

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
                .frame(width: Self.tapTargetSize(for: size), height: Self.tapTargetSize(for: size))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(Text(accessibilityLabel.localized))
    }
}

struct PressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appReduceMotion) private var appReduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !shouldReduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(AppMotion.animation(reduceMotion: shouldReduceMotion), value: configuration.isPressed)
    }

    private var shouldReduceMotion: Bool {
        AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)
    }
}

private struct OptionalAccessibilityHint: ViewModifier {
    let hint: String?

    func body(content: Content) -> some View {
        if let hint, hint.isEmpty == false {
            content.accessibilityHint(Text(hint.localized))
        } else {
            content
        }
    }
}

extension View {
    func optionalAccessibilityHint(_ hint: String?) -> some View {
        modifier(OptionalAccessibilityHint(hint: hint))
    }
}
