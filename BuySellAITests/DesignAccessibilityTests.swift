import XCTest
import SwiftUI
@testable import BuySellAI

final class DesignAccessibilityTests: XCTestCase {
    func testIconCircleButtonKeepsMinimumTapTargetForSmallVisualControls() {
        XCTAssertEqual(IconCircleButton.minimumTapTarget, 44)
        XCTAssertEqual(IconCircleButton.tapTargetSize(for: 40), 44)
        XCTAssertEqual(IconCircleButton.tapTargetSize(for: 44), 44)
        XCTAssertEqual(IconCircleButton.tapTargetSize(for: 56), 56)
    }

    func testChipButtonsKeepMinimumTapTarget() {
        XCTAssertEqual(ChipButton.minimumTapTarget, 44)
    }

    func testGhostButtonsUsePillShape() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)
        let ghostRange = try XCTUnwrap(source.range(of: "struct GhostButton: View"))
        let iconRange = try XCTUnwrap(source.range(of: "struct IconCircleButton: View"))
        let ghostSource = String(source[ghostRange.lowerBound..<iconRange.lowerBound])

        XCTAssertNotNil(ghostSource.range(of: ".background(Color.brand.surface, in: Capsule())"))
        XCTAssertNotNil(ghostSource.range(of: "Capsule()\n                    .stroke"))
        XCTAssertNil(ghostSource.range(of: "RoundedRectangle"))
    }

    func testAccessibleBorderUsesStrongTokenWhenDifferentiatingWithoutColor() {
        XCTAssertEqual(Color.brand.accessibilityBorderToken(differentiateWithoutColor: false), .standard)
        XCTAssertEqual(Color.brand.accessibilityBorderToken(differentiateWithoutColor: true), .strong)
    }

    func testAppReduceMotionParticipatesInSharedMotionDecisions() {
        XCTAssertFalse(AppMotion.shouldReduceMotion(os: false, app: false))
        XCTAssertTrue(AppMotion.shouldReduceMotion(os: true, app: false))
        XCTAssertTrue(AppMotion.shouldReduceMotion(os: false, app: true))
        XCTAssertTrue(AppMotion.shouldReduceMotion(os: true, app: true))
    }

    func testBrandTextStylesUseStaticFontFacesAndBoldTextVariants() {
        XCTAssertEqual(BrandTextStyle.display.fontResourceName(), "SpaceGrotesk-Bold")
        XCTAssertEqual(BrandTextStyle.titleXL.fontResourceName(), "SpaceGrotesk-SemiBold")
        XCTAssertEqual(BrandTextStyle.titleLg.fontResourceName(), "SpaceGrotesk-SemiBold")
        XCTAssertEqual(BrandTextStyle.title.fontResourceName(), "SpaceGrotesk-SemiBold")
        XCTAssertEqual(BrandTextStyle.bodyLg.fontResourceName(), "Inter-Medium")
        XCTAssertEqual(BrandTextStyle.body.fontResourceName(), "Inter-Regular")
        XCTAssertEqual(BrandTextStyle.caption.fontResourceName(), "Inter-Medium")
        XCTAssertEqual(BrandTextStyle.overline.fontResourceName(), "Inter-SemiBold")
        XCTAssertEqual(BrandTextStyle.button.fontResourceName(), "SpaceGrotesk-SemiBold")

        for style in BrandTextStyle.allCases {
            XCTAssertTrue(style.fontResourceName(legibilityWeight: .bold).hasSuffix("-Bold"))
        }
        XCTAssertEqual(BrandTextStyle.body.fontResourceName(legibilityWeight: .bold), "Inter-Bold")
        XCTAssertEqual(BrandTextStyle.button.fontResourceName(legibilityWeight: .bold), "SpaceGrotesk-Bold")
    }

    func testAuthWordmarkUsesBuySellAIWithoutOrangePeriod() throws {
        let auth = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)
        let typography = try String(contentsOf: projectURL("BuySellAI/Design/Typography.swift"), encoding: .utf8)

        XCTAssertNotNil(typography.range(of: "var showsPeriod = true"))
        XCTAssertNotNil(typography.range(of: "if showsPeriod"))
        XCTAssertNotNil(auth.range(of: #"BrandWordmark(includeAI: true, showsPeriod: false, size: .display)"#))
    }

    func testMarketplaceAccessibilityLabelsDescribePayoutAndDelta() {
        let below = MarketplaceEstimate(id: .ebay, payout: Decimal(41), deltaPct: -8.2, badge: .none)
        XCTAssertEqual(
            MarketplaceAccessibilityText.estimateLabel(for: below),
            "eBay, estimated payout 41 dollars, 8 percent below average"
        )

        let above = MarketplaceEstimate(id: .craigslist, payout: Decimal(45), deltaPct: 12.4, badge: .best)
        XCTAssertEqual(
            MarketplaceAccessibilityText.summaryLabel("Best", for: above),
            "Best, Craigslist, estimated payout 45 dollars, 12 percent above average"
        )

        let average = MarketplaceEstimate(id: .facebook, payout: Decimal(43), deltaPct: 0.2, badge: .none)
        XCTAssertEqual(
            MarketplaceAccessibilityText.estimateLabel(for: average),
            "Facebook, estimated payout 43 dollars, average payout"
        )
    }

    func testHistoryAccessibilityLabelIncludesDecodedThumbnailStatus() {
        let entry = HistoryEntry(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            itemName: "Lamp",
            category: .home,
            condition: .good,
            suggestedPrice: Decimal(45),
            imageThumbnail: ImageTools.sampleJPEG(),
            marketplace: .ebay,
            listingText: "TITLE:\nLamp"
        )

        XCTAssertEqual(HistoryAccessibilityText.thumbnailStatus(for: entry.imageThumbnail), "photo attached")
        XCTAssertEqual(
            HistoryAccessibilityText.rowLabel(for: entry, relativeDate: "2h ago"),
            "Lamp, eBay, 2h ago, photo attached"
        )
        XCTAssertEqual(HistoryAccessibilityText.thumbnailStatus(for: Data([0x00, 0x01])), "no photo")
        XCTAssertEqual(HistoryAccessibilityText.thumbnailStatus(for: nil), "no photo")
    }

    func testChipAccessibilityLabelsDescribeControlAndCurrentValue() {
        XCTAssertEqual(
            ChipAccessibilityText.valueLabel("Category", value: "Furniture"),
            "Category, Furniture"
        )
        XCTAssertEqual(
            ChipAccessibilityText.valueLabel("Condition", value: "Like New"),
            "Condition, Like New"
        )
    }

    func testButtonsAvoidEmptyAccessibilityHints() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "optionalAccessibilityHint(accessibilityHint)"))
        XCTAssertNil(source.range(of: #"accessibilityHint\?\.\S+\s*\?\?\s*"""#, options: .regularExpression))
    }

    func testSnapResultChipsExposePurposeAndActionHints() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"ChipAccessibilityText.valueLabel("Category""#))
        XCTAssertNotNil(source.range(of: #"accessibilityHint: "Changes the category""#))
        XCTAssertNotNil(source.range(of: #"ChipAccessibilityText.valueLabel("Condition""#))
        XCTAssertNotNil(source.range(of: #"accessibilityHint: "Changes the condition""#))
    }

    func testSnapResultStillWorkingHintAnnouncesAlertAndRetryAction() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"import UIKit"#))
        XCTAssertNotNil(source.range(of: #".onChange(of: store.showStillWorking)"#))
        XCTAssertNotNil(source.range(of: #".accessibilityIdentifier("SnapResult.StillWorkingAlert")"#))
        XCTAssertNotNil(source.range(of: #"UIAccessibility.post("#))
        XCTAssertNotNil(source.range(of: #"notification: .announcement"#))
        XCTAssertNotNil(source.range(of: #"SecondaryPillButton(title: "Retry""#))
    }

    func testSnapResultErrorStateOffersRetakeBeforeRetry() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)
        let errorRange = try XCTUnwrap(source.range(of: "private func errorView(message: String) -> some View"))
        let fieldRange = try XCTUnwrap(source.range(of: "private enum Field"))
        let errorSource = String(source[errorRange.lowerBound..<fieldRange.lowerBound])

        let retakeRange = try XCTUnwrap(errorSource.range(of: #"PrimaryPillButton(title: "Retake photo", systemImage: "camera.rotate")"#))
        let retryRange = try XCTUnwrap(errorSource.range(of: #"SecondaryPillButton(title: "Try again", systemImage: "arrow.clockwise")"#))

        XCTAssertLessThan(retakeRange.lowerBound, retryRange.lowerBound)
    }

    func testHomeDisplayHeadlineSupportsAccessibilityThreeWithoutSingleLineTruncation() throws {
        let root = try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)

        XCTAssertNotNil(root.range(of: #".dynamicTypeLimit()"#))
        XCTAssertNotNil(home.range(of: #"Text("Sell anything in three taps.".localized)"#))
        XCTAssertNotNil(home.range(of: #".lineLimit(3)"#))
        XCTAssertNotNil(home.range(of: #".minimumScaleFactor(0.78)"#))
    }

    func testHomeHeaderSignInButtonKeepsMinimumTapTarget() throws {
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)

        XCTAssertNotNil(home.range(of: #"Text((appStore.session == nil ? "Sign in" : "Sign out").localized)"#))
        XCTAssertNotNil(home.range(of: #".frame(minHeight: 44)"#))
    }

    func testHomeSettingsGearUsesFortyPointVisualWithMinimumTapTarget() throws {
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)

        XCTAssertNotNil(home.range(of: #"IconCircleButton(systemImage: "gearshape.fill", accessibilityLabel: "Settings", size: 40)"#))
        XCTAssertNotNil(home.range(of: #".frame(width: 44, height: 44)"#))
    }

    func testPrimaryGlowIsScopedToHomeSnapButton() throws {
        let buttons = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)
        let designTokens = try String(contentsOf: projectURL("BuySellAI/Design/DesignTokens.swift"), encoding: .utf8)
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)
        let appSources = try appSwiftFiles()
            .filter { $0.lastPathComponent != "HomeView.swift" }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")

        XCTAssertNotNil(buttons.range(of: "var showsGlow = false"))
        XCTAssertNotNil(designTokens.range(of: "static func primaryGlow() -> some ViewModifier"))
        XCTAssertNotNil(designTokens.range(of: "ShadowModifier(color: Color.brand.primary.opacity(0.35), radius: 30, y: 12)"))
        XCTAssertNotNil(buttons.range(of: "PrimaryGlowModifier(isEnabled: showsGlow)"))
        XCTAssertNotNil(buttons.range(of: "content.modifier(AppShadow.primaryGlow())"))
        XCTAssertNotNil(home.range(of: #"PrimaryPillButton(title: "Snap to sell", systemImage: "camera.fill", showsGlow: true)"#))
        XCTAssertNil(appSources.range(of: "showsGlow: true"))
    }

    func testPresentedSheetsExposeVoiceOverSortPriorities() throws {
        let snapResult = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)
        let marketplace = try String(contentsOf: projectURL("BuySellAI/Features/MarketplacePicker/MarketplacePickerSheet.swift"), encoding: .utf8)
        let listing = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)
        let auth = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)

        XCTAssertGreaterThanOrEqual(snapResult.components(separatedBy: ".accessibilitySortPriority").count - 1, 5)
        XCTAssertGreaterThanOrEqual(marketplace.components(separatedBy: ".accessibilitySortPriority").count - 1, 4)
        XCTAssertGreaterThanOrEqual(listing.components(separatedBy: ".accessibilitySortPriority").count - 1, 6)
        XCTAssertGreaterThanOrEqual(auth.components(separatedBy: ".accessibilitySortPriority").count - 1, 5)
        XCTAssertGreaterThanOrEqual(settings.components(separatedBy: ".accessibilitySortPriority").count - 1, 6)
    }

    func testAuthEmailSignInUsesNavigationPush() throws {
        let authView = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)
        let authStore = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthStore.swift"), encoding: .utf8)

        XCTAssertNotNil(authView.range(of: #"NavigationStack(path: $path)"#))
        XCTAssertNotNil(authView.range(of: #"path.append(.email)"#))
        XCTAssertNotNil(authView.range(of: #".navigationDestination(for: AuthRoute.self)"#))
        XCTAssertNotNil(authView.range(of: #"private struct EmailSignInView"#))
        XCTAssertNil(authView.range(of: "showsEmailForm"))
        XCTAssertNil(authStore.range(of: "showsEmailForm"))
    }

    func testAuthSignInProviderButtonsUseFiftySixPointPills() throws {
        let authView = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)
        let buttons = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)

        XCTAssertNotNil(buttons.range(of: #".frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 56)"#))
        XCTAssertNotNil(
            authView.range(of: #"SecondaryPillButton(title: "Continue with Email", systemImage: "envelope.fill", minHeight: 56)"#)
        )
    }

    func testDeleteAccountNavigationLinkHasExplicitVoiceOverLabel() throws {
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)

        XCTAssertNotNil(settings.range(of: #"NavigationLink("Delete account".localized)"#))
        XCTAssertNotNil(settings.range(of: #".accessibilityLabel("Delete account".localized)"#))
    }

    func testSettingsPreferenceControlsHaveExplicitVoiceOverLabels() throws {
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)

        XCTAssertNotNil(settings.range(of: #"Picker("Theme".localized"#))
        XCTAssertNotNil(settings.range(of: #".accessibilityLabel("Theme".localized)"#))
        XCTAssertNotNil(settings.range(of: #"Toggle("Reduce Motion".localized"#))
        XCTAssertNotNil(settings.range(of: #".accessibilityLabel("Reduce Motion".localized)"#))
    }

    func testEveryDirectSwiftUIButtonHasExplicitAccessibilityLabel() throws {
        let buttonPattern = #"(?<![A-Za-z0-9_])Button\s*(?:\(|\{)"#
        var unlabeledButtons: [String] = []

        for sourceFile in try appSwiftFiles() {
            let source = try String(contentsOf: sourceFile, encoding: .utf8)
            let lines = source.components(separatedBy: .newlines)

            for (index, line) in lines.enumerated() where line.range(of: buttonPattern, options: .regularExpression) != nil {
                let expression = buttonExpression(startingAt: index, in: lines)
                if expression.range(of: ".accessibilityLabel") == nil {
                    unlabeledButtons.append("\(relativePath(sourceFile)):\(index + 1)")
                }
            }
        }

        XCTAssertTrue(
            unlabeledButtons.isEmpty,
            "Direct SwiftUI Buttons need explicit accessibility labels: \(unlabeledButtons.joined(separator: ", "))"
        )
    }

    func testSettingsKeepsFiveSectionLimitAndGatedDangerZone() throws {
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)

        XCTAssertEqual(settings.components(separatedBy: #"Section(""#).count - 1, 5)
        XCTAssertNotNil(settings.range(of: #"Section("Account".localized)"#))
        XCTAssertNotNil(settings.range(of: #"Section("Appearance".localized)"#))
        XCTAssertNotNil(settings.range(of: #"Section("App".localized)"#))
        XCTAssertNotNil(settings.range(of: #"Section("About".localized)"#))
        XCTAssertNotNil(settings.range(of: #".listStyle(.insetGrouped)"#))
        XCTAssertNotNil(
            settings.range(
                of: #"if\s+appStore\.session\s*!=\s*nil\s*\{\s*Section\("Danger zone"\.localized\)"#,
                options: .regularExpression
            )
        )
    }

    func testCameraControlsExposeVoiceOverLabelsAndStayCameraOnly() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraView.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"accessibilityLabel("Take photo".localized)"#))
        XCTAssertNotNil(source.range(of: #"accessibilityHint("Captures the current view".localized)"#))
        XCTAssertNotNil(source.range(of: #"accessibilityLabel: "Close camera""#))
        XCTAssertNotNil(source.range(of: #"accessibilityLabel: flashAccessibilityLabel"#))
        XCTAssertNotNil(source.range(of: #"guard isFlashAvailable else { return "Flash unavailable" }"#))
        XCTAssertNil(source.range(of: "PhotosPicker"))
        XCTAssertNil(source.range(of: "PHPickerViewController"))
        XCTAssertNil(source.range(of: "UIImagePickerController"))
    }

    func testAnimatedSurfacesUseSharedReduceMotionDecision() throws {
        let root = try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)
        let designTokens = try String(contentsOf: projectURL("BuySellAI/Design/DesignTokens.swift"), encoding: .utf8)
        let buttons = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)
        let toast = try String(contentsOf: projectURL("BuySellAI/Design/Toast.swift"), encoding: .utf8)
        let camera = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraView.swift"), encoding: .utf8)
        let tutorial = try String(contentsOf: projectURL("BuySellAI/Features/Tutorial/HowItWorksView.swift"), encoding: .utf8)

        XCTAssertNotNil(root.range(of: #".environment(\.appReduceMotion, appStore.reduceMotion)"#))
        XCTAssertNotNil(root.range(of: #"withAnimation(AppMotion.screenAnimation(reduceMotion: shouldReduceMotion))"#))
        XCTAssertNotNil(designTokens.range(of: #"static let screen = Animation.easeOut(duration: 0.2)"#))
        XCTAssertNotNil(designTokens.range(of: "static func screenAnimation(reduceMotion: Bool) -> Animation"))
        XCTAssertGreaterThanOrEqual(buttons.components(separatedBy: "AppMotion.shouldReduceMotion").count - 1, 3)
        XCTAssertGreaterThanOrEqual(buttons.components(separatedBy: ".opacity(pressed ? 0.82 : 1)").count - 1, 2)
        XCTAssertNotNil(buttons.range(of: ".opacity(configuration.isPressed ? 0.82 : 1)"))
        XCTAssertNotNil(toast.range(of: "AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)"))
        XCTAssertNotNil(camera.range(of: "AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)"))
        XCTAssertNotNil(camera.range(of: ".task(id: shouldReduceMotion)"))
        XCTAssertGreaterThanOrEqual(tutorial.components(separatedBy: "AppMotion.shouldReduceMotion").count - 1, 2)
    }

    func testSkeletonShimmerFreezesUnderReduceMotion() throws {
        let toast = try String(contentsOf: projectURL("BuySellAI/Design/Toast.swift"), encoding: .utf8)

        XCTAssertNotNil(toast.range(of: "struct SkeletonLine"))
        XCTAssertNotNil(toast.range(of: ".task(id: shouldReduceMotion)"))
        XCTAssertNotNil(toast.range(of: "if shouldReduceMotion {\n                    phase = false\n                    return"))
        XCTAssertNotNil(toast.range(of: "startPoint: shimmerStartPoint"))
        XCTAssertNotNil(toast.range(of: "endPoint: shimmerEndPoint"))
        XCTAssertGreaterThanOrEqual(toast.components(separatedBy: "shouldReduceMotion || phase").count - 1, 2)
    }

    func testTutorialUsesCustomIllustrationShapesInsteadOfSystemSymbols() throws {
        let tutorial = try String(contentsOf: projectURL("BuySellAI/Features/Tutorial/HowItWorksView.swift"), encoding: .utf8)

        XCTAssertNil(tutorial.range(of: #"Image(systemName:"#))
        XCTAssertNotNil(tutorial.range(of: "private struct SnapIllustration"))
        XCTAssertNotNil(tutorial.range(of: "private struct AnalyzeIllustration"))
        XCTAssertNotNil(tutorial.range(of: "private struct CopyIllustration"))
    }

    func testTutorialSlidesAndDotPagerExposeStepValues() throws {
        let tutorial = try String(contentsOf: projectURL("BuySellAI/Features/Tutorial/HowItWorksView.swift"), encoding: .utf8)

        XCTAssertNotNil(tutorial.range(of: #"TutorialSlidePage(slide: slides[slideIndex], step: slideIndex + 1, total: slides.count)"#))
        XCTAssertNotNil(tutorial.range(of: #".accessibilityValue(String.localizedFormat("Step %d of %d", step, total))"#))
        XCTAssertNotNil(tutorial.range(of: #".accessibilityLabel("Tutorial progress".localized)"#))
        XCTAssertNotNil(tutorial.range(of: #".accessibilityValue(String.localizedFormat("Step %d of %d", index + 1, count))"#))
    }

    func testListingGeneratedTextPanelMatchesPromptRequirements() throws {
        let listing = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)
        let panelRange = try XCTUnwrap(listing.range(of: "private var listingText: some View"))
        let errorRange = try XCTUnwrap(listing.range(of: "private func error", range: panelRange.upperBound..<listing.endIndex))
        let panelSource = String(listing[panelRange.lowerBound..<errorRange.lowerBound])

        XCTAssertNotNil(panelSource.range(of: "Text(store.listingText)"))
        XCTAssertNotNil(panelSource.range(of: ".brandFont(.body)"))
        XCTAssertNotNil(panelSource.range(of: ".lineSpacing(4)"))
        XCTAssertNotNil(panelSource.range(of: ".textSelection(.enabled)"))
        XCTAssertNotNil(panelSource.range(of: ".background(Color.brand.secondary, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))"))
        XCTAssertNotNil(panelSource.range(of: #".accessibilityLabel("Generated listing text".localized)"#))
    }

    func testListingSuccessActionsAreStickyAndOrderedAfterGenerationSucceeds() throws {
        let listing = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)
        let bottomRange = try XCTUnwrap(listing.range(of: "private var successBottomActions: some View"))
        let regenerateRange = try XCTUnwrap(listing.range(of: "private func regenerateListing", range: bottomRange.upperBound..<listing.endIndex))
        let bottomSource = String(listing[bottomRange.lowerBound..<regenerateRange.lowerBound])

        XCTAssertNotNil(listing.range(of: ".safeAreaInset(edge: .bottom)"))
        XCTAssertNotNil(listing.range(of: "case .success:\n            successBottomActions"))
        XCTAssertNotNil(listing.range(of: "case .idle, .loading, .failed:\n            EmptyView()"))
        XCTAssertNotNil(bottomSource.range(of: ".background(.regularMaterial)"))

        let copyRange = try XCTUnwrap(bottomSource.range(of: #"PrimaryPillButton(title: "Copy listing""#))
        let retakeRange = try XCTUnwrap(bottomSource.range(of: #"GhostButton(title: "Wrong item — retake""#))
        let regenerateButtonRange = try XCTUnwrap(bottomSource.range(of: #"GhostButton(title: "Regenerate""#))
        let footerRange = try XCTUnwrap(bottomSource.range(of: #"Text("Tip: paste, add photos, hit list. That's it.".localized)"#))

        XCTAssertLessThan(copyRange.lowerBound, retakeRange.lowerBound)
        XCTAssertLessThan(retakeRange.lowerBound, regenerateButtonRange.lowerBound)
        XCTAssertLessThan(regenerateButtonRange.lowerBound, footerRange.lowerBound)
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }

    private func relativePath(_ url: URL) -> String {
        let root = projectURL("")
        return url.path.replacingOccurrences(of: root.path + "/", with: "")
    }

    private func appSwiftFiles() throws -> [URL] {
        let root = projectURL("BuySellAI")
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item -> URL? in
            guard let url = item as? URL else { return nil }
            let values = try url.resourceValues(forKeys: resourceKeys)
            guard values.isRegularFile == true, url.pathExtension == "swift" else { return nil }
            return url
        }
    }

    private func buttonExpression(startingAt startIndex: Int, in lines: [String]) -> String {
        var expression = lines[startIndex] + "\n"
        var delimiterBalance = delimiterBalance(in: lines[startIndex])
        var index = startIndex + 1

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if delimiterBalance > 0 || trimmed.hasPrefix(".") || trimmed.isEmpty {
                expression += line + "\n"
                delimiterBalance += self.delimiterBalance(in: line)
                index += 1
            } else {
                break
            }
        }

        return expression
    }

    private func delimiterBalance(in line: String) -> Int {
        line.reduce(into: 0) { balance, character in
            switch character {
            case "(", "{", "[":
                balance += 1
            case ")", "}", "]":
                balance -= 1
            default:
                break
            }
        }
    }
}
