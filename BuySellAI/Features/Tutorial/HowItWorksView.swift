import SwiftUI

struct HowItWorksView: View {
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appReduceMotion) private var appReduceMotion
    @State private var index = 0

    private let slides = TutorialSlide.slides

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Skip".localized) {
                    onClose()
                }
                .brandFont(.button)
                .foregroundStyle(Color.brand.foreground)
                .frame(minWidth: 64, minHeight: 44)
                .accessibilityLabel("Skip".localized)

                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.lg)

            Spacer(minLength: Spacing.xl)

            ZStack {
                ForEach(slides.indices, id: \.self) { slideIndex in
                    if slideIndex == index {
                        TutorialSlidePage(slide: slides[slideIndex], step: slideIndex + 1, total: slides.count)
                            .transition(transition)
                    }
                }
            }
            .animation(AppMotion.animation(reduceMotion: shouldReduceMotion), value: index)
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        if value.translation.width < -40 {
                            advance()
                        } else if value.translation.width > 40 {
                            retreat()
                        }
                    }
            )

            Spacer(minLength: Spacing.xl)

            HStack {
                DotPager(index: index, count: slides.count)

                Spacer()

                PrimaryPillButton(title: index == slides.count - 1 ? "Get started" : "Next", fillsWidth: false) {
                    advance()
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.brand.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .focusable()
        .onKeyPress(.space) {
            advance()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            advance()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            retreat()
            return .handled
        }
    }

    private var transition: AnyTransition {
        shouldReduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var shouldReduceMotion: Bool {
        AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)
    }

    private func advance() {
        if index == slides.count - 1 {
            onClose()
        } else {
            index += 1
        }
    }

    private func retreat() {
        index = max(0, index - 1)
    }
}

private struct TutorialSlide: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let illustration: Int

    static let slides: [TutorialSlide] = [
        TutorialSlide(title: "Welcome to BuySell.", body: "Turn stuff into cash in three taps.", illustration: 0),
        TutorialSlide(title: "Snap a photo.", body: "Point, tap, done. We handle the rest.", illustration: 1),
        TutorialSlide(title: "We figure out what it is.", body: "Name, category, condition, price — in seconds.", illustration: 2),
        TutorialSlide(title: "Pick where to sell.", body: "We rank every marketplace by how much you'd get.", illustration: 3),
        TutorialSlide(title: "Copy and paste.", body: "Your listing is written for you. Paste it in.", illustration: 4)
    ]
}

private struct TutorialSlidePage: View {
    let slide: TutorialSlide
    let step: Int
    let total: Int

    var body: some View {
        VStack(spacing: Spacing.xl) {
            TutorialIllustration(kind: slide.illustration)
                .frame(width: 240, height: 240)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.sm) {
                Text(slide.title.localized)
                    .brandFont(.display)
                    .foregroundStyle(Color.brand.foreground)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)

                Text(slide.body.localized)
                    .brandFont(.body)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, Spacing.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@ %@", slide.title.localized, slide.body.localized))
        .accessibilityValue(String.localizedFormat("Step %d of %d", step, total))
    }
}

private struct TutorialIllustration: View {
    let kind: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 64, style: .continuous)
                .fill(Color.brand.primaryMuted)

            Circle()
                .fill(Color.brand.primary.opacity(0.16))
                .frame(width: 160, height: 160)

            switch kind {
            case 0:
                BrandWordmark(size: .large)
                    .padding(Spacing.xl)
            case 1:
                SnapIllustration()
            case 2:
                AnalyzeIllustration()
            case 3:
                VStack(spacing: Spacing.xs) {
                    ForEach([Marketplace.craigslist, .facebook, .ebay], id: \.self) { marketplace in
                        HStack {
                            MarketplaceIcon(marketplace: marketplace, size: 32)
                            RoundedRectangle(cornerRadius: Radius.pill)
                                .fill(Color.brand.surface)
                                .frame(width: 92, height: 12)
                        }
                    }
                }
            default:
                CopyIllustration()
            }
        }
    }
}

private struct SnapIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(Color.brand.surface)
                .frame(width: 124, height: 92)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(Color.brand.primary, lineWidth: 5)
                )

            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.brand.primary)
                .frame(width: 42, height: 14)
                .offset(x: -30, y: -54)

            Circle()
                .fill(Color.brand.primaryMuted)
                .frame(width: 48, height: 48)
                .overlay(Circle().stroke(Color.brand.primary, lineWidth: 5))

            Circle()
                .fill(Color.brand.primary)
                .frame(width: 12, height: 12)
                .offset(x: 42, y: -26)
        }
    }
}

private struct AnalyzeIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.brand.primary.opacity(0.22), lineWidth: 14)
                .frame(width: 126, height: 126)

            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(Color.brand.primary)
                    .frame(width: index.isMultiple(of: 2) ? 14 : 10, height: index.isMultiple(of: 2) ? 14 : 10)
                    .offset(x: index < 2 ? -62 : 62, y: index.isMultiple(of: 2) ? -42 : 42)
            }

            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(Color.brand.surface)
                .frame(width: 118, height: 82)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(Color.brand.primary, lineWidth: 4)
                )

            VStack(spacing: Spacing.xxs) {
                Text("$45".localized)
                    .brandFont(.titleXL)
                    .foregroundStyle(Color.brand.primary)
                HStack(spacing: Spacing.xxs) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(Color.brand.primary.opacity(index == 1 ? 1 : 0.35))
                            .frame(width: 16, height: 5)
                    }
                }
            }
        }
    }
}

private struct CopyIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.brand.surface)
                .frame(width: 104, height: 134)
                .offset(x: -14, y: 10)
                .opacity(0.74)

            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.brand.surface)
                .frame(width: 112, height: 142)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .stroke(Color.brand.primary, lineWidth: 4)
                )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Capsule()
                    .fill(Color.brand.primary)
                    .frame(width: 62, height: 9)
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(Color.brand.primary.opacity(index == 3 ? 0.32 : 0.5))
                        .frame(width: index == 3 ? 46 : 78, height: 6)
                }
            }
            .offset(y: -12)

            RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                .fill(Color.brand.primary)
                .frame(width: 82, height: 28)
                .offset(y: 52)
        }
    }
}

private struct DotPager: View {
    let index: Int
    let count: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.appReduceMotion) private var appReduceMotion

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<count, id: \.self) { dot in
                Capsule()
                    .fill(dot == index ? Color.brand.primary : inactiveColor)
                    .frame(width: dot == index ? 24 : 8, height: 8)
            }
        }
        .animation(AppMotion.animation(reduceMotion: shouldReduceMotion), value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tutorial progress".localized)
        .accessibilityValue(String.localizedFormat("Step %d of %d", index + 1, count))
    }

    private var shouldReduceMotion: Bool {
        AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)
    }

    private var inactiveColor: Color {
        Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor)
    }
}
