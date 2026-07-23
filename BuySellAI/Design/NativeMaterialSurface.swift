import SwiftUI

enum NativeMaterialSurfaceAccessibility {
    static func resolvedTintOpacity(
        base: Double,
        reduceTransparency: Bool,
        reducedTransparencyMinimum: Double
    ) -> Double {
        reduceTransparency ? max(base, reducedTransparencyMinimum) : base
    }
}

#if compiler(>=6.2)
@available(iOS 26.0, *)
private struct LiquidGlassSurfaceGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content()
        }
    }
}

@available(iOS 26.0, *)
private let liquidGlassButtonStyleType = GlassButtonStyle.self
#endif

enum NativeGlassButtonProminence {
    case standard
    case prominent
}

private struct NativeGlassButtonStyleModifier: ViewModifier {
    let prominence: NativeGlassButtonProminence

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            switch prominence {
            case .standard:
                content.buttonStyle(.glass)
            case .prominent:
                content.buttonStyle(.glassProminent)
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

private struct NativeLiquidGlassControlGroupModifier: ViewModifier {
    let spacing: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            LiquidGlassSurfaceGroup(spacing: spacing) {
                content
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

private struct NativeRoundedButtonBackgroundModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    let tintOpacity: Double
    let strokeOpacity: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
        } else {
            fallbackBody(content: content)
        }
        #else
        fallbackBody(content: content)
        #endif
    }

    private func fallbackBody(content: Content) -> some View {
        content.background {
            NativeMaterialRoundedBackground(
                cornerRadius: cornerRadius,
                tint: tint,
                tintOpacity: tintOpacity,
                strokeOpacity: strokeOpacity
            )
        }
    }
}

private struct NativeIconButtonBackgroundModifier: ViewModifier {
    let material: Bool
    let materialStroke: Color
    let usesAccessibleMaterialStroke: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
        } else {
            fallbackBody(content: content)
        }
        #else
        fallbackBody(content: content)
        #endif
    }

    @ViewBuilder
    private func fallbackBody(content: Content) -> some View {
        content.background {
            if material {
                NativeMaterialCircleBackground(
                    strokeColor: materialStroke,
                    usesAccessibleStroke: usesAccessibleMaterialStroke
                )
            } else {
                Circle().fill(Color.brand.secondary)
            }
        }
    }
}

struct NativeMaterialCircleBackground: View {
    var tintOpacity: Double = 0.14
    var strokeColor = Color.brand.primaryForeground
    var usesAccessibleStroke = false
    var strokeOpacity: Double = 0.28

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Circle()
                .fill(Color.brand.surface.opacity(resolvedTintOpacity))
                .glassEffect(.regular.tint(Color.brand.surface.opacity(resolvedTintOpacity)).interactive(), in: Circle())
                .overlay {
                    Circle()
                        .stroke(resolvedStrokeColor.opacity(strokeOpacity), lineWidth: 1)
                }
        } else {
            fallbackBody
        }
        #else
        fallbackBody
        #endif
    }

    private var fallbackBody: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay {
                Circle().fill(Color.brand.surface.opacity(resolvedTintOpacity))
            }
            .overlay {
                Circle()
                    .stroke(resolvedStrokeColor.opacity(strokeOpacity), lineWidth: 1)
            }
    }

    private var resolvedStrokeColor: Color {
        usesAccessibleStroke
            ? Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor)
            : strokeColor
    }

    private var resolvedTintOpacity: Double {
        NativeMaterialSurfaceAccessibility.resolvedTintOpacity(
            base: tintOpacity,
            reduceTransparency: reduceTransparency,
            reducedTransparencyMinimum: 0.88
        )
    }
}

struct NativeMaterialRoundedBackground: View {
    var cornerRadius: CGFloat = Radius.lg
    var tint = Color.brand.surface
    var tintOpacity: Double = 0.66
    var strokeColor: Color?
    var usesAccessibleStroke = true
    var strokeOpacity: Double = 0.72
    var lineWidth: CGFloat = 1

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            shape
                .fill(tint.opacity(resolvedTintOpacity))
                .glassEffect(.regular.tint(tint.opacity(resolvedTintOpacity)), in: shape)
                .overlay {
                    shape.stroke(resolvedStrokeColor.opacity(strokeOpacity), lineWidth: lineWidth)
                }
        } else {
            fallbackBody(shape: shape)
        }
        #else
        fallbackBody(shape: shape)
        #endif
    }

    private func fallbackBody(shape: RoundedRectangle) -> some View {
        shape
            .fill(.regularMaterial)
            .overlay {
                shape.fill(tint.opacity(resolvedTintOpacity))
            }
            .overlay {
                shape.stroke(resolvedStrokeColor.opacity(strokeOpacity), lineWidth: lineWidth)
            }
    }

    private var resolvedStrokeColor: Color {
        usesAccessibleStroke
            ? Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor)
            : (strokeColor ?? Color.brand.border)
    }

    private var resolvedTintOpacity: Double {
        NativeMaterialSurfaceAccessibility.resolvedTintOpacity(
            base: tintOpacity,
            reduceTransparency: reduceTransparency,
            reducedTransparencyMinimum: 0.94
        )
    }
}

private struct NativeMaterialPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tintOpacity: Double
    let strokeOpacity: Double

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .background {
                    shape.fill(Color.brand.surface.opacity(resolvedTintOpacity))
                }
                .glassEffect(.regular.tint(Color.brand.surface.opacity(resolvedTintOpacity)), in: shape)
                .overlay {
                    shape.stroke(
                        Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor)
                            .opacity(strokeOpacity),
                        lineWidth: 1
                    )
                }
        } else {
            fallbackBody(content: content, shape: shape)
        }
        #else
        fallbackBody(content: content, shape: shape)
        #endif
    }

    private func fallbackBody(content: Content, shape: RoundedRectangle) -> some View {
        content
            .background {
                shape
                    .fill(.regularMaterial)
                    .overlay {
                        shape.fill(Color.brand.surface.opacity(resolvedTintOpacity))
                    }
            }
            .overlay {
                shape.stroke(
                    Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor)
                        .opacity(strokeOpacity),
                    lineWidth: 1
                )
            }
    }

    private var resolvedTintOpacity: Double {
        NativeMaterialSurfaceAccessibility.resolvedTintOpacity(
            base: tintOpacity,
            reduceTransparency: reduceTransparency,
            reducedTransparencyMinimum: 0.94
        )
    }
}

private struct NativeMaterialPillModifier: ViewModifier {
    let tintOpacity: Double
    let strokeOpacity: Double

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = Capsule(style: .continuous)

        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .background {
                    shape.fill(Color.brand.surface.opacity(resolvedTintOpacity))
                }
                .glassEffect(.regular.tint(Color.brand.surface.opacity(resolvedTintOpacity)).interactive(), in: shape)
                .overlay {
                    shape.stroke(
                        Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor)
                            .opacity(strokeOpacity),
                        lineWidth: 1
                    )
                }
        } else {
            fallbackBody(content: content, shape: shape)
        }
        #else
        fallbackBody(content: content, shape: shape)
        #endif
    }

    private func fallbackBody(content: Content, shape: Capsule) -> some View {
        content
            .background {
                shape
                    .fill(.regularMaterial)
                    .overlay {
                        shape.fill(Color.brand.surface.opacity(resolvedTintOpacity))
                    }
            }
            .overlay {
                shape.stroke(
                    Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor)
                        .opacity(strokeOpacity),
                    lineWidth: 1
                )
            }
    }

    private var resolvedTintOpacity: Double {
        NativeMaterialSurfaceAccessibility.resolvedTintOpacity(
            base: tintOpacity,
            reduceTransparency: reduceTransparency,
            reducedTransparencyMinimum: 0.94
        )
    }
}

private struct NativeMaterialBarModifier: ViewModifier {
    let tintOpacity: Double
    let showsTopDivider: Bool
    let showsBottomDivider: Bool

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .background {
                    Rectangle().fill(Color.brand.surface.opacity(resolvedTintOpacity))
                }
                .glassEffect(.regular.tint(Color.brand.surface.opacity(resolvedTintOpacity)), in: Rectangle())
                .overlay(alignment: .top) {
                    if showsTopDivider {
                        divider
                    }
                }
                .overlay(alignment: .bottom) {
                    if showsBottomDivider {
                        divider
                    }
                }
        } else {
            fallbackBody(content: content)
        }
        #else
        fallbackBody(content: content)
        #endif
    }

    private func fallbackBody(content: Content) -> some View {
        content
            .background {
                Rectangle()
                    .fill(.regularMaterial)
                    .overlay {
                        Rectangle().fill(Color.brand.surface.opacity(resolvedTintOpacity))
                    }
                    .ignoresSafeArea()
            }
            .overlay(alignment: .top) {
                if showsTopDivider {
                    divider
                }
            }
            .overlay(alignment: .bottom) {
                if showsBottomDivider {
                    divider
                }
            }
    }

    private var divider: some View {
        Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor)
            .frame(height: 1)
            .opacity(0.72)
    }

    private var resolvedTintOpacity: Double {
        NativeMaterialSurfaceAccessibility.resolvedTintOpacity(
            base: tintOpacity,
            reduceTransparency: reduceTransparency,
            reducedTransparencyMinimum: 0.96
        )
    }
}

private struct NativeMaterialSheetModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tintOpacity: Double
    let strokeOpacity: Double

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: cornerRadius,
            style: .continuous
        )

        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .background {
                    shape.fill(Color.brand.background.opacity(resolvedTintOpacity))
                }
                .glassEffect(.regular.tint(Color.brand.background.opacity(resolvedTintOpacity)), in: shape)
                .clipShape(shape)
                .overlay {
                    shape.stroke(
                        Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor)
                            .opacity(strokeOpacity),
                        lineWidth: 1
                    )
                }
        } else {
            fallbackBody(content: content, shape: shape)
        }
        #else
        fallbackBody(content: content, shape: shape)
        #endif
    }

    private func fallbackBody(content: Content, shape: UnevenRoundedRectangle) -> some View {
        content
            .background {
                shape
                    .fill(.regularMaterial)
                    .overlay {
                        shape.fill(Color.brand.background.opacity(resolvedTintOpacity))
                    }
            }
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor)
                        .opacity(strokeOpacity),
                    lineWidth: 1
                )
            }
    }

    private var resolvedTintOpacity: Double {
        NativeMaterialSurfaceAccessibility.resolvedTintOpacity(
            base: tintOpacity,
            reduceTransparency: reduceTransparency,
            reducedTransparencyMinimum: 0.97
        )
    }
}

private struct NativeSystemSheetPresentationModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            nativePresentation(content)
        } else {
            fallbackPresentation(content)
        }
        #else
        fallbackPresentation(content)
        #endif
    }

    private func nativePresentation(_ content: Content) -> some View {
        content
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
    }

    private func fallbackPresentation(_ content: Content) -> some View {
        content
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(.regularMaterial)
    }
}

extension View {
    func nativeLiquidGlassControlGroup(spacing: CGFloat = Spacing.sm) -> some View {
        modifier(NativeLiquidGlassControlGroupModifier(spacing: spacing))
    }

    func nativeGlassButtonStyle(_ prominence: NativeGlassButtonProminence = .standard) -> some View {
        modifier(NativeGlassButtonStyleModifier(prominence: prominence))
    }

    func nativeRoundedButtonBackground(
        cornerRadius: CGFloat = Radius.pill,
        tint: Color = Color.brand.surface,
        tintOpacity: Double = 0.12,
        strokeOpacity: Double = 0.5
    ) -> some View {
        modifier(NativeRoundedButtonBackgroundModifier(
            cornerRadius: cornerRadius,
            tint: tint,
            tintOpacity: tintOpacity,
            strokeOpacity: strokeOpacity
        ))
    }

    func nativeIconButtonBackground(
        material: Bool,
        materialStroke: Color,
        usesAccessibleMaterialStroke: Bool
    ) -> some View {
        modifier(NativeIconButtonBackgroundModifier(
            material: material,
            materialStroke: materialStroke,
            usesAccessibleMaterialStroke: usesAccessibleMaterialStroke
        ))
    }

    func nativeMaterialPanel(
        cornerRadius: CGFloat = Radius.lg,
        tintOpacity: Double = 0.62,
        strokeOpacity: Double = 0.74
    ) -> some View {
        modifier(NativeMaterialPanelModifier(
            cornerRadius: cornerRadius,
            tintOpacity: tintOpacity,
            strokeOpacity: strokeOpacity
        ))
    }

    func nativeMaterialPill(
        tintOpacity: Double = 0.66,
        strokeOpacity: Double = 0.72
    ) -> some View {
        modifier(NativeMaterialPillModifier(
            tintOpacity: tintOpacity,
            strokeOpacity: strokeOpacity
        ))
    }

    func nativeMaterialBar(
        tintOpacity: Double = 0.72,
        showsTopDivider: Bool = true,
        showsBottomDivider: Bool = false
    ) -> some View {
        modifier(NativeMaterialBarModifier(
            tintOpacity: tintOpacity,
            showsTopDivider: showsTopDivider,
            showsBottomDivider: showsBottomDivider
        ))
    }

    func nativeMaterialSheet(
        cornerRadius: CGFloat = 28,
        tintOpacity: Double = 0.88,
        strokeOpacity: Double = 0.68
    ) -> some View {
        modifier(NativeMaterialSheetModifier(
            cornerRadius: cornerRadius,
            tintOpacity: tintOpacity,
            strokeOpacity: strokeOpacity
        ))
    }

    func nativeSystemSheetPresentationChrome() -> some View {
        modifier(NativeSystemSheetPresentationModifier())
    }
}
