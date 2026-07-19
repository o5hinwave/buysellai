import SwiftUI

struct HowItWorksView: View {
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appReduceMotion) private var appReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isKeyboardFocused: Bool

    private let steps = OnboardingStep.steps

    var body: some View {
        NavigationStack {
            List {
                Section {
                    OnboardingSummary()
                } footer: {
                    Text("No account required.".localized)
                }

                Section("Sell in three steps".localized) {
                    ForEach(steps) { step in
                        OnboardingStepRow(step: step)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.bottom, Spacing.huge, for: .scrollContent)
            .navigationTitle("Welcome to BuySell.".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip".localized) {
                        finish()
                    }
                    .accessibilityLabel("Skip".localized)
                }
            }
            .safeAreaInset(edge: .bottom) {
                footerAction
            }
        }
        .background(Color.brand.background.ignoresSafeArea())
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

    private var footerAction: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Ready when you are.".localized)
                        .brandFont(.caption)
                        .foregroundStyle(.secondary)

                    getStartedButton
                }
            } else {
                HStack(spacing: Spacing.md) {
                    Text("Ready when you are.".localized)
                        .brandFont(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: Spacing.md)

                    getStartedButton
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.md)
        .background(.bar)
        .animation(AppMotion.animation(reduceMotion: shouldReduceMotion), value: dynamicTypeSize.isAccessibilitySize)
    }

    private var getStartedButton: some View {
        Button {
            Haptics.impact(.light)
            finish()
        } label: {
            Text("Get started".localized)
                .brandFont(.button)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Color.brand.primary)
        .accessibilityLabel("Get started".localized)
    }

    private var shouldReduceMotion: Bool {
        AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)
    }

    private func finish() {
        onClose()
    }
}

private struct OnboardingSummary: View {
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "camera.viewfinder")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)
                .frame(width: 48, height: 48)
                .background(Color.brand.primaryMuted, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Sell anything in three taps.".localized)
                    .brandFont(.title)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Snap a photo. Pick a marketplace. Copy your listing.".localized)
                    .brandFont(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingStepRow: View {
    let step: OnboardingStep

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: step.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(step.title.localized)
                    .brandFont(.bodyLg)
                    .foregroundStyle(.primary)

                Text(step.detail.localized)
                    .brandFont(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@ %@", step.title.localized, step.detail.localized))
    }
}

private struct OnboardingStep: Identifiable {
    let id: Int
    let title: String
    let detail: String
    let systemImage: String

    static let steps = [
        OnboardingStep(
            id: 1,
            title: "Snap a photo.",
            detail: "Capture one clear item.",
            systemImage: "camera"
        ),
        OnboardingStep(
            id: 2,
            title: "Pick where to sell.",
            detail: "Compare estimated payouts.",
            systemImage: "list.bullet.rectangle"
        ),
        OnboardingStep(
            id: 3,
            title: "Copy and paste.",
            detail: "Use the ready listing wherever you sell.",
            systemImage: "doc.on.doc"
        )
    ]
}
