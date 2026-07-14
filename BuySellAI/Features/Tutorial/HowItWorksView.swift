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
                Button("Skip") {
                    onClose()
                }
                .brandFont(.button)
                .foregroundStyle(Color.brand.foreground)
                .frame(minWidth: 64, minHeight: 44)
                .accessibilityLabel("Skip")

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
            .animation(AppMotion.animation(reduceMotion: reduceMotion || appReduceMotion), value: index)
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
                    .accessibilityValue("Step \(index + 1) of \(slides.count)")

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
        reduceMotion || appReduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
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
        TutorialSlide(title: "Copy and paste.", body: "Your listing is written for you. Just paste it in.", illustration: 4)
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
                Text(slide.title)
                    .brandFont(.display)
                    .foregroundStyle(Color.brand.foreground)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)

                Text(slide.body)
                    .brandFont(.body)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, Spacing.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(slide.title) \(slide.body)")
        .accessibilityValue("Step \(step) of \(total)")
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
                Image(systemName: "camera.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(Color.brand.primary)
            case 2:
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 44, weight: .bold))
                    Text("$45")
                        .brandFont(.titleXL)
                }
                .foregroundStyle(Color.brand.primary)
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
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(Color.brand.primary)
            }
        }
    }
}

private struct DotPager: View {
    let index: Int
    let count: Int
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
        .animation(AppMotion.animation(reduceMotion: appReduceMotion), value: index)
    }

    private var inactiveColor: Color {
        differentiateWithoutColor ? Color.brand.borderStrong : Color.brand.border
    }
}
