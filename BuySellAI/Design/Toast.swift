import SwiftUI

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let style: ToastStyle
}

enum ToastStyle: Equatable {
    case success
    case error
    case info

    var tint: Color {
        switch self {
        case .success: Color.brand.success
        case .error: Color.brand.destructive
        case .info: Color.brand.info
        }
    }

    var icon: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }
}

struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: toast.style.icon)
                .foregroundStyle(toast.style.tint)
            Text(toast.text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .nativeMaterialPill(tintOpacity: 0.78, strokeOpacity: 0.84)
        .modifier(AppShadow.hover())
        .padding(.horizontal, Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(toast.text)
        .accessibilityIdentifier("Toast")
    }
}

struct SkeletonLine: View {
    var height: CGFloat = 14
    var width: CGFloat?

    @State private var phase = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appReduceMotion) private var appReduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.brand.secondary,
                        Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor).opacity(0.45),
                        Color.brand.secondary
                    ],
                    startPoint: shimmerStartPoint,
                    endPoint: shimmerEndPoint
                )
            )
            .frame(width: width, height: height)
            .task(id: shouldReduceMotion) {
                if shouldReduceMotion {
                    phase = false
                    return
                }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = true
                }
            }
            .accessibilityHidden(true)
    }

    private var shouldReduceMotion: Bool {
        AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)
    }

    private var shimmerStartPoint: UnitPoint {
        shouldReduceMotion || phase ? .leading : .trailing
    }

    private var shimmerEndPoint: UnitPoint {
        shouldReduceMotion || phase ? .trailing : .leading
    }
}
