import SwiftUI

struct HowItWorksView: View {
    let onClose: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isKeyboardFocused: Bool

    private let steps = TutorialStep.steps

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerControls

                guideContent

                footerControls
            }
            .padding(.horizontal, horizontalPadding)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .focusable()
        .focused($isKeyboardFocused)
        .task {
            isKeyboardFocused = true
        }
        .onKeyPress(.space) {
            finish()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            finish()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            return .handled
        }
    }

    private var headerControls: some View {
        HStack {
            Spacer(minLength: Spacing.md)

            TextActionButton(title: "Skip", minWidth: 64) {
                finish()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.top, Spacing.sm)
    }

    private var guideContent: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: contentSpacing) {
                    Spacer(minLength: Spacing.md)

                    CompactGuideGraphic()
                        .frame(width: graphicWidth(in: geometry), height: graphicHeight)

                    VStack(spacing: Spacing.md) {
                        Text("Sell anything in three taps.".localized)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(Color.brand.foreground)
                            .multilineTextAlignment(.center)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                            .minimumScaleFactor(0.78)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Take a photo. We suggest where to sell and write the listing.".localized)
                            .font(.body)
                            .foregroundStyle(Color.brand.foregroundSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 440)

                    VStack(spacing: Spacing.sm) {
                        ForEach(steps) { step in
                            TutorialStepRow(step: step)
                        }
                    }
                    .frame(maxWidth: 520)
                    .accessibilityElement(children: .contain)

                    Spacer(minLength: Spacing.md)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
                .padding(.vertical, Spacing.lg)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var footerControls: some View {
        Button {
            Haptics.impact(.light)
            finish()
        } label: {
            Text("Start selling".localized)
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, Spacing.lg)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.brand.primary)
        .accessibilityLabel("Start selling".localized)
        .padding(.bottom, Spacing.lg)
    }

    private var horizontalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? Spacing.lg : Spacing.xl
    }

    private var contentSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? Spacing.lg : Spacing.xxl
    }

    private var graphicHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 136 : 164
    }

    private func graphicWidth(in geometry: GeometryProxy) -> CGFloat {
        min(420, max(260, geometry.size.width * 0.84))
    }

    private func finish() {
        onClose()
    }
}

private struct CompactGuideGraphic: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            GuideGlyph(systemName: "camera.viewfinder", label: "Photo")
            Connector()
            GuideGlyph(systemName: "sparkles.rectangle.stack", label: "Place")
            Connector()
            GuideGlyph(systemName: "doc.on.clipboard", label: "Listing")
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(Color.brand.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .strokeBorder(Color.brand.border, lineWidth: 1)
        )
        .modifier(AppShadow.raised())
        .accessibilityHidden(true)
    }
}

private struct GuideGlyph: View {
    let systemName: String
    let label: String

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: systemName)
                .symbolRenderingMode(.hierarchical)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(Color.brand.primaryMuted)
                )

            Text(label.localized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.foregroundSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct Connector: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.brand.mutedForeground)
            .accessibilityHidden(true)
    }
}

private struct TutorialStepRow: View {
    let step: TutorialStep

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: step.systemImage)
                .symbolRenderingMode(.hierarchical)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.brand.primaryMuted)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(step.title.localized)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                    .fixedSize(horizontal: false, vertical: true)

                Text(step.detail.localized)
                    .font(.subheadline)
                    .foregroundStyle(Color.brand.foregroundSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.brand.surface)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct TutorialStep: Identifiable {
    let id: Int
    let systemImage: String
    let title: String
    let detail: String

    static let steps = [
        TutorialStep(
            id: 1,
            systemImage: "camera",
            title: "Take a clear photo",
            detail: "Fit the whole item in the frame."
        ),
        TutorialStep(
            id: 2,
            systemImage: "list.bullet.rectangle",
            title: "Choose where to sell",
            detail: "We suggest the best place first."
        ),
        TutorialStep(
            id: 3,
            systemImage: "doc.on.clipboard",
            title: "Copy the listing",
            detail: "Paste it into the marketplace when you are ready."
        )
    ]
}
