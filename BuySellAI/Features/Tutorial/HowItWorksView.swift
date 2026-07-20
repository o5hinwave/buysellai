import SwiftUI

struct HowItWorksView: View {
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appReduceMotion) private var appReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isKeyboardFocused: Bool
    @State private var selectedIndex = 0
    @State private var slideDirection = 1

    private let slides = TutorialSlide.slides

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerControls

                slidePager

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
            advanceOrFinish()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            incrementSlide()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            decrementSlide()
            return .handled
        }
    }

    private var headerControls: some View {
        HStack {
            TextActionButton(title: "Skip", minWidth: 64) {
                finish()
            }

            Spacer(minLength: Spacing.md)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.top, Spacing.sm)
    }

    private var slidePager: some View {
        ZStack {
            TutorialSlidePage(slide: slides[selectedIndex])
                .id(selectedIndex)
                .transition(slideTransition)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(slideSwipeGesture)
        .animation(AppMotion.screenAnimation(reduceMotion: shouldReduceMotion), value: selectedIndex)
    }

    private var footerControls: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Spacing.md) {
                    DotPager(count: slides.count, selectedIndex: $selectedIndex)

                    nextButton
                        .frame(maxWidth: .infinity)
                }
            } else {
                ZStack {
                    DotPager(count: slides.count, selectedIndex: $selectedIndex)

                    HStack {
                        Spacer(minLength: Spacing.md)

                        nextButton
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 104 : 64)
        .padding(.bottom, Spacing.lg)
        .animation(AppMotion.animation(reduceMotion: shouldReduceMotion), value: dynamicTypeSize.isAccessibilitySize)
    }

    private var nextButton: some View {
        Button {
            Haptics.impact(.light)
            advanceOrFinish()
        } label: {
            Text(nextButtonTitle.localized)
                .brandFont(.button)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? nil : 96, minHeight: 44)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                .padding(.horizontal, Spacing.lg)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Color.brand.primary)
        .accessibilityLabel(nextButtonTitle.localized)
    }

    private var slideSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                if value.translation.width < -44 {
                    incrementSlide()
                } else if value.translation.width > 44 {
                    decrementSlide()
                }
            }
    }

    private var slideTransition: AnyTransition {
        guard shouldReduceMotion == false else {
            return .opacity
        }

        let insertionEdge: Edge = slideDirection >= 0 ? .trailing : .leading
        let removalEdge: Edge = slideDirection >= 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private var nextButtonTitle: String {
        isLastSlide ? "Get started" : "Next"
    }

    private var isLastSlide: Bool {
        selectedIndex == slides.count - 1
    }

    private var shouldReduceMotion: Bool {
        AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)
    }

    private var horizontalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? Spacing.lg : Spacing.xl
    }

    private func advanceOrFinish() {
        if isLastSlide {
            finish()
        } else {
            incrementSlide()
        }
    }

    private func incrementSlide() {
        moveToSlide(selectedIndex + 1, direction: 1)
    }

    private func decrementSlide() {
        moveToSlide(selectedIndex - 1, direction: -1)
    }

    private func moveToSlide(_ index: Int, direction: Int) {
        let boundedIndex = min(max(index, 0), slides.count - 1)
        guard boundedIndex != selectedIndex else { return }
        slideDirection = direction
        selectedIndex = boundedIndex
    }

    private func finish() {
        onClose()
    }
}

private struct TutorialSlidePage: View {
    let slide: TutorialSlide

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: pageSpacing) {
                    Spacer(minLength: Spacing.md)

                    TutorialIllustration(kind: slide.illustration)
                        .frame(width: illustrationSize(in: geometry), height: illustrationSize(in: geometry))

                    VStack(spacing: Spacing.md) {
                        Text(slide.title.localized)
                            .brandFont(.display)
                            .foregroundStyle(Color.brand.foreground)
                            .multilineTextAlignment(.center)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                            .minimumScaleFactor(0.78)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(slide.detail.localized)
                            .brandFont(.bodyLg)
                            .foregroundStyle(Color.brand.foregroundSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 420)

                    Spacer(minLength: Spacing.md)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
                .padding(.vertical, Spacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
    }

    private var pageSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? Spacing.lg : Spacing.xxl
    }

    private func illustrationSize(in geometry: GeometryProxy) -> CGFloat {
        let heightBound = geometry.size.height * (dynamicTypeSize.isAccessibilitySize ? 0.34 : 0.42)
        let widthBound = geometry.size.width * 0.76
        return max(144, min(240, min(heightBound, widthBound)))
    }
}

private struct DotPager: View {
    let count: Int
    @Binding var selectedIndex: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<count, id: \.self) { index in
                Button {
                    Haptics.impact(.light)
                    selectedIndex = index
                } label: {
                    Capsule()
                        .fill(index == selectedIndex ? Color.brand.primary : Color.brand.border)
                        .frame(width: index == selectedIndex ? 24 : 8, height: 8)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String.localizedFormat("Step %d".localized, index + 1))
                .accessibilityValue(
                    String.localizedFormat(
                        "Step %d of %d".localized,
                        index + 1,
                        count
                    )
                )
                .accessibilityHint(index == selectedIndex ? "Current step".localized : "Shows this step".localized)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct TutorialIllustration: View {
    let kind: TutorialIllustrationKind

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(Color.brand.primaryMuted)

            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .strokeBorder(Color.brand.primary.opacity(0.24), lineWidth: 1)

            switch kind {
            case .welcome:
                WelcomeIllustration()
            case .snap:
                SnapIllustration()
            case .analyze:
                AnalyzeIllustration()
            case .pick:
                PickIllustration()
            case .copy:
                CopyIllustration()
            }
        }
        .modifier(AppShadow.raised())
        .accessibilityHidden(true)
    }
}

private struct WelcomeIllustration: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            BrandWordmark(size: .large)

            HStack(spacing: Spacing.xs) {
                MiniStepPill(width: 42)
                MiniStepPill(width: 58)
                MiniStepPill(width: 46)
            }

            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.brand.primary)
                .frame(width: 96, height: 18)
        }
        .padding(Spacing.xl)
    }
}

private struct SnapIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.brand.surface)
                .frame(width: 126, height: 96)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.brand.primary, lineWidth: 4)
                )

            Circle()
                .fill(Color.brand.primaryMuted)
                .frame(width: 52, height: 52)
                .overlay(Circle().strokeBorder(Color.brand.primary, lineWidth: 6))

            RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                .fill(Color.brand.primary)
                .frame(width: 34, height: 10)
                .offset(x: -38, y: -58)

            ViewfinderCorners()
                .stroke(Color.brand.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: 154, height: 124)
        }
    }
}

private struct AnalyzeIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.brand.surface)
                .frame(width: 136, height: 118)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.brand.borderStrong, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: Spacing.sm) {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(Color.brand.primary.opacity(0.2))
                    .frame(width: 78, height: 42)

                RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                    .fill(Color.brand.foreground.opacity(0.18))
                    .frame(width: 84, height: 8)

                HStack(spacing: Spacing.xs) {
                    Capsule()
                        .fill(Color.brand.primary)
                        .frame(width: 44, height: 18)

                    Text("$45".localized)
                        .brandFont(.caption)
                        .foregroundStyle(Color.brand.primaryText)
                }
            }
            .offset(x: -4)

            Rectangle()
                .fill(Color.brand.primary.opacity(0.72))
                .frame(width: 152, height: 3)
                .offset(y: -20)
        }
    }
}

private struct PickIllustration: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            MarketplaceChoice(width: 126, payout: "$45", isBest: true)
            MarketplaceChoice(width: 116, payout: "$41", isBest: false)
            MarketplaceChoice(width: 104, payout: "$38", isBest: false)
        }
    }
}

private struct CopyIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.brand.surface)
                .frame(width: 116, height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.brand.borderStrong, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Capsule()
                    .fill(Color.brand.primary)
                    .frame(width: 58, height: 12)

                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(Color.brand.foreground.opacity(0.14))
                        .frame(width: index == 3 ? 54 : 78, height: 7)
                }
            }
            .offset(y: -10)

            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.brand.primary)
                .frame(width: 48, height: 34)
                .offset(x: 42, y: 46)
                .overlay(
                    Checkmark()
                        .stroke(Color.brand.primaryForeground, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .frame(width: 20, height: 14)
                        .offset(x: 42, y: 46)
                )
        }
    }
}

private struct MiniStepPill: View {
    let width: CGFloat

    var body: some View {
        Capsule()
            .fill(Color.brand.surface)
            .frame(width: width, height: 16)
            .overlay(Capsule().strokeBorder(Color.brand.primary.opacity(0.3), lineWidth: 1))
    }
}

private struct MarketplaceChoice: View {
    let width: CGFloat
    let payout: String
    let isBest: Bool

    var body: some View {
        HStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(isBest ? Color.brand.success : Color.brand.primary)
                .frame(width: 28, height: 28)

            Capsule()
                .fill(Color.brand.surface)
                .frame(width: width, height: 12)

            Text(payout.localized)
                .brandFont(.caption)
                .foregroundStyle(isBest ? Color.brand.success : Color.brand.primaryText)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

private struct ViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length = min(rect.width, rect.height) * 0.22

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))

        return path
    }
}

private struct Checkmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX * 0.86, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

private struct TutorialSlide: Identifiable {
    let id: Int
    let title: String
    let detail: String
    let illustration: TutorialIllustrationKind

    static let slides = [
        TutorialSlide(
            id: 1,
            title: "Welcome to BuySell.",
            detail: "Turn stuff into cash in three taps.",
            illustration: .welcome
        ),
        TutorialSlide(
            id: 2,
            title: "Snap a photo.",
            detail: "Point, tap, done. We handle the rest.",
            illustration: .snap
        ),
        TutorialSlide(
            id: 3,
            title: "We figure out what it is.",
            detail: "Name, category, condition, price — in seconds.",
            illustration: .analyze
        ),
        TutorialSlide(
            id: 4,
            title: "Pick where to sell.",
            detail: "We rank every marketplace by how much you'd get.",
            illustration: .pick
        ),
        TutorialSlide(
            id: 5,
            title: "Copy and paste.",
            detail: "Your listing is written for you. Paste it in.",
            illustration: .copy
        )
    ]
}

private enum TutorialIllustrationKind {
    case welcome
    case snap
    case analyze
    case pick
    case copy
}
