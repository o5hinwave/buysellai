import SwiftUI
import UIKit

struct TextActionButton: View {
    let title: String
    var minWidth: CGFloat?
    var minHeight: CGFloat = 44
    var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle? = .light
    let action: () -> Void

    var body: some View {
        Button(action: {
            if let hapticStyle {
                Haptics.impact(hapticStyle)
            }
            action()
        }) {
            Text(title.localized)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.82)
                .frame(minWidth: minWidth, minHeight: minHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .nativeGlassButtonStyle(.standard)
        .accessibilityLabel(Text(title.localized))
    }
}

private struct FocusedInputChromeModifier: ViewModifier {
    let isFocused: Bool
    let cornerRadius: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appReduceMotion) private var appReduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                NativeMaterialRoundedBackground(
                    cornerRadius: cornerRadius,
                    tintOpacity: 0.78,
                    strokeOpacity: 0
                )
            }
            .overlay {
                shape.stroke(borderColor, lineWidth: isFocused ? 1.5 : 1)
            }
            .opacity(isEnabled ? ButtonStateOpacity.enabled : ButtonStateOpacity.disabled)
            .animation(AppMotion.animation(reduceMotion: shouldReduceMotion), value: isFocused)
            .animation(AppMotion.animation(reduceMotion: shouldReduceMotion), value: isEnabled)
    }

    private var borderColor: Color {
        isFocused
            ? Color.brand.borderStrong
            : Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor)
    }

    private var shouldReduceMotion: Bool {
        AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)
    }
}

extension View {
    func focusedInputChrome(
        isFocused: Bool,
        cornerRadius: CGFloat = Radius.lg,
        horizontalPadding: CGFloat = Spacing.md,
        verticalPadding: CGFloat = Spacing.md
    ) -> some View {
        modifier(FocusedInputChromeModifier(
            isFocused: isFocused,
            cornerRadius: cornerRadius,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        ))
    }
}

struct IconCircleButton: View {
    static let minimumTapTarget: CGFloat = 44

    let systemImage: String
    let accessibilityLabel: String
    var size: CGFloat = 44
    var material = false
    var materialForeground = Color.brand.primaryForeground
    var materialStroke = Color.brand.primaryForeground
    var usesAccessibleMaterialStroke = false
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
                .brandSymbol(.controlIcon)
                .foregroundStyle(material ? materialForeground : Color.brand.foreground)
                .frame(width: size, height: size)
                .nativeIconButtonBackground(
                    material: material,
                    materialStroke: materialStroke,
                    usesAccessibleMaterialStroke: usesAccessibleMaterialStroke
                )
                .frame(width: Self.tapTargetSize(for: size), height: Self.tapTargetSize(for: size))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .tint(Color.brand.primary)
        .nativeGlassButtonStyle(.standard)
        .accessibilityLabel(Text(accessibilityLabel.localized))
    }
}

struct PressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appReduceMotion) private var appReduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && isEnabled && !shouldReduceMotion ? 0.96 : 1)
            .opacity(ButtonStateOpacity.opacity(isEnabled: isEnabled, isPressed: configuration.isPressed))
            .animation(AppMotion.animation(reduceMotion: shouldReduceMotion), value: configuration.isPressed)
            .animation(AppMotion.animation(reduceMotion: shouldReduceMotion), value: isEnabled)
    }

    private var shouldReduceMotion: Bool {
        AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)
    }
}

enum ButtonStateOpacity {
    static let enabled = 1.0
    static let pressed = 0.82
    static let disabled = 0.48

    static func opacity(isEnabled: Bool, isPressed: Bool) -> Double {
        if isEnabled == false {
            return disabled
        }
        return isPressed ? pressed : enabled
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
