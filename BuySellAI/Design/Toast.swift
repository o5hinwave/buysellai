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
                .font(.brandCaption)
                .foregroundStyle(Color.brand.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.brand.surfaceElevated, in: Capsule())
        .overlay(Capsule().stroke(Color.brand.border, lineWidth: 1))
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

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.brand.secondary,
                        Color.brand.border.opacity(0.45),
                        Color.brand.secondary
                    ],
                    startPoint: phase ? .leading : .trailing,
                    endPoint: phase ? .trailing : .leading
                )
            )
            .frame(width: width, height: height)
            .task {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = true
                }
            }
            .accessibilityHidden(true)
    }
}
