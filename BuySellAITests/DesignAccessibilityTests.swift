import XCTest
import SwiftUI
import ImageIO
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

    func testSharedActionPrimitivesUseSemanticNativeTypography() throws {
        let buttons = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)
        let chips = try String(contentsOf: projectURL("BuySellAI/Design/Chips.swift"), encoding: .utf8)
        let toast = try String(contentsOf: projectURL("BuySellAI/Design/Toast.swift"), encoding: .utf8)

        XCTAssertEqual(buttons.components(separatedBy: ".font(.headline.weight(.semibold))").count - 1, 1)
        XCTAssertNotNil(chips.range(of: ".font(.caption.weight(.semibold))"))
        XCTAssertNotNil(toast.range(of: ".font(.caption.weight(.semibold))"))

        for source in [buttons, chips, toast] {
            XCTAssertNil(source.range(of: #".brandFont("#))
            XCTAssertNil(source.range(of: #".font(.custom("#))
        }
    }

    func testObsoletePillButtonPrimitivesStayRemoved() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)

        XCTAssertNil(source.range(of: "struct PrimaryPillButton: View"))
        XCTAssertNil(source.range(of: "struct SecondaryPillButton: View"))
        XCTAssertNil(source.range(of: "struct GhostButton: View"))
        XCTAssertNotNil(source.range(of: "struct TextActionButton: View"))
        XCTAssertNotNil(source.range(of: "struct IconCircleButton: View"))
    }

    func testTextActionButtonKeepsCompactNativeTextAndAccessibilityLabel() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)
        let textActionRange = try XCTUnwrap(source.range(of: "struct TextActionButton: View"))
        let focusRange = try XCTUnwrap(source.range(of: "private struct FocusedInputChromeModifier", range: textActionRange.upperBound..<source.endIndex))
        let textActionSource = String(source[textActionRange.lowerBound..<focusRange.lowerBound])

        XCTAssertNotNil(textActionSource.range(of: ".font(.headline.weight(.semibold))"))
        XCTAssertNotNil(textActionSource.range(of: ".lineLimit(2)"))
        XCTAssertNotNil(textActionSource.range(of: ".minimumScaleFactor(0.82)"))
        XCTAssertNotNil(textActionSource.range(of: ".frame(minWidth: minWidth, minHeight: minHeight)"))
        XCTAssertNotNil(textActionSource.range(of: ".accessibilityLabel(Text(title.localized))"))
    }

    func testNativeMaterialSurfaceUsesCurrentSDKFallbacksAndCompilerGatedLiquidGlassHooks() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Design/NativeMaterialSurface.swift"), encoding: .utf8)
        let buttons = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "NativeMaterialSurfaceAccessibility"))
        XCTAssertNotNil(source.range(of: "resolvedTintOpacity("))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: #"@Environment(\.accessibilityReduceTransparency) private var reduceTransparency"#).count - 1, 5)
        XCTAssertNotNil(source.range(of: "reducedTransparencyMinimum: 0.88"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "reducedTransparencyMinimum: 0.94").count - 1, 3)
        XCTAssertNotNil(source.range(of: "reducedTransparencyMinimum: 0.96"))
        XCTAssertNotNil(source.range(of: "NativeMaterialCircleBackground"))
        XCTAssertNotNil(source.range(of: "struct NativeMaterialRoundedBackground: View"))
        XCTAssertNotNil(source.range(of: "private struct NativeSystemSheetPresentationModifier: ViewModifier"))
        XCTAssertNotNil(source.range(of: "private struct NativeSystemFlowSheetPresentationModifier: ViewModifier"))
        XCTAssertNotNil(source.range(of: "private struct NativeMaterialPillModifier: ViewModifier"))
        XCTAssertNotNil(source.range(of: "func nativeMaterialPill("))
        XCTAssertNotNil(source.range(of: "func nativeSystemSheetPresentationChrome()"))
        XCTAssertNotNil(source.range(of: "func nativeSystemFlowSheetPresentationChrome("))
        XCTAssertNotNil(source.range(of: "let detents: Set<PresentationDetent>"))
        XCTAssertNotNil(source.range(of: ".presentationDetents(detents)"))
        XCTAssertNotNil(source.range(of: "enum NativeGlassButtonProminence"))
        XCTAssertNotNil(source.range(of: "private struct NativeGlassButtonStyleModifier: ViewModifier"))
        XCTAssertNotNil(source.range(of: "func nativeGlassButtonStyle(_ prominence: NativeGlassButtonProminence = .standard)"))
        XCTAssertNotNil(source.range(of: "private struct NativeLiquidGlassControlGroupModifier: ViewModifier"))
        XCTAssertNotNil(source.range(of: "func nativeLiquidGlassControlGroup(spacing: CGFloat = Spacing.sm)"))
        XCTAssertNotNil(source.range(of: "LiquidGlassSurfaceGroup(spacing: spacing)"))
        XCTAssertNotNil(source.range(of: "private struct NativeRoundedButtonBackgroundModifier: ViewModifier"))
        XCTAssertNotNil(source.range(of: "private struct NativeIconButtonBackgroundModifier: ViewModifier"))
        XCTAssertNotNil(source.range(of: "func nativeRoundedButtonBackground("))
        XCTAssertNotNil(source.range(of: "func nativeIconButtonBackground("))
        XCTAssertNil(source.range(of: "private struct NativePrimaryButtonBackgroundModifier: ViewModifier"))
        XCTAssertNil(source.range(of: "func nativePrimaryButtonBackground()"))
        XCTAssertNil(source.range(of: "content.background(Color.brand.primary, in: Capsule())"))
        XCTAssertNil(source.range(of: "private struct NativeStandardButtonBackgroundModifier: ViewModifier"))
        XCTAssertNil(source.range(of: "func nativeStandardButtonBackground("))
        XCTAssertNil(source.range(of: "private struct NativeMaterialSheetModifier: ViewModifier"))
        XCTAssertNil(source.range(of: "func nativeMaterialSheet("))
        XCTAssertNil(source.range(of: "reducedTransparencyMinimum: 0.97"))
        XCTAssertNil(source.range(of: "bottomLeadingRadius: 0"))
        XCTAssertNil(source.range(of: "bottomTrailingRadius: 0"))
        XCTAssertNil(source.range(of: "shape.fill(Color.brand.background.opacity(resolvedTintOpacity))"))
        XCTAssertNotNil(source.range(of: "content.buttonStyle(.glass)"))
        XCTAssertNotNil(source.range(of: "content.buttonStyle(.glassProminent)"))
        XCTAssertNotNil(source.range(of: "var tint = Color.brand.surface"))
        XCTAssertNotNil(source.range(of: "shape.fill(tint.opacity(resolvedTintOpacity))"))
        XCTAssertNotNil(source.range(of: "strokeColor ?? Color.brand.border"))
        XCTAssertNotNil(source.range(of: "let shape = Capsule(style: .continuous)"))
        XCTAssertNotNil(source.range(of: "var strokeColor = Color.brand.primaryForeground"))
        XCTAssertNotNil(source.range(of: "var usesAccessibleStroke = false"))
        XCTAssertNotNil(source.range(of: #"@Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor"#))
        XCTAssertNotNil(source.range(of: ".stroke(resolvedStrokeColor.opacity(strokeOpacity), lineWidth: 1)"))
        XCTAssertNotNil(source.range(of: "? Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor)"))
        XCTAssertNotNil(source.range(of: ".fill(.ultraThinMaterial)"))
        XCTAssertNotNil(source.range(of: ".fill(.regularMaterial)"))
        XCTAssertNotNil(source.range(of: "accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor)"))
        XCTAssertNotNil(buttons.range(of: "var materialForeground = Color.brand.primaryForeground"))
        XCTAssertNotNil(buttons.range(of: "var materialStroke = Color.brand.primaryForeground"))
        XCTAssertNotNil(buttons.range(of: "var usesAccessibleMaterialStroke = false"))
        XCTAssertNotNil(buttons.range(of: ".foregroundStyle(material ? materialForeground : Color.brand.foreground)"))
        XCTAssertNotNil(source.range(of: "usesAccessibleStroke: usesAccessibleMaterialStroke"))
        XCTAssertNotNil(buttons.range(of: ".nativeIconButtonBackground("))
        XCTAssertNil(buttons.range(of: ".nativeStandardButtonBackground("))
        XCTAssertNotNil(source.range(of: "#if compiler(>=6.2)"))
        XCTAssertNotNil(source.range(of: "#available(iOS 26.0, *)"))
        XCTAssertNotNil(source.range(of: "GlassEffectContainer(spacing: spacing)"))
        XCTAssertNotNil(source.range(of: "GlassButtonStyle.self"))
        XCTAssertNotNil(source.range(of: "private func nativePresentation(_ content: Content) -> some View"))
        XCTAssertNotNil(source.range(of: "private func fallbackPresentation(_ content: Content) -> some View"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: ".glassEffect(.regular.tint").count - 1, 5)
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: ".interactive()").count - 1, 2)
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: ".presentationDetents([.large])").count - 1, 2)
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: ".presentationDragIndicator(.visible)").count - 1, 2)
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: ".presentationCornerRadius(28)").count - 1, 2)
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: ".presentationBackground(.regularMaterial)").count - 1, 2)
        XCTAssertNotNil(buttons.range(of: ".tint(Color.brand.primary)"))
        XCTAssertNil(buttons.range(of: ".background(Color.brand.primary, in: Capsule())"))
        XCTAssertNil(buttons.range(of: ".nativePrimaryButtonBackground()"))
        XCTAssertEqual(buttons.components(separatedBy: ".nativeGlassButtonStyle(.prominent)").count - 1, 0)
        XCTAssertGreaterThanOrEqual(buttons.components(separatedBy: ".nativeGlassButtonStyle(.standard)").count - 1, 2)
    }

    func testNativeMaterialReducedTransparencyRaisesTintOpacity() {
        XCTAssertEqual(
            NativeMaterialSurfaceAccessibility.resolvedTintOpacity(
                base: 0.62,
                reduceTransparency: false,
                reducedTransparencyMinimum: 0.94
            ),
            0.62
        )
        XCTAssertEqual(
            NativeMaterialSurfaceAccessibility.resolvedTintOpacity(
                base: 0.62,
                reduceTransparency: true,
                reducedTransparencyMinimum: 0.94
            ),
            0.94
        )
        XCTAssertEqual(
            NativeMaterialSurfaceAccessibility.resolvedTintOpacity(
                base: 0.98,
                reduceTransparency: true,
                reducedTransparencyMinimum: 0.94
            ),
            0.98
        )
    }

    func testPrimaryFlowOverlaysUseSharedNativeMaterialSurface() throws {
        let buttons = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)
        let material = try String(contentsOf: projectURL("BuySellAI/Design/NativeMaterialSurface.swift"), encoding: .utf8)
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)
        let camera = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraView.swift"), encoding: .utf8)
        let auth = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)
        let root = try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)
        let picker = try String(contentsOf: projectURL("BuySellAI/Features/MarketplacePicker/MarketplacePickerSheet.swift"), encoding: .utf8)
        let listing = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)
        let snapResult = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(material.range(of: "NativeMaterialCircleBackground("))
        XCTAssertNotNil(buttons.range(of: ".nativeIconButtonBackground("))
        XCTAssertNotNil(material.range(of: "usesAccessibleStroke: usesAccessibleMaterialStroke"))
        XCTAssertNotNil(home.range(of: ".listStyle(.insetGrouped)"))
        XCTAssertNotNil(home.range(of: ".toolbar {"))
        XCTAssertNil(home.range(of: ".nativeLiquidGlassControlGroup"))
        XCTAssertNil(home.range(of: #"Image("SigmaHero")"#))
        XCTAssertNotNil(camera.range(of: ".nativeLiquidGlassControlGroup(spacing: Spacing.md)"))
        XCTAssertNotNil(auth.range(of: ".listStyle(.insetGrouped)"))
        XCTAssertNotNil(auth.range(of: ".toolbar {"))
        XCTAssertNotNil(auth.range(of: ".background(.bar)"))
        XCTAssertNil(auth.range(of: ".nativeLiquidGlassControlGroup"))
        XCTAssertNil(buttons.range(of: ".nativeStandardButtonBackground("))
        XCTAssertNotNil(camera.range(of: ".nativeMaterialPill(tintOpacity: 0.72, strokeOpacity: 0.64)"))
        XCTAssertNotNil(camera.range(of: ".nativeMaterialPanel(cornerRadius: Radius.xl"))
        XCTAssertNotNil(root.range(of: #".sheet(isPresented: flowSheetBinding)"#))
        XCTAssertNotNil(root.range(of: ".nativeSystemFlowSheetPresentationChrome("))
        XCTAssertNotNil(root.range(of: "detents: flowSheetDetents"))
        XCTAssertNil(root.range(of: "@State private var flowSheetDetent"))
        XCTAssertNil(root.range(of: "private struct FlowSheetOverlay"))
        XCTAssertNil(root.range(of: ".nativeMaterialSheet(cornerRadius: 28, tintOpacity: 0.88, strokeOpacity: 0.68)"))
        XCTAssertNil(root.range(of: ".background(Color.brand.background)\n        .clipShape(UnevenRoundedRectangle("))
        XCTAssertNotNil(picker.range(of: "NavigationStack {"))
        XCTAssertNotNil(picker.range(of: "List {"))
        XCTAssertNotNil(picker.range(of: ".listStyle(.insetGrouped)"))
        XCTAssertNotNil(picker.range(of: #".navigationTitle("Best place to sell".localized)"#))
        XCTAssertNil(picker.range(of: "ScrollView {"))
        XCTAssertNil(picker.range(of: "LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders])"))
        XCTAssertNil(picker.range(of: ".nativeMaterialBar(tintOpacity: 0.78, showsTopDivider: false, showsBottomDivider: true)"))
        XCTAssertNotNil(listing.range(of: "NavigationStack {"))
        XCTAssertNotNil(listing.range(of: ".listStyle(.insetGrouped)"))
        XCTAssertNotNil(listing.range(of: ".toolbar {"))
        XCTAssertNotNil(listing.range(of: ".background(.bar)"))
        XCTAssertNotNil(snapResult.range(of: ".background(Color.clear)"))
        XCTAssertNotNil(picker.range(of: ".background(Color.clear)"))
        XCTAssertNotNil(listing.range(of: ".background(Color.clear)"))
        XCTAssertNotNil(listing.range(of: #"Label("Close listing".localized, systemImage: "xmark")"#))
        XCTAssertNotNil(listing.range(of: #".accessibilityLabel("Close listing".localized)"#))
        XCTAssertNil(listing.range(of: "IconCircleButton("))
        XCTAssertNil(listing.range(of: "material: true"))
    }

    func testAuthAndSettingsSheetsUseNativeMaterialPresentationChrome() throws {
        let root = try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)
        let auth = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)

        let authSheetRange = try XCTUnwrap(root.range(of: #".sheet(isPresented: $store.isShowingAuth)"#))
        let settingsSheetRange = try XCTUnwrap(root.range(of: #".sheet(isPresented: $store.isShowingSettings)"#))
        let flowSheetRange = try XCTUnwrap(root.range(of: #".sheet(isPresented: flowSheetBinding)"#, range: settingsSheetRange.upperBound..<root.endIndex))
        let authSheet = String(root[authSheetRange.lowerBound..<settingsSheetRange.lowerBound])
        let settingsSheet = String(root[settingsSheetRange.lowerBound..<flowSheetRange.lowerBound])

        XCTAssertNotNil(authSheet.range(of: "AuthView()"))
        XCTAssertNotNil(authSheet.range(of: ".nativeSystemSheetPresentationChrome()"))
        XCTAssertNil(authSheet.range(of: ".presentationBackground(.regularMaterial)"))
        XCTAssertNotNil(settingsSheet.range(of: "SettingsView()"))
        XCTAssertNotNil(settingsSheet.range(of: ".nativeSystemSheetPresentationChrome()"))
        XCTAssertNil(settingsSheet.range(of: ".presentationBackground(.regularMaterial)"))
        XCTAssertGreaterThanOrEqual(auth.components(separatedBy: ".background(Color.clear)").count - 1, 2)
        XCTAssertGreaterThanOrEqual(settings.components(separatedBy: ".background(Color.clear)").count - 1, 2)
        XCTAssertNil(auth.range(of: ".background(Color.brand.background)"))
        XCTAssertNil(settings.range(of: ".background(Color.brand.background)"))
    }

    func testFeedbackGeneratedContentAndSmallPickerSurfacesUseSharedNativeMaterialChrome() throws {
        let chips = try String(contentsOf: projectURL("BuySellAI/Design/Chips.swift"), encoding: .utf8)
        let toast = try String(contentsOf: projectURL("BuySellAI/Design/Toast.swift"), encoding: .utf8)
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)
        let listing = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)
        let marketplace = try String(contentsOf: projectURL("BuySellAI/Features/MarketplacePicker/MarketplacePickerSheet.swift"), encoding: .utf8)
        let marketplaceRow = try String(contentsOf: projectURL("BuySellAI/Features/MarketplacePicker/MarketplaceRow.swift"), encoding: .utf8)

        XCTAssertNotNil(chips.range(of: ".nativeRoundedButtonBackground("))
        XCTAssertNotNil(chips.range(of: "cornerRadius: Radius.pill"))
        XCTAssertNotNil(chips.range(of: "tint: tint"))
        XCTAssertNotNil(chips.range(of: ".nativeGlassButtonStyle(.standard)"))
        XCTAssertNil(chips.range(of: ".background(tint.opacity(0.12), in: Capsule())"))

        XCTAssertNotNil(toast.range(of: ".nativeMaterialPill(tintOpacity: 0.78, strokeOpacity: 0.84)"))
        XCTAssertNil(toast.range(of: ".background(Color.brand.surfaceElevated, in: Capsule())"))

        XCTAssertNotNil(listing.range(of: #"Section("Generated listing text".localized) {"#))
        XCTAssertNotNil(listing.range(of: "Text(store.listingText)"))
        XCTAssertNotNil(listing.range(of: ".textSelection(.enabled)"))
        XCTAssertNotNil(listing.range(of: ".buttonStyle(.borderedProminent)"))
        XCTAssertNil(listing.range(of: ".nativeMaterialPanel(cornerRadius: Radius.lg, tintOpacity: 0.78, strokeOpacity: 0.62)"))
        XCTAssertNil(listing.range(of: ".background(Color.brand.secondary, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))"))
        XCTAssertNotNil(home.range(of: "EmptyHistoryView()"))
        XCTAssertNotNil(home.range(of: #"Label("No saved listings yet".localized, systemImage: "clock.arrow.circlepath")"#))
        XCTAssertNil(home.range(of: ".nativeMaterialPanel(cornerRadius: Radius.xl, tintOpacity: 0.78, strokeOpacity: 0.58)"))
        XCTAssertNil(home.range(of: ".background(Color.brand.secondary, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))"))

        let summaryRange = try XCTUnwrap(marketplace.range(of: "private struct SummaryButton: View"))
        let summarySource = String(marketplace[summaryRange.lowerBound..<marketplace.endIndex])
        XCTAssertNotNil(summarySource.range(of: ".buttonStyle(PressButtonStyle())"))
        XCTAssertNotNil(summarySource.range(of: #"Image(systemName: "chevron.right")"#))
        XCTAssertNil(summarySource.range(of: ".buttonStyle(.bordered)"))
        XCTAssertNil(summarySource.range(of: ".buttonBorderShape(.capsule)"))
        XCTAssertNil(summarySource.range(of: ".tint(label == \"Best\" ? Color.brand.success : Color.brand.primary)"))
        XCTAssertNil(marketplace.range(of: ".nativeMaterialPanel(cornerRadius: Radius.lg, tintOpacity: 0.72)"))
        XCTAssertNil(marketplace.range(of: ".background((label == \"Best\" ? Color.brand.success : Color.brand.secondary).opacity(0.14), in: Capsule())"))
        XCTAssertNotNil(marketplaceRow.range(of: "tintOpacity: 0.7,\n                    strokeOpacity: 0.54"))
        XCTAssertNil(marketplaceRow.range(of: ".background(Color.brand.secondary, in: Capsule())"))
    }

    func testAccessibleBorderUsesStrongTokenWhenDifferentiatingWithoutColor() {
        XCTAssertEqual(Color.brand.accessibilityBorderToken(differentiateWithoutColor: false), .standard)
        XCTAssertEqual(Color.brand.accessibilityBorderToken(differentiateWithoutColor: true), .strong)
    }

    func testAccessibleBorderAssetValuesMatchPromptTokens() throws {
        let border = try colorAsset("Border", appearance: .light)
        XCTAssertEqual(border.red, 0.922, accuracy: 0.001)
        XCTAssertEqual(border.green, 0.922, accuracy: 0.001)
        XCTAssertEqual(border.blue, 0.922, accuracy: 0.001)

        let borderStrong = try colorAsset("BorderStrong", appearance: .light)
        XCTAssertEqual(borderStrong.red, 0.839, accuracy: 0.001)
        XCTAssertEqual(borderStrong.green, 0.839, accuracy: 0.001)
        XCTAssertEqual(borderStrong.blue, 0.839, accuracy: 0.001)
    }

    func testSemanticColorAssetsMeetPromptContrastTargets() throws {
        let textAssets = ["Foreground", "ForegroundSecondary", "MutedForeground"]
        let backgrounds = ["Background", "Surface"]

        for appearance in ColorAppearance.allCases {
            for backgroundName in backgrounds {
                let background = try colorAsset(backgroundName, appearance: appearance)

                for textName in textAssets {
                    let text = try colorAsset(textName, appearance: appearance)
                    XCTAssertGreaterThanOrEqual(
                        contrastRatio(text, background),
                        4.5,
                        "\(textName) on \(backgroundName) in \(appearance.description) mode should pass body contrast."
                    )
                }

                let accentText = try colorAsset("BrandPrimaryText", appearance: appearance)
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(accentText, background),
                    3.0,
                    "BrandPrimaryText on \(backgroundName) in \(appearance.description) mode should pass large text and icon contrast."
                )
            }
        }
    }

    func testReadableOrangeForegroundUsesPrimaryTextToken() throws {
        let designTokens = try String(contentsOf: projectURL("BuySellAI/Design/DesignTokens.swift"), encoding: .utf8)
        let chips = try String(contentsOf: projectURL("BuySellAI/Design/Chips.swift"), encoding: .utf8)
        let typography = try String(contentsOf: projectURL("BuySellAI/Design/Typography.swift"), encoding: .utf8)
        let appSources = try appSwiftFiles()
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")

        XCTAssertNotNil(designTokens.range(of: #"static let primaryText = Color("BrandPrimaryText")"#))
        XCTAssertNotNil(chips.range(of: "var tint: Color = Color.brand.primaryText"))
        XCTAssertNotNil(typography.range(of: "var periodColor = Color.brand.primaryText"))
        XCTAssertNotNil(appSources.range(of: ".foregroundStyle(Color.brand.primaryText)"))
        XCTAssertNil(appSources.range(of: ".foregroundStyle(Color.brand.primary)"))
    }

    func testAppReduceMotionParticipatesInSharedMotionDecisions() {
        XCTAssertFalse(AppMotion.shouldReduceMotion(os: false, app: false))
        XCTAssertTrue(AppMotion.shouldReduceMotion(os: true, app: false))
        XCTAssertTrue(AppMotion.shouldReduceMotion(os: false, app: true))
        XCTAssertTrue(AppMotion.shouldReduceMotion(os: true, app: true))
    }

    func testWordmarkSizesUseNativeSemanticDynamicTypeAndBoldTextWeights() {
        XCTAssertEqual(WordmarkSize.regular.textStyle, .title3)
        XCTAssertEqual(WordmarkSize.large.textStyle, .title)
        XCTAssertEqual(WordmarkSize.display.textStyle, .largeTitle)

        XCTAssertEqual(WordmarkSize.regular.weight(), .semibold)
        XCTAssertEqual(WordmarkSize.large.weight(), .semibold)
        XCTAssertEqual(WordmarkSize.display.weight(), .bold)
        XCTAssertEqual(WordmarkSize.regular.weight(legibilityWeight: .bold), .bold)
        XCTAssertEqual(WordmarkSize.large.weight(legibilityWeight: .bold), .bold)
    }

    func testSFSymbolSizingUsesSharedBrandSymbolStyles() throws {
        XCTAssertEqual(BrandSymbolStyle.smallChevron.size, 11)
        XCTAssertEqual(BrandSymbolStyle.chevron.size, 13)
        XCTAssertEqual(BrandSymbolStyle.rowIcon.size, 15)
        XCTAssertEqual(BrandSymbolStyle.controlIcon.size, 17)
        XCTAssertEqual(BrandSymbolStyle.heroIcon.size, 44)

        let typography = try String(contentsOf: projectURL("BuySellAI/Design/Typography.swift"), encoding: .utf8)
        let buttons = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)
        let history = try String(contentsOf: projectURL("BuySellAI/Features/History/HistoryRow.swift"), encoding: .utf8)
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)
        let marketplace = try String(contentsOf: projectURL("BuySellAI/Features/MarketplacePicker/MarketplaceRow.swift"), encoding: .utf8)
        let snapResult = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(typography.range(of: "enum BrandSymbolStyle: Sendable"))
        XCTAssertNotNil(typography.range(of: "func brandSymbol(_ style: BrandSymbolStyle)"))
        XCTAssertNotNil(buttons.range(of: ".brandSymbol(.controlIcon)"))
        XCTAssertNotNil(history.range(of: ".brandSymbol(.chevron)"))
        XCTAssertNotNil(settings.range(of: ".brandSymbol(.rowIcon)"))
        XCTAssertNotNil(marketplace.range(of: ".brandSymbol(.chevron)"))
        XCTAssertNotNil(snapResult.range(of: ".brandSymbol(.smallChevron)"))
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)
        XCTAssertNotNil(home.range(of: ".brandSymbol(.heroIcon)"))
        XCTAssertNotNil(home.range(of: ".brandSymbol(.controlIcon)"))
        XCTAssertNotNil(home.range(of: ".brandSymbol(.smallChevron)"))

        for file in try appSwiftFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)
            XCTAssertNil(
                source.range(of: ".font(.system("),
                "\(relativePath(file)) should use brandSymbol for SF Symbol icon sizing."
            )
        }
    }

    func testTypographyUsesNativeSystemTypographyWithoutRegisteredFonts() throws {
        let plistData = try Data(contentsOf: projectURL("BuySellAI/Info.plist"))
        let plist = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        )
        let typography = try String(contentsOf: projectURL("BuySellAI/Design/Typography.swift"), encoding: .utf8)

        XCTAssertNil(plist["UIAppFonts"])
        XCTAssertNotNil(typography.range(of: ".system(textStyle, design: .default, weight: weight(legibilityWeight: legibilityWeight))"))
        XCTAssertNotNil(typography.range(of: ".font(size.font(legibilityWeight: legibilityWeight))"))
        XCTAssertNotNil(typography.range(of: #"@Environment(\.legibilityWeight) private var legibilityWeight"#))
        XCTAssertNil(typography.range(of: "Font.custom("))
        XCTAssertNil(typography.range(of: "BrandTextStyle"))
        XCTAssertNil(typography.range(of: "brandFont("))
        let fontsURL = projectURL("BuySellAI/Resources/Fonts")
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: fontsURL.path, isDirectory: &isDirectory) {
            XCTAssertTrue(isDirectory.boolValue)
            let fontFiles = try FileManager.default.contentsOfDirectory(atPath: fontsURL.path)
            XCTAssertTrue(fontFiles.isEmpty, "Legacy custom fonts should not be shipped in the synchronized app target.")
        }
    }

    func testUserFacingTextUsesSemanticTypographyInsteadOfRawSystemFonts() throws {
        for file in try appSwiftFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)
            let lines = source.components(separatedBy: .newlines)

            for (index, line) in lines.enumerated() where line.contains(".font(.system") {
                let context = nearbySource(lines: lines, index: index, radius: 3)
                XCTAssertNotNil(
                    context.range(of: "Image(systemName:"),
                    "\(relativePath(file)):\(index + 1) should reserve .font(.system...) for SF Symbol icon sizing."
                )
            }

            for (index, line) in lines.enumerated() where line.contains(".font(.caption2)") {
                let context = nearbySource(lines: lines, index: index, radius: 4)
                XCTAssertTrue(
                    context.contains("LaunchArguments") ||
                    context.contains("uiTest") ||
                    context.contains("SettingsStateProbe") ||
                    context.contains("ClipboardVerification"),
                    "\(relativePath(file)):\(index + 1) should use a semantic Dynamic Type role for user-facing caption text."
                )
            }
        }
    }

    func testAuthWordmarkUsesBuySellAIWithoutOrangePeriod() throws {
        let auth = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)
        let typography = try String(contentsOf: projectURL("BuySellAI/Design/Typography.swift"), encoding: .utf8)

        XCTAssertNotNil(typography.range(of: "var showsPeriod = true"))
        XCTAssertNotNil(typography.range(of: "if showsPeriod"))
        XCTAssertNotNil(auth.range(of: #"BrandWordmark(includeAI: true, showsPeriod: false, size: .large)"#))
    }

    func testMarketplaceAccessibilityLabelsDescribePayoutAndDelta() {
        let below = MarketplaceEstimate(id: .ebay, payout: Decimal(41), deltaPct: -8.2, badge: .none)
        XCTAssertEqual(
            MarketplaceAccessibilityText.estimateLabel(for: below),
            "eBay, estimated payout 41 dollars, 8 percent below average"
        )

        let above = MarketplaceEstimate(id: .craigslist, payout: Decimal(45), deltaPct: 12.4, badge: .best)
        XCTAssertEqual(
            MarketplaceAccessibilityText.summaryLabel("Best overall", for: above),
            "Best overall, Craigslist, estimated payout 45 dollars, 12 percent above average"
        )

        let average = MarketplaceEstimate(id: .facebook, payout: Decimal(43), deltaPct: 0.2, badge: .none)
        XCTAssertEqual(
            MarketplaceAccessibilityText.estimateLabel(for: average),
            "Facebook, estimated payout 43 dollars, average payout"
        )

        let strongFit = MarketplaceEstimate(
            id: .reverb,
            payout: Decimal(560),
            deltaPct: 6,
            badge: .best,
            fitScore: 91
        )
        XCTAssertEqual(
            MarketplaceAccessibilityText.summaryLabel("Best overall", for: strongFit),
            "Best overall, Reverb, strong fit, estimated payout 560 dollars, 6 percent above average"
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
            listingText: "TITLE:\nLamp\n\nDESCRIPTION:\nLamp in good condition."
        )

        XCTAssertEqual(HistoryAccessibilityText.thumbnailStatus(for: entry.imageThumbnail), "photo attached")
        XCTAssertEqual(
            HistoryAccessibilityText.rowLabel(for: entry, relativeDate: "2h ago"),
            "Lamp, eBay, 2h ago, photo attached"
        )
        XCTAssertEqual(HistoryAccessibilityText.thumbnailStatus(for: Data([0x00, 0x01])), "no photo")
        XCTAssertEqual(HistoryAccessibilityText.thumbnailStatus(for: nil), "no photo")
    }

    func testHistoryRowsAdaptForAccessibilityDynamicTypeWithoutShrinkingThumbnail() throws {
        let history = try String(contentsOf: projectURL("BuySellAI/Features/History/HistoryRow.swift"), encoding: .utf8)

        XCTAssertEqual(HistoryRowLayout.thumbnailSize, 56)
        XCTAssertEqual(HistoryRowLayout.rowMinHeight, 72)
        XCTAssertEqual(HistoryRowLayout.accessibilityRowMinHeight, 112)
        XCTAssertNotNil(history.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(history.range(of: #"private var rowContent: some View"#))
        XCTAssertNotNil(history.range(of: #"if dynamicTypeSize.isAccessibilitySize"#))
        XCTAssertNotNil(history.range(of: #"private var regularRowContent: some View"#))
        XCTAssertNotNil(history.range(of: #"private var accessibilityRowContent: some View"#))
        XCTAssertNotNil(history.range(of: #"historyCopy(itemLineLimit: 1, metaLineLimit: 1)"#))
        XCTAssertNotNil(history.range(of: #"historyCopy(itemLineLimit: 3, metaLineLimit: 2)"#))
        XCTAssertNotNil(history.range(of: #".padding(.trailing, Spacing.lg)"#))
        XCTAssertNotNil(history.range(of: #".overlay(alignment: .bottomTrailing)"#))
        XCTAssertNotNil(history.range(of: #".frame(width: HistoryRowLayout.thumbnailSize, height: HistoryRowLayout.thumbnailSize)"#))
        XCTAssertNotNil(history.range(of: #"dynamicTypeSize.isAccessibilitySize ? HistoryRowLayout.accessibilityRowMinHeight : HistoryRowLayout.rowMinHeight"#))
        XCTAssertNotNil(history.range(of: #".padding(.vertical, Spacing.xs)"#))
        XCTAssertNil(history.range(of: #".brandFont("#))
        XCTAssertNotNil(history.range(of: #".font(.body.weight(.semibold))"#))
        XCTAssertNotNil(history.range(of: #".font(.caption)"#))
        XCTAssertNil(history.range(of: #".nativeMaterialPanel(cornerRadius: Radius.lg, tintOpacity: 0.74, strokeOpacity: 0.66)"#))
        XCTAssertNil(history.range(of: #".background(Color.brand.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))"#))
        XCTAssertNil(history.range(of: #"@Environment(\.accessibilityDifferentiateWithoutColor)"#))
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
        let buttons = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)
        let chips = try String(contentsOf: projectURL("BuySellAI/Design/Chips.swift"), encoding: .utf8)

        XCTAssertNotNil(buttons.range(of: "func optionalAccessibilityHint(_ hint: String?) -> some View"))
        XCTAssertNotNil(chips.range(of: "optionalAccessibilityHint(accessibilityHint)"))
        XCTAssertNil(buttons.range(of: #"accessibilityHint\?\.\S+\s*\?\?\s*"""#, options: .regularExpression))
        XCTAssertNil(chips.range(of: #"accessibilityHint\?\.\S+\s*\?\?\s*"""#, options: .regularExpression))
    }

    func testTextActionButtonsUseSharedPressStyleAndHaptics() throws {
        let buttons = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)
        let auth = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)

        XCTAssertNotNil(buttons.range(of: "struct TextActionButton: View"))
        XCTAssertNotNil(buttons.range(of: "var minHeight: CGFloat = 44"))
        XCTAssertNotNil(buttons.range(of: "Haptics.impact(hapticStyle)"))
        XCTAssertNotNil(buttons.range(of: ".buttonStyle(PressButtonStyle())"))
        XCTAssertNotNil(buttons.range(of: ".accessibilityLabel(Text(title.localized))"))
        XCTAssertNotNil(auth.range(of: #"private var guestBottomAction: some View"#))
        XCTAssertNotNil(auth.range(of: #"Text("Keep going without an account".localized)"#))
        XCTAssertNotNil(auth.range(of: #".buttonStyle(.bordered)"#))
        XCTAssertNotNil(auth.range(of: #".background(.bar)"#))
        XCTAssertNil(auth.range(of: #".buttonBorderShape(.capsule)"#))
        XCTAssertNil(auth.range(of: #"TextActionButton(title: "Keep going without an account""#))
        XCTAssertNil(auth.range(of: #".nativeMaterialBar(tintOpacity: 0.78)"#))
    }

    func testFocusedInputChromeUsesStrongFocusBorderAndSharedMotionWhereCustomInputsRemain() throws {
        let buttons = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)
        let auth = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)
        let snapResult = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)
        let modifierRange = try XCTUnwrap(buttons.range(of: "private struct FocusedInputChromeModifier: ViewModifier"))
        let extensionRange = try XCTUnwrap(buttons.range(of: "func focusedInputChrome(", range: modifierRange.upperBound..<buttons.endIndex))
        let modifierSource = String(buttons[modifierRange.lowerBound..<extensionRange.lowerBound])

        XCTAssertNotNil(buttons.range(of: "private struct FocusedInputChromeModifier: ViewModifier"))
        XCTAssertNotNil(buttons.range(of: "func focusedInputChrome("))
        XCTAssertNotNil(modifierSource.range(of: "NativeMaterialRoundedBackground("))
        XCTAssertNotNil(modifierSource.range(of: "tintOpacity: 0.78"))
        XCTAssertNil(modifierSource.range(of: ".background(Color.brand.secondary"))
        XCTAssertNotNil(buttons.range(of: "Color.brand.borderStrong"))
        XCTAssertNotNil(buttons.range(of: "Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor)"))
        XCTAssertNotNil(buttons.range(of: "ButtonStateOpacity.disabled"))
        XCTAssertNotNil(buttons.range(of: "AppMotion.animation(reduceMotion: shouldReduceMotion)"))
        XCTAssertNil(auth.range(of: ".focusedInputChrome("))
        XCTAssertNotNil(settings.range(of: "@FocusState private var isConfirmationFocused: Bool"))
        XCTAssertNotNil(settings.range(of: ".focusedInputChrome(isFocused: isConfirmationFocused)"))
        XCTAssertGreaterThanOrEqual(snapResult.components(separatedBy: ".focusedInputChrome(").count - 1, 2)
    }

    func testSnapResultChipsExposePurposeAndActionHints() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"ChipAccessibilityText.valueLabel("Category""#))
        XCTAssertNotNil(source.range(of: #"accessibilityHint: "Changes the category""#))
        XCTAssertNotNil(source.range(of: #"ChipAccessibilityText.valueLabel("Condition""#))
        XCTAssertNotNil(source.range(of: #"accessibilityHint: "Changes the condition""#))
    }

    func testSnapResultPricePrefixStaysVisuallyAttachedToEditablePrice() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)
        let pricePrefixRange = try XCTUnwrap(source.range(of: #"Text("~$")"#))
        let priceFieldRange = try XCTUnwrap(source.range(of: #"TextField("Price".localized"#))
        let priceControlStart = try XCTUnwrap(source[..<pricePrefixRange.lowerBound].range(of: "HStack(spacing: 0)", options: .backwards))
        let priceControlSource = String(source[priceControlStart.lowerBound..<priceFieldRange.upperBound])

        XCTAssertNotNil(priceControlSource.range(of: "HStack(spacing: 0)"))
        XCTAssertNil(priceControlSource.range(of: "Spacing.xs"))
        XCTAssertNotNil(source.range(of: ".textFieldStyle(.plain)"))
    }

    func testSnapResultHeaderStacksPhotoAndControlsAtAccessibilityDynamicType() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(source.range(of: #"private func confirmationHero(item: DetectedItem) -> some View"#))
        XCTAssertNotNil(source.range(of: #"if dynamicTypeSize.isAccessibilitySize"#))
        XCTAssertNotNil(source.range(of: #"VStack(alignment: .leading, spacing: Spacing.md)"#))
        XCTAssertNotNil(source.range(of: #"HStack(alignment: .center, spacing: Spacing.md)"#))
        XCTAssertNotNil(source.range(of: #"private func confirmationSummary(item: DetectedItem) -> some View"#))
        XCTAssertNotNil(source.range(of: #"private var priceEditor: some View"#))
        XCTAssertNotNil(source.range(of: #".layoutPriority(1)"#))
        XCTAssertNotNil(source.range(of: #"confirmationCard(item: item)"#))
        XCTAssertNotNil(source.range(of: #".accessibilitySortPriority(5)"#))
    }

    func testSnapResultInlineNameEditUsesSharedPressFeedback() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)
        let controlRange = try XCTUnwrap(source.range(of: "private var itemNameControl: some View"))
        let readableNameRange = try XCTUnwrap(source.range(of: "private var readableItemName", range: controlRange.upperBound..<source.endIndex))
        let controlSource = String(source[controlRange.lowerBound..<readableNameRange.lowerBound])

        XCTAssertNotNil(controlSource.range(of: "Haptics.impact(.light)"))
        XCTAssertNotNil(controlSource.range(of: ".buttonStyle(PressButtonStyle())"))
        XCTAssertNotNil(controlSource.range(of: #".accessibilityHint("Double-tap to edit the item name".localized)"#))
        XCTAssertNil(controlSource.range(of: ".buttonStyle(.plain)"))
    }

    func testSnapResultStillWorkingHintAnnouncesAlertAndRetryAction() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"import UIKit"#))
        XCTAssertNotNil(source.range(of: #".onChange(of: store.showStillWorking)"#))
        XCTAssertNotNil(source.range(of: #".accessibilityIdentifier("SnapResult.StillWorkingAlert")"#))
        XCTAssertNotNil(source.range(of: #"UIAccessibility.post("#))
        XCTAssertNotNil(source.range(of: #"notification: .announcement"#))
        XCTAssertNotNil(source.range(of: #"Label("Retry".localized, systemImage: "arrow.clockwise")"#))
        XCTAssertNotNil(source.range(of: #".buttonStyle(.bordered)"#))
        XCTAssertNil(source.range(of: #".buttonBorderShape(.capsule)"#))
        XCTAssertNil(source.range(of: #"SecondaryPillButton(title: "Retry""#))
    }

    func testSnapResultErrorStateOffersRetakeBeforeRetry() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)
        let errorRange = try XCTUnwrap(source.range(of: "private func errorView(message: String) -> some View"))
        let fieldRange = try XCTUnwrap(source.range(of: "private enum Field"))
        let errorSource = String(source[errorRange.lowerBound..<fieldRange.lowerBound])

        let retakeRange = try XCTUnwrap(errorSource.range(of: #"Label("Retake photo".localized, systemImage: "camera.rotate")"#))
        let retryRange = try XCTUnwrap(errorSource.range(of: #"Label("Try again".localized, systemImage: "arrow.clockwise")"#))

        XCTAssertLessThan(retakeRange.lowerBound, retryRange.lowerBound)
        XCTAssertNotNil(errorSource.range(of: #".buttonStyle(.borderedProminent)"#))
        XCTAssertNotNil(errorSource.range(of: #".buttonStyle(.bordered)"#))
        XCTAssertNil(errorSource.range(of: #".buttonBorderShape(.capsule)"#))
        XCTAssertNil(errorSource.range(of: #"PrimaryPillButton"#))
        XCTAssertNil(errorSource.range(of: #"SecondaryPillButton"#))
        XCTAssertNotNil(errorSource.range(of: #".task(id: message)"#))
        XCTAssertNotNil(errorSource.range(of: #"appStore.showToast(message, style: .error)"#))
    }

    func testSnapResultUsesNativeListAndStickyDecisionAction() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"NavigationStack {"#))
        XCTAssertNotNil(source.range(of: #"List {"#))
        XCTAssertNotNil(source.range(of: #".listStyle(.insetGrouped)"#))
        XCTAssertNotNil(source.range(of: #".listSectionSpacing(.compact)"#))
        XCTAssertNotNil(source.range(of: #".scrollContentBackground(.hidden)"#))
        XCTAssertNotNil(source.range(of: #".contentMargins(.bottom, listBottomContentInset, for: .scrollContent)"#))
        XCTAssertNotNil(source.range(of: #".navigationTitle("Confirm item".localized)"#))
        XCTAssertNotNil(source.range(of: #".navigationBarTitleDisplayMode(.inline)"#))
        XCTAssertNotNil(source.range(of: #".safeAreaInset(edge: .bottom)"#))
        XCTAssertNil(source.range(of: #".brandFont("#))
        XCTAssertNotNil(source.range(of: #".font(.title3.weight(.semibold))"#))
        XCTAssertNotNil(source.range(of: #".font(.title2.weight(.semibold))"#))
        XCTAssertNotNil(source.range(of: #"private var pearlSheetBackground: some View"#))
        XCTAssertNotNil(source.range(of: #"private func confirmationCard(item: DetectedItem) -> some View"#))
        XCTAssertNotNil(source.range(of: #"Text("We think this is".localized)"#))
        XCTAssertNotNil(source.range(of: #"private struct SnapResultFactPill: View"#))
        XCTAssertNotNil(source.range(of: #"private var notSureButton: some View"#))
        XCTAssertNotNil(source.range(of: #"private var changeDetailsButton: some View"#))
        XCTAssertNotNil(source.range(of: #"private func uncertaintyHelp(details: AnalyzeIntelligence?) -> some View"#))
        XCTAssertNotNil(source.range(of: #"private func likelyMatchButton(_ match: AnalyzeLikelyMatch) -> some View"#))
        XCTAssertNotNil(source.range(of: #"store.selectLikelyMatch(match)"#))
        XCTAssertNotNil(source.range(of: #"match.closenessLabel"#))
        XCTAssertNotNil(source.range(of: #"private func decisionBar(item: DetectedItem) -> some View"#))
        XCTAssertNotNil(source.range(of: #"Label("Yes, that's it".localized, systemImage: "checkmark.circle.fill")"#))
        XCTAssertNotNil(source.range(of: #"Label("Not sure".localized, systemImage: "questionmark.circle")"#))
        XCTAssertNotNil(source.range(of: #"Label("Change details".localized, systemImage: "slider.horizontal.3")"#))
        XCTAssertNotNil(source.range(of: #"Text("Next: a few easy questions.".localized)"#))
        XCTAssertNotNil(source.range(of: #"Section("What we found".localized) {"#))
        XCTAssertNotNil(source.range(of: #"private func analysisDetailRows(_ details: AnalyzeIntelligence) -> some View"#))
        XCTAssertNotNil(source.range(of: #"ForEach(Array(details.itemFacts.prefix(3).enumerated()), id: \.offset)"#))
        XCTAssertNotNil(source.range(of: #"private func analysisFactRow(_ fact: AnalyzeItemFact) -> some View"#))
        XCTAssertNotNil(source.range(of: #"private func analysisGuidanceRow(_ guidance: String) -> some View"#))
        XCTAssertNotNil(source.range(of: #"Image(systemName: "text.magnifyingglass")"#))
        XCTAssertNotNil(source.range(of: #"Text("Could help".localized)"#))
        XCTAssertNotNil(source.range(of: #"Image(systemName: "lightbulb")"#))
        XCTAssertNotNil(source.range(of: #".accessibilityLabel(String.localizedFormat("%@, %@", fact.label, fact.value))"#))
        XCTAssertNotNil(source.range(of: #".accessibilityLabel(String.localizedFormat("%@, %@", "Could help".localized, guidance))"#))
        XCTAssertNotNil(source.range(of: #".buttonStyle(.borderedProminent)"#))
        XCTAssertNotNil(source.range(of: #".nativeMaterialBar(tintOpacity: 0.9, showsTopDivider: true)"#))
        XCTAssertNil(source.range(of: #".buttonBorderShape(.capsule)"#))
        XCTAssertNil(source.range(of: #"PrimaryPillButton(title: "Looks right — add details""#))

        let confirmationRange = try XCTUnwrap(source.range(of: #"confirmationCard(item: item)"#))
        let detailSectionRange = try XCTUnwrap(source.range(of: #"Section("What we found".localized) {"#, range: confirmationRange.upperBound..<source.endIndex))
        XCTAssertLessThan(confirmationRange.lowerBound, detailSectionRange.lowerBound)
    }

    func testSnapResultStoresStructuredAnalyzeDetailsForReviewRows() throws {
        let store = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultStore.swift"), encoding: .utf8)
        let sheet = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(store.range(of: #"var analysisDetails: AnalyzeIntelligence?"#))
        XCTAssertNotNil(store.range(of: #"analysisDetails = nil"#))
        XCTAssertNotNil(store.range(of: #"analysisDetails = response.analysis"#))
        XCTAssertNotNil(store.range(of: #"func selectLikelyMatch(_ match: AnalyzeLikelyMatch)"#))
        XCTAssertNotNil(store.range(of: #"analysisDetails = details.acceptingLikelyMatch(cleanMatch)"#))
        XCTAssertNotNil(sheet.range(of: #"if let details = store.analysisDetails"#))
        XCTAssertNotNil(sheet.range(of: #"Section("What we found".localized) {"#))
        XCTAssertNotNil(sheet.range(of: #"analysisDetailRows(details)"#))
    }

    func testSnapResultVisibleCancellationRetriesOnceAndKeepsManualRetry() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"@State private var automaticCancellationRetryCount = 0"#))
        XCTAssertNotNil(source.range(of: #"@State private var isSheetVisible = true"#))
        XCTAssertNotNil(source.range(of: #".onChange(of: store.phase) { oldPhase, newPhase in"#))
        XCTAssertNotNil(source.range(of: #"retryVisibleAnalysisIfCancelled(from: oldPhase, to: newPhase)"#))
        XCTAssertNotNil(source.range(of: #"guard isSheetVisible,"#))
        XCTAssertNotNil(source.range(of: #"automaticCancellationRetryCount == 0,"#))
        XCTAssertNotNil(source.range(of: #"oldPhase == .loading,"#))
        XCTAssertNotNil(source.range(of: #"newPhase == .idle else { return }"#))
        XCTAssertNotNil(source.range(of: #"automaticCancellationRetryCount += 1"#))
        XCTAssertNotNil(source.range(of: #"await store.analyzeIfNeeded(accessToken: await appStore.authenticatedAccessToken())"#))
        XCTAssertNotNil(source.range(of: #"store.phase == .idle && automaticCancellationRetryCount > 0"#))
    }

    func testItemQuestionsSheetUsesDynamicOneQuestionFlow() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/ItemQuestions/ItemQuestionsSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"@State private var questions: [DetailQuestion]"#))
        XCTAssertNotNil(source.range(of: #"@State private var currentQuestionIndex = 0"#))
        XCTAssertNotNil(source.range(of: #"Self.makeQuestions(context: context, answers: initialAnswers)"#))
        XCTAssertNotNil(source.range(of: #"if let currentQuestion {"#))
        XCTAssertNotNil(source.range(of: #"questionCard(currentQuestion)"#))
        XCTAssertNotNil(source.range(of: #"Text("One quick thing".localized)"#))
        XCTAssertNotNil(source.range(of: #"Text("Ready to write".localized)"#))
        XCTAssertNotNil(source.range(of: #"Text("BuySell has enough details for this marketplace.".localized)"#))
        XCTAssertNotNil(source.range(of: #".navigationTitle("Tiny details".localized)"#))
        XCTAssertNotNil(source.range(of: #"ProgressView(value: questionProgress)"#))
        XCTAssertNotNil(source.range(of: #".accessibilityLabel("Question progress".localized)"#))
        XCTAssertNotNil(source.range(of: #"Text("I don't know".localized)"#))
        XCTAssertNotNil(source.range(of: #"previousQuestionButton"#))
        XCTAssertNotNil(source.range(of: #"Section {"#))
        XCTAssertNotNil(source.range(of: #"Text("Saved so far".localized)"#))
        XCTAssertNotNil(source.range(of: #"question.isAnswered(in: answers)"#))
        XCTAssertNotNil(source.range(of: #"usedKinds.contains(question.kind)"#))
        XCTAssertNotNil(source.range(of: #"let knownFacts = context.analysis?.itemFacts ?? []"#))
        XCTAssertNotNil(source.range(of: #"add(analysisQuestion(for: context))"#))
        XCTAssertNotNil(source.range(of: #"context.analysis?.highestImpactMissingFact"#))
        XCTAssertNotNil(source.range(of: #"answers.markAnswered(field.detailKey)"#))
        XCTAssertNotNil(source.range(of: #"answers.clearAnswered(field.detailKey)"#))
        XCTAssertNotNil(source.range(of: #"answers.markAnswered(.largeOrFragile)"#))
        XCTAssertNotNil(source.range(of: #"answers.hasAnsweredOrSkipped(field.detailKey)"#))
        XCTAssertNotNil(source.range(of: #"knownFacts.containsFact(namedLike:"#))
        XCTAssertNotNil(source.range(of: #"private extension Array where Element == AnalyzeItemFact"#))
        XCTAssertNotNil(source.range(of: #"guard fact.confidence >= 0.7 else { return false }"#))
        XCTAssertNotNil(source.range(of: #"String.localizedFormat("#))
        XCTAssertNotNil(source.range(of: #"The photo did not clearly show %@. Add it only if you can see it."#))
        XCTAssertNotNil(source.range(of: #"contextLabel: "Photo check""#))
        XCTAssertNotNil(source.range(of: #"marketplaceQuestion(for: marketplace, item: context.item)"#))
        XCTAssertNotNil(source.range(of: #"case .ebay:"#))
        XCTAssertNotNil(source.range(of: #"case .facebook, .craigslist, .offerup, .nextdoor:"#))
        XCTAssertNotNil(source.range(of: #"case .poshmark, .depop, .vinted, .vestiaire, .therealreal, .grailed, .curtsy:"#))
        XCTAssertNotNil(source.range(of: #"case .stockx, .goat:"#))
        XCTAssertNotNil(source.range(of: #"return Array(questions.prefix(3))"#))
        XCTAssertNotNil(source.range(of: #"return limitedQuestions.isEmpty ? [flawQuestion] : limitedQuestions"#))
        XCTAssertNil(source.range(of: #"questionField("#))
        XCTAssertNil(source.range(of: #"Toggle(isOn: $answers.isLargeOrFragile)"#))
        XCTAssertNil(source.range(of: #"Text("Check if you know it".localized)"#))
        XCTAssertNil(source.range(of: #"Text("Add what you know".localized)"#))
    }

    func testMarketplacePickerRunsPlatformQuestionBeforeListingGeneration() throws {
        let marketplace = try String(contentsOf: projectURL("BuySellAI/Features/MarketplacePicker/MarketplacePickerSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(marketplace.range(of: #"private func chooseMarketplace(_ marketplace: Marketplace)"#))
        XCTAssertNotNil(marketplace.range(of: #"chooseMarketplace(estimate.id)"#))
        XCTAssertNotNil(marketplace.range(of: #"chooseMarketplace(pick.estimate.id)"#))
        XCTAssertNotNil(marketplace.range(of: #"chooseMarketplace(marketplace)"#))
        XCTAssertNotNil(marketplace.range(of: #"appStore.presentItemQuestions("#))
        XCTAssertNotNil(marketplace.range(of: #"preferredMarketplace: marketplace"#))
        XCTAssertNotNil(marketplace.range(of: #"analysis: context.analysis"#))
        XCTAssertNotNil(marketplace.range(of: #"answers: context.details"#))
        XCTAssertNil(marketplace.range(of: #"appStore.presentListing(item: context.item"#))
    }

    func testHomePrimaryActionUsesAppleSimpleOneTwoThreeFrontDoor() throws {
        let root = try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)

        XCTAssertNotNil(root.range(of: #".dynamicTypeLimit()"#))
        XCTAssertNotNil(home.range(of: ".listStyle(.insetGrouped)"))
        XCTAssertNotNil(home.range(of: "HomeCameraHeroMark(startSnapFlow: startSnapFlow)"))
        XCTAssertNotNil(home.range(of: "private struct HomeCameraHeroMark: View"))
        XCTAssertNotNil(home.range(of: "let startSnapFlow: () -> Void"))
        XCTAssertNotNil(home.range(of: ".brandSymbol(.heroIcon)"))
        XCTAssertNotNil(home.range(of: "Color.brand.primaryMuted"))
        XCTAssertNotNil(home.range(of: "HomePearlScreenBackground()"))
        XCTAssertNotNil(home.range(of: "HomePearlTopHighlight(cornerRadius: Radius.xl)"))
        XCTAssertNotNil(home.range(of: "private struct HomeHeroCameraGlyph: View"))
        XCTAssertNotNil(home.range(of: #"Image(systemName: "camera.aperture")"#))
        XCTAssertNotNil(home.range(of: "Color.brand.border.opacity(0.76)"))
        XCTAssertNotNil(home.range(of: "Color.brand.shadow.opacity(0.07)"))
        XCTAssertNotNil(home.range(of: "private struct HomeStepRow: View"))
        XCTAssertNotNil(home.range(of: #"HomeStepRow(number: 1, title: "Snap a photo""#))
        XCTAssertNotNil(home.range(of: #"HomeStepRow(number: 2, title: "Answer what you know""#))
        XCTAssertNotNil(home.range(of: #"HomeStepRow(number: 3, title: "Copy the listing""#))
        XCTAssertNotNil(home.range(of: "private struct HomeHowItWorksRow: View"))
        XCTAssertNil(home.range(of: "HomeHeroSection("))
        XCTAssertNil(home.range(of: "private struct HomeHeroSection: View"))
        XCTAssertNil(home.range(of: "private struct HomeHeroVisual: View"))
        XCTAssertNil(home.range(of: "private struct HomePromiseStrip: View"))
        XCTAssertNotNil(home.range(of: #"Section("1 · 2 · 3".localized) {"#))
        XCTAssertNotNil(home.range(of: #"Text("Snap to sell".localized)"#))
        XCTAssertNotNil(home.range(of: #"Text("Photo. Questions. Listing.".localized)"#))
        XCTAssertNotNil(home.range(of: #"Text("1 2 3".localized)"#))
        XCTAssertNotNil(home.range(of: #".buttonStyle(PressButtonStyle())"#))
        XCTAssertNil(home.range(of: #".buttonStyle(.borderedProminent)"#))
        XCTAssertNotNil(home.range(of: #".accessibilityHint("Opens the camera".localized)"#))
        XCTAssertNotNil(home.range(of: #".accessibilityLabel("Snap to sell".localized)"#))
        XCTAssertNotNil(home.range(of: #"Text("How it works".localized)"#))
        XCTAssertNotNil(home.range(of: #"Text("Take photo, pick place, copy listing.".localized)"#))
        XCTAssertNil(home.range(of: "HomePromiseItem("))
        XCTAssertNil(home.range(of: "private struct HomePromiseItem"))
        XCTAssertNotNil(home.range(of: #"Section("Saved listings".localized) {"#))
        XCTAssertNotNil(home.range(of: "private var shouldShowHistorySection: Bool"))
        XCTAssertNotNil(home.range(of: "isInitialHistoryLoading || historySyncFailureMessage != nil || appStore.history.isEmpty == false"))
        XCTAssertNotNil(home.range(of: #"Label("No saved listings yet".localized, systemImage: "clock.arrow.circlepath")"#))
        XCTAssertNotNil(home.range(of: #".frame(maxWidth: .infinity, minHeight: 116)"#))
        XCTAssertNil(home.range(of: #"Section("Recent listings".localized) {"#))
        XCTAssertNil(home.range(of: #"Copy a listing and it will appear here."#))
        XCTAssertNil(home.range(of: #".brandFont("#))
        XCTAssertNotNil(home.range(of: #".font(.body.weight(.semibold))"#))
        XCTAssertNotNil(home.range(of: #".font(.subheadline)"#))
        XCTAssertNil(home.range(of: #".font(.largeTitle.weight(.bold))"#))
        XCTAssertNil(home.range(of: "SnapActionRow()"))
        XCTAssertNil(home.range(of: "private struct SnapActionRow: View"))
        XCTAssertNil(home.range(of: ".brandFont(.display)"))
        XCTAssertNil(home.range(of: #"Image("SigmaHero")"#))
    }

    func testHomeAccountActionUsesNativeToolbarPlacement() throws {
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)
        let accountRange = try XCTUnwrap(home.range(of: "private var accountButton: some View"))
        let settingsRange = try XCTUnwrap(home.range(of: "private var settingsButton: some View", range: accountRange.upperBound..<home.endIndex))
        let accountSource = String(home[accountRange.lowerBound..<settingsRange.lowerBound])

        XCTAssertNotNil(home.range(of: #"ToolbarItem(placement: .topBarTrailing) {"#))
        XCTAssertNotNil(accountSource.range(of: #"Text(accountButtonTitle.localized)"#))
        XCTAssertNotNil(accountSource.range(of: #".accessibilityLabel(accountButtonTitle.localized)"#))
        XCTAssertNotNil(accountSource.range(of: #"appStore.session == nil ? "Sign in" : "Sign out""#))
        XCTAssertNil(accountSource.range(of: ".nativeStandardButtonBackground"))
        XCTAssertNil(accountSource.range(of: ".nativeGlassButtonStyle"))
    }

    func testHomeAccountAndHistoryActionsUseSharedPressFeedbackAndHaptics() throws {
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)

        XCTAssertNotNil(home.range(of: "handleAccountButtonTap()"))
        XCTAssertNotNil(home.range(of: "private func handleAccountButtonTap()"))
        XCTAssertNotNil(home.range(of: "private func reopenHistoryEntry(_ entry: HistoryEntry)"))
        XCTAssertGreaterThanOrEqual(home.components(separatedBy: "Haptics.impact(.light)").count - 1, 2)
        XCTAssertNotNil(home.range(of: "reopenHistoryEntry(entry)"))
        XCTAssertNotNil(home.range(of: ".buttonStyle(PressButtonStyle())"))
        XCTAssertNotNil(home.range(of: "appStore.reopenListing(entry)"))
        XCTAssertNil(home.range(of: "appStore.reopenListing(entry)\n                            } label:"))
    }

    func testHomeHistoryLoadingAndSyncFailureStatesAreDesignedRows() throws {
        let appStore = try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)

        XCTAssertNotNil(appStore.range(of: "enum HistorySyncState: Equatable, Sendable"))
        XCTAssertNotNil(appStore.range(of: "var historySyncState: HistorySyncState = .idle"))
        XCTAssertNotNil(appStore.range(of: "historySyncState = .loading"))
        XCTAssertNotNil(appStore.range(of: "historySyncState = .failed(message)"))
        XCTAssertNotNil(home.range(of: "private var historySectionContent: some View"))
        XCTAssertNotNil(home.range(of: "private var isInitialHistoryLoading: Bool"))
        XCTAssertNotNil(home.range(of: "private var historySyncFailureMessage: String?"))
        XCTAssertNotNil(home.range(of: "HistoryLoadingView()"))
        XCTAssertNotNil(home.range(of: "HistorySyncFailureRow(message: historySyncFailureMessage)"))
        XCTAssertNotNil(home.range(of: "private struct HistoryLoadingView: View"))
        XCTAssertNotNil(home.range(of: "SkeletonLine(height: 56, width: 56)"))
        XCTAssertNotNil(home.range(of: #".accessibilityLabel("Loading recent listings".localized)"#))
        XCTAssertNotNil(home.range(of: #".accessibilityAddTraits(.updatesFrequently)"#))
        XCTAssertNotNil(home.range(of: #"private struct HistorySyncFailureRow: View"#))
        XCTAssertNotNil(home.range(of: #"Image(systemName: "arrow.clockwise.circle")"#))
        XCTAssertNotNil(home.range(of: #"Text("Couldn't update listings".localized)"#))
        XCTAssertNotNil(home.range(of: #"Text("Try again".localized)"#))
        XCTAssertNotNil(home.range(of: #".accessibilityHint("Checks for your latest saved listings".localized)"#))
        XCTAssertNotNil(home.range(of: "Task {\n            await appStore.loadHistory()\n        }"))
    }

    func testHomeSettingsActionUsesNativeToolbarGear() throws {
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)
        let settingsRange = try XCTUnwrap(home.range(of: "private var settingsButton: some View"))
        let accountRange = try XCTUnwrap(home.range(of: "private func handleAccountButtonTap", range: settingsRange.upperBound..<home.endIndex))
        let gearSource = String(home[settingsRange.lowerBound..<accountRange.lowerBound])

        XCTAssertNotNil(home.range(of: #"ToolbarItem(placement: .topBarTrailing) {"#))
        XCTAssertNotNil(gearSource.range(of: #"Image(systemName: "gearshape")"#))
        XCTAssertNotNil(gearSource.range(of: #"appStore.presentSettings()"#))
        XCTAssertNotNil(gearSource.range(of: #".accessibilityLabel("Settings".localized)"#))
        XCTAssertNil(gearSource.range(of: "IconCircleButton("))
        XCTAssertNil(gearSource.range(of: "material: true"))
    }

    func testIconCircleButtonCallSitesUseNativeMaterialChrome() throws {
        let appSources = try appSwiftFiles()
            .filter { $0.lastPathComponent != "Buttons.swift" }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
        let callPattern = #"IconCircleButton\([\s\S]*?\)\s*\{"#
        var calls: [String] = []
        var searchRange = appSources.startIndex..<appSources.endIndex
        while let range = appSources.range(of: callPattern, options: .regularExpression, range: searchRange) {
            calls.append(String(appSources[range]))
            searchRange = range.upperBound..<appSources.endIndex
        }

        XCTAssertGreaterThanOrEqual(calls.count, 3)
        for source in calls {
            XCTAssertNotNil(source.range(of: #"material: true"#), "Icon circle buttons should use shared native material chrome: \(source)")
        }
    }

    func testHomeScrollContentClearsSystemHomeIndicator() throws {
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)

        XCTAssertNotNil(home.range(of: #".contentMargins(.bottom, Spacing.xxxl, for: .scrollContent)"#))
        XCTAssertNil(home.range(of: #".safeAreaInset(edge: .bottom)"#))
        XCTAssertNotNil(home.range(of: #".frame(maxWidth: .infinity, minHeight: 116)"#))
    }

    func testHomeUsesNativeInsetGroupedTaskRowsInsteadOfCustomWidthClamps() throws {
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)

        XCTAssertNotNil(home.range(of: ".listStyle(.insetGrouped)"))
        XCTAssertNotNil(home.range(of: "HomeCameraHeroMark(startSnapFlow: startSnapFlow)"))
        XCTAssertNotNil(home.range(of: "HomeStepRow(number: 1"))
        XCTAssertNotNil(home.range(of: "HomeStepRow(number: 2"))
        XCTAssertNotNil(home.range(of: "HomeStepRow(number: 3"))
        XCTAssertNotNil(home.range(of: "HomeHowItWorksRow"))
        XCTAssertNil(home.range(of: "HomeHeroSection("))
        XCTAssertNotNil(home.range(of: #".navigationTitle("BuySell.".localized)"#))
        XCTAssertNotNil(home.range(of: ".navigationBarTitleDisplayMode(.inline)"))
        XCTAssertNotNil(home.range(of: "ToolbarItem(placement: .principal)"))
        XCTAssertNotNil(home.range(of: "BrandWordmark(size: .regular, periodColor: Color.brand.foregroundSecondary)"))
        XCTAssertNil(home.range(of: "horizontalSizeClass"))
        XCTAssertNil(home.range(of: "UIDevice.current.userInterfaceIdiom"))
        XCTAssertNil(home.range(of: "heroContentMaxWidth"))
        XCTAssertNil(home.range(of: "sectionContentMaxWidth"))
    }

    func testHomeRemovesLegacyHeroArtworkForFirstPartyTaskHub() throws {
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)
        let heroContents = projectURL("BuySellAI/Resources/Assets.xcassets/SigmaHero.imageset/Contents.json")
        let heroSVG = projectURL("BuySellAI/Resources/Assets.xcassets/SigmaHero.imageset/SigmaHero.svg")

        XCTAssertNil(home.range(of: #"Image("SigmaHero")"#))
        XCTAssertNil(home.range(of: "SigmaHero"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: heroContents.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: heroSVG.path))
        XCTAssertNotNil(home.range(of: #"Text("Snap to sell".localized)"#))
        XCTAssertNil(home.range(of: "HomeHeroVisual"))
    }

    func testAppIconUsesCameraFirstBrandArtworkWithoutTextTile() throws {
        let iconURL = projectURL("BuySellAI/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
        let data = try Data(contentsOf: iconURL)
        let pngSignature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]

        XCTAssertEqual(Array(data.prefix(pngSignature.count)), pngSignature)
        XCTAssertEqual(try pngUInt32(data, offset: 16), 1024)
        XCTAssertEqual(try pngUInt32(data, offset: 20), 1024)
        XCTAssertEqual(data[24], 8)
        XCTAssertEqual(data[25], 2, "PNG color type 2 is truecolor without alpha, which keeps the App Store source icon alpha-free.")

        let imageSource = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
        XCTAssertEqual(image.width, 1024)
        XCTAssertEqual(image.height, 1024)

        let renderedPixels = try renderedPixels(from: image)
        let orangeBackgroundSamples = [
            (16, 16),
            (90, 90),
            (934, 90),
            (90, 934),
            (934, 934),
            (1000, 1000)
        ]

        for point in orangeBackgroundSamples {
            let sampledPixel = try pixel(in: renderedPixels, image: image, x: point.0, y: point.1)
            XCTAssertTrue(isWarmBrandOrange(sampledPixel), "App icon background sample at \(point) should stay warm orange, not a white text tile or black artifact.")
        }

        for point in [(400, 448), (512, 512), (624, 448)] {
            let sampledPixel = try pixel(in: renderedPixels, image: image, x: point.0, y: point.1)
            XCTAssertTrue(isCameraWhite(sampledPixel), "App icon camera mark sample at \(point) should stay white.")
        }

        let lensCandidates = [(512, 650), (512, 373), (512, 640), (512, 384)]
        XCTAssertTrue(
            try lensCandidates.contains { point in
                let sampledPixel = try pixel(in: renderedPixels, image: image, x: point.0, y: point.1)
                return isWarmBrandOrange(sampledPixel)
            },
            "App icon should preserve a warm orange lens opening inside the white camera mark."
        )
    }

    func testMarketplacePickerUsesNativeNavigationListChrome() throws {
        let marketplace = try String(contentsOf: projectURL("BuySellAI/Features/MarketplacePicker/MarketplacePickerSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(marketplace.range(of: #"NavigationStack {"#))
        XCTAssertNotNil(marketplace.range(of: #"List {"#))
        XCTAssertNotNil(marketplace.range(of: #"Section("All places".localized) {"#))
        XCTAssertNotNil(marketplace.range(of: #".listStyle(.insetGrouped)"#))
        XCTAssertNotNil(marketplace.range(of: #".scrollContentBackground(.hidden)"#))
        XCTAssertNotNil(marketplace.range(of: #".contentMargins(.bottom, Spacing.xxxl, for: .scrollContent)"#))
        XCTAssertNotNil(marketplace.range(of: #".navigationTitle("Best place to sell".localized)"#))
        XCTAssertNotNil(marketplace.range(of: #".navigationBarTitleDisplayMode(.inline)"#))
        XCTAssertNil(marketplace.range(of: #".padding(.bottom, Spacing.xxl)"#))
        XCTAssertNil(marketplace.range(of: #"pinnedViews: [.sectionHeaders]"#))
    }

    func testMarketplaceRowsReserveStablePayoutAndDeltaSpace() throws {
        let rowSource = try String(contentsOf: projectURL("BuySellAI/Features/MarketplacePicker/MarketplaceRow.swift"), encoding: .utf8)
        let rowRange = try XCTUnwrap(rowSource.range(of: "struct MarketplaceRow: View"))
        let fallbackRange = try XCTUnwrap(rowSource.range(of: "struct MarketplaceFallbackRow: View"))
        let row = String(rowSource[rowRange.lowerBound..<fallbackRange.lowerBound])

        XCTAssertEqual(MarketplaceRowLayout.iconSize, 44)
        XCTAssertEqual(MarketplaceRowLayout.payoutCircleSize, 56)
        XCTAssertEqual(MarketplaceRowLayout.payoutStackWidth, 66)
        XCTAssertEqual(MarketplaceRowLayout.deltaReservedHeight, 14)
        XCTAssertEqual(MarketplaceRowLayout.rowMinHeight, 104)
        XCTAssertNotNil(rowSource.range(of: #"var size: CGFloat = MarketplaceRowLayout.iconSize"#))
        XCTAssertNotNil(row.range(of: #".frame(width: MarketplaceRowLayout.payoutStackWidth)"#))
        XCTAssertNotNil(row.range(of: #".frame(height: MarketplaceRowLayout.deltaReservedHeight)"#))
        XCTAssertNotNil(row.range(of: #".padding(.vertical, Spacing.sm)"#))
        XCTAssertNotNil(row.range(of: #".frame(minHeight: rowMinHeight)"#))
        XCTAssertNotNil(row.range(of: #".font(.caption.weight(.semibold))"#))
        XCTAssertNil(rowSource.range(of: #".brandFont("#))
        XCTAssertNil(row.range(of: #".tracking("#))
        XCTAssertNil(row.range(of: #".font(.system"#))
    }

    func testVisibleAppTextAvoidsCustomLetterSpacingAndForcedUppercase() throws {
        let sourceFiles = try appSwiftFiles()

        for file in sourceFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            XCTAssertNil(source.range(of: #".tracking("#), "\(file.lastPathComponent) should use native letter spacing.")
            XCTAssertNil(source.range(of: #".kerning("#), "\(file.lastPathComponent) should use native letter spacing.")
            XCTAssertNil(source.range(of: #".textCase(.uppercase)"#), "\(file.lastPathComponent) should keep visible copy in its written case.")
        }
    }

    func testMarketplaceRowsAdaptForAccessibilityDynamicTypeAndPressFeedback() throws {
        let row = try String(contentsOf: projectURL("BuySellAI/Features/MarketplacePicker/MarketplaceRow.swift"), encoding: .utf8)

        XCTAssertEqual(MarketplaceRowLayout.accessibilityPayoutCircleSize, 64)
        XCTAssertEqual(MarketplaceRowLayout.accessibilityRowMinHeight, 148)
        XCTAssertNotNil(row.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(row.range(of: #"if dynamicTypeSize.isAccessibilitySize"#))
        XCTAssertNotNil(row.range(of: #"private var regularRowContent: some View"#))
        XCTAssertNotNil(row.range(of: #"private var accessibilityRowContent: some View"#))
        XCTAssertNotNil(row.range(of: #"marketplaceCopy(nameLineLimit: 1, blurbLineLimit: 2, fitLineLimit: 1)"#))
        XCTAssertNotNil(row.range(of: #"marketplaceCopy(nameLineLimit: 2, blurbLineLimit: 3, fitLineLimit: 2)"#))
        XCTAssertNotNil(row.range(of: #"Text(estimate.comparisonSignals(for: item).rowLine)"#))
        XCTAssertNotNil(row.range(of: #"struct MarketplaceComparisonSignals: Sendable, Hashable"#))
        XCTAssertNotNil(row.range(of: #"List around %@"#))
        XCTAssertNotNil(row.range(of: #"Fast sale"#))
        XCTAssertNotNil(row.range(of: #"Local pickup"#))
        XCTAssertNotNil(row.range(of: #"if let fitSummary = estimate.fitSummary"#))
        XCTAssertNotNil(row.range(of: #"Text(fitSummary.localized)"#))
        XCTAssertNotNil(row.range(of: #".font(.caption2.weight(.semibold))"#))
        XCTAssertNotNil(row.range(of: #"estimate.fitScore >= 82 ? Color.brand.success : Color.brand.mutedForeground"#))
        XCTAssertNotNil(row.range(of: #"payoutCircle(size: MarketplaceRowLayout.accessibilityPayoutCircleSize)"#))
        XCTAssertNotNil(row.range(of: #".padding(.leading, MarketplaceRowLayout.iconSize + Spacing.md)"#))
        XCTAssertNotNil(row.range(of: #".frame(minHeight: 44)"#))
        XCTAssertNotNil(row.range(of: #"NativeMaterialRoundedBackground("#))
        XCTAssertNotNil(row.range(of: #"tintOpacity: 0.7"#))
        XCTAssertNotNil(row.range(of: #"dynamicTypeSize.isAccessibilitySize ? MarketplaceRowLayout.accessibilityRowMinHeight : MarketplaceRowLayout.rowMinHeight"#))
        XCTAssertNotNil(row.range(of: #".buttonStyle(PressButtonStyle())"#))
        XCTAssertNil(row.range(of: #".buttonStyle(.plain)"#))
    }

    func testMarketplaceFallbackRowsUseNativePressAndAccessibilityDynamicTypeLayout() throws {
        let picker = try String(contentsOf: projectURL("BuySellAI/Features/MarketplacePicker/MarketplacePickerSheet.swift"), encoding: .utf8)
        let row = try String(contentsOf: projectURL("BuySellAI/Features/MarketplacePicker/MarketplaceRow.swift"), encoding: .utf8)
        let fallbackRange = try XCTUnwrap(row.range(of: "struct MarketplaceFallbackRow: View"))
        let accessibilityRange = try XCTUnwrap(row.range(of: "enum MarketplaceAccessibilityText"))
        let fallback = String(row[fallbackRange.lowerBound..<accessibilityRange.lowerBound])

        XCTAssertEqual(MarketplaceRowLayout.fallbackRowMinHeight, 72)
        XCTAssertEqual(MarketplaceRowLayout.fallbackAccessibilityRowMinHeight, 112)
        XCTAssertNotNil(picker.range(of: "ForEach(Marketplace.activeRecommendationCases)"))
        XCTAssertNotNil(picker.range(of: "MarketplaceFallbackRow(marketplace: marketplace)"))
        XCTAssertNotNil(fallback.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(fallback.range(of: #"if dynamicTypeSize.isAccessibilitySize"#))
        XCTAssertNotNil(fallback.range(of: #"marketplaceCopy(nameLineLimit: 1, blurbLineLimit: 2)"#))
        XCTAssertNotNil(fallback.range(of: #"marketplaceCopy(nameLineLimit: 2, blurbLineLimit: 3)"#))
        XCTAssertNotNil(fallback.range(of: #".overlay(alignment: .bottomTrailing)"#))
        XCTAssertNotNil(fallback.range(of: #"Image(systemName: "chevron.right")"#))
        XCTAssertNotNil(fallback.range(of: #".buttonStyle(PressButtonStyle())"#))
        XCTAssertNotNil(fallback.range(of: #".accessibilityHint("Drafts a listing without a payout estimate".localized)"#))
        XCTAssertNotNil(fallback.range(of: #"dynamicTypeSize.isAccessibilitySize ? MarketplaceRowLayout.fallbackAccessibilityRowMinHeight : MarketplaceRowLayout.fallbackRowMinHeight"#))
        XCTAssertNil(fallback.range(of: #".buttonStyle(.plain)"#))
        XCTAssertNil(picker.range(of: #".frame(minHeight: 72)"#))
    }

    func testMarketplaceIconsUseNativeSymbolsInsteadOfShortTextMarks() throws {
        let marketplace = try String(contentsOf: projectURL("BuySellAI/Data/Marketplace.swift"), encoding: .utf8)
        let row = try String(contentsOf: projectURL("BuySellAI/Features/MarketplacePicker/MarketplaceRow.swift"), encoding: .utf8)

        XCTAssertNotNil(marketplace.range(of: "var iconSystemName: String"))
        XCTAssertNotNil(row.range(of: #"Image(systemName: marketplace.iconSystemName)"#))
        XCTAssertNotNil(row.range(of: #".symbolRenderingMode(.hierarchical)"#))
        XCTAssertNotNil(row.range(of: #".stroke(marketplace.brandTint.opacity(0.22), lineWidth: 1)"#))
        XCTAssertNil(marketplace.range(of: "var shortMark"))
        XCTAssertNil(marketplace.range(of: "displayName.prefix(1)"))
        XCTAssertNil(row.range(of: "Text(marketplace.shortMark)"))
    }

    func testMarketplaceSummaryActionsAdaptForAccessibilityDynamicTypeAndNativeButtons() throws {
        let marketplace = try String(contentsOf: projectURL("BuySellAI/Features/MarketplacePicker/MarketplacePickerSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(marketplace.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(marketplace.range(of: #"private func summaryActions(picks: [MarketplaceSummaryPick]) -> some View"#))
        XCTAssertNotNil(marketplace.range(of: #"recommendationSections(picks: MarketplaceSummaryPlanner.picks("#))
        XCTAssertNotNil(marketplace.range(of: #"item: context.item"#))
        XCTAssertNotNil(marketplace.range(of: #"details: context.details"#))
        XCTAssertNotNil(marketplace.range(of: #"private func recommendationSections(picks: [MarketplaceSummaryPick]) -> some View"#))
        XCTAssertNotNil(marketplace.range(of: #"Section("Best place to sell".localized) {"#))
        XCTAssertNotNil(marketplace.range(of: #"recommendedButton(pick: recommendedPick)"#))
        XCTAssertNotNil(marketplace.range(of: #"private struct RecommendedMarketplaceButton: View"#))
        XCTAssertNotNil(marketplace.range(of: #"Text("We found the best place to sell this".localized)"#))
        XCTAssertNotNil(marketplace.range(of: #".accessibilityLabel(MarketplaceAccessibilityText.summaryLabel(pick.kind.label, for: pick.estimate, item: item))"#))
        XCTAssertNotNil(marketplace.range(of: #".accessibilityIdentifier("MarketplaceSummary.\(pick.kind.rawValue).\(pick.estimate.id.rawValue)")"#))
        XCTAssertNotNil(marketplace.range(of: #"Section("Compare".localized) {"#))
        XCTAssertNotNil(marketplace.range(of: #"let otherPicks = Array(picks.dropFirst())"#))
        XCTAssertNotNil(marketplace.range(of: #"HStack(alignment: .center, spacing: Spacing.sm)"#))
        XCTAssertNotNil(marketplace.range(of: #"summaryButton(pick: pick, isRecommended: false)"#))
        XCTAssertNil(marketplace.range(of: #"summaryButton(pick: recommendedPick, isRecommended: true)"#))
        XCTAssertNotNil(marketplace.range(of: #"Image(systemName: "chevron.right")"#))
        XCTAssertNotNil(marketplace.range(of: #".buttonStyle(PressButtonStyle())"#))
        XCTAssertNil(marketplace.range(of: #"VStack(spacing: Spacing.sm)"#))
        XCTAssertNil(marketplace.range(of: #".buttonStyle(.bordered)"#))
        XCTAssertNil(marketplace.range(of: #".buttonBorderShape(.capsule)"#))
        XCTAssertNil(marketplace.range(of: #".controlSize(.large)"#))
        XCTAssertNotNil(marketplace.range(of: #".monospacedDigit()"#))
        let obsoleteBestConditional = #"label == ""# + "Best" + #"""#
        XCTAssertNil(marketplace.range(of: obsoleteBestConditional))
        XCTAssertNil(marketplace.range(of: #".brandFont("#))
        XCTAssertNotNil(marketplace.range(of: #".font(.caption.weight(.semibold))"#))
        XCTAssertNotNil(marketplace.range(of: #".font(.body.weight(.semibold))"#))
        XCTAssertNil(marketplace.range(of: #".nativeMaterialPanel(cornerRadius: Radius.lg, tintOpacity: 0.72)"#))
        XCTAssertNil(marketplace.range(of: #"NativeMaterialRoundedBackground("#))
        XCTAssertNotNil(marketplace.range(of: #"Text("Take-home".localized)"#))
        XCTAssertNotNil(marketplace.range(of: #"Label(pick.kind.label.localized, systemImage: pick.kind.systemImage)"#))
        XCTAssertNotNil(marketplace.range(of: #"Text(pick.estimate.comparisonSignals(for: item).summaryLine)"#))
        XCTAssertNotNil(marketplace.range(of: #"if let fitSummary = pick.estimate.fitSummary"#))
        XCTAssertNotNil(marketplace.range(of: #".font(.caption2.weight(.semibold))"#))
        XCTAssertNotNil(marketplace.range(of: #"private var summaryLineLimit: Int"#))
        XCTAssertNotNil(marketplace.range(of: #"dynamicTypeSize.isAccessibilitySize ? 2 : 1"#))
        XCTAssertNotNil(marketplace.range(of: #".accessibilityLabel("Checking places to sell".localized)"#))
        XCTAssertNotNil(marketplace.range(of: #".accessibilityAddTraits(.updatesFrequently)"#))
    }

    func testHomeRemovesDecorativePrimaryGlowAndUsesNativeTaskRows() throws {
        let buttons = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)
        let designTokens = try String(contentsOf: projectURL("BuySellAI/Design/DesignTokens.swift"), encoding: .utf8)
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)

        XCTAssertNil(buttons.range(of: "showsGlow"))
        XCTAssertNil(buttons.range(of: "PrimaryGlowModifier"))
        XCTAssertNil(designTokens.range(of: "static func primaryGlow()"))
        XCTAssertNil(designTokens.range(of: "Color.brand.primary.opacity(0.35), radius: 30, y: 12"))
        XCTAssertNotNil(buttons.range(of: "struct TextActionButton: View"))
        XCTAssertNotNil(buttons.range(of: "struct PressButtonStyle: ButtonStyle"))
        XCTAssertNotNil(buttons.range(of: ".nativeGlassButtonStyle(.standard)"))
        XCTAssertNotNil(home.range(of: "HomeCameraHeroMark(startSnapFlow: startSnapFlow)"))
        XCTAssertNotNil(home.range(of: "private struct HomeStepRow: View"))
        XCTAssertNotNil(home.range(of: #"Text("Snap to sell".localized)"#))
        XCTAssertNotNil(home.range(of: #"Text("Photo. Questions. Listing.".localized)"#))
        XCTAssertNotNil(home.range(of: #"Image(systemName: "camera.aperture")"#))
        XCTAssertNil(home.range(of: #"PrimaryPillButton("#))
        XCTAssertNil(home.range(of: #"systemImage: "camera.fill""#))
    }

    func testHomeUsesNativeToolbarInsteadOfCustomHeaderControls() throws {
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)

        XCTAssertNotNil(home.range(of: #".toolbar {"#))
        XCTAssertNotNil(home.range(of: #"ToolbarItem(placement: .principal) {"#))
        XCTAssertNotNil(home.range(of: #"ToolbarItem(placement: .topBarTrailing) {"#))
        XCTAssertNotNil(home.range(of: #".navigationTitle("BuySell.".localized)"#))
        XCTAssertNotNil(home.range(of: "BrandWordmark(size: .regular, periodColor: Color.brand.foregroundSecondary)"))
        XCTAssertNotNil(home.range(of: #"private var accountButton: some View"#))
        XCTAssertNotNil(home.range(of: #"private var settingsButton: some View"#))
        XCTAssertNil(home.range(of: "@ViewBuilder\n    private var header: some View"))
        XCTAssertNil(home.range(of: #"private var brandLockup: some View"#))
        XCTAssertNil(home.range(of: #".nativeLiquidGlassControlGroup(spacing: Spacing.sm)"#))
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

    func testSnapResultChangeActionsUseNativeMenusForExactSelection() throws {
        let snapResult = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)
        let store = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultStore.swift"), encoding: .utf8)

        XCTAssertNotNil(snapResult.range(of: "categoryMenuButton(selected: item.category)"))
        XCTAssertNotNil(snapResult.range(of: "conditionMenuButton(selected: item.condition)"))
        XCTAssertGreaterThanOrEqual(snapResult.components(separatedBy: "Menu {").count - 1, 2)
        XCTAssertNotNil(snapResult.range(of: "ForEach(Category.allCases, id: \\.self)"))
        XCTAssertNotNil(snapResult.range(of: "ForEach(Condition.allCases, id: \\.self)"))
        XCTAssertNotNil(snapResult.range(of: "systemImage: categoryMenuItemIcon(for: category)"))
        XCTAssertNotNil(snapResult.range(of: "systemImage: conditionMenuItemIcon(for: condition)"))
        XCTAssertNotNil(snapResult.range(of: "private func categoryMenuItemIcon(for category: Category) -> String"))
        XCTAssertNotNil(snapResult.range(of: "private func conditionMenuItemIcon(for condition: Condition) -> String"))
        XCTAssertNotNil(snapResult.range(of: #"Image(systemName: isSelected ? "checkmark.circle.fill" : systemImage)"#))
        XCTAssertNotNil(snapResult.range(of: #".electronics: "display""#))
        XCTAssertNotNil(snapResult.range(of: #".furniture: "house""#))
        XCTAssertNotNil(snapResult.range(of: #".forParts: "wrench""#))
        XCTAssertNotNil(snapResult.range(of: "store.selectCategory(category)"))
        XCTAssertNotNil(snapResult.range(of: "store.selectCondition(condition)"))
        XCTAssertNotNil(store.range(of: "func selectCategory(_ category: Category)"))
        XCTAssertNotNil(store.range(of: "func selectCondition(_ condition: Condition)"))
    }

    func testSnapResultChangeMenuTriggersUseNativeBorderedControlsAndCurrentValues() throws {
        let snapResult = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)
        let categoryRange = try XCTUnwrap(snapResult.range(of: "private func categoryMenuButton"))
        let itemNameRange = try XCTUnwrap(snapResult.range(of: "private var itemNameControl"))
        let menuSource = String(snapResult[categoryRange.lowerBound..<itemNameRange.lowerBound])
        let labelRange = try XCTUnwrap(snapResult.range(of: "private struct SnapResultMenuLabel"))
        let photoRange = try XCTUnwrap(snapResult.range(of: "struct PhotoThumbnail", range: labelRange.upperBound..<snapResult.endIndex))
        let labelSource = String(snapResult[labelRange.lowerBound..<photoRange.lowerBound])

        XCTAssertNotNil(menuSource.range(of: #"SnapResultMenuLabel(title: "Change category", systemImage: "tag", maxWidth: sheetContentMaxWidth)"#))
        XCTAssertNotNil(menuSource.range(of: #"SnapResultMenuLabel(title: "Change condition", systemImage: "slider.horizontal.3", maxWidth: sheetContentMaxWidth)"#))
        XCTAssertGreaterThanOrEqual(menuSource.components(separatedBy: #".buttonStyle(.bordered)"#).count - 1, 2)
        XCTAssertNil(menuSource.range(of: #".buttonBorderShape(.capsule)"#))
        XCTAssertGreaterThanOrEqual(menuSource.components(separatedBy: #".controlSize(.large)"#).count - 1, 2)
        XCTAssertEqual(menuSource.components(separatedBy: #".accessibilityValue(Text(selected.display.localized))"#).count - 1, 2)
        XCTAssertNotNil(menuSource.range(of: #".accessibilityHint("Opens category choices".localized)"#))
        XCTAssertNotNil(menuSource.range(of: #".accessibilityHint("Opens condition choices".localized)"#))
        XCTAssertNil(menuSource.range(of: #".buttonStyle(.plain)"#))
        XCTAssertNil(menuSource.range(of: #".buttonStyle(PressButtonStyle())"#))
        XCTAssertNotNil(labelSource.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(labelSource.range(of: #"Image(systemName: "chevron.down")"#))
        XCTAssertNil(labelSource.range(of: #".nativeMaterialPanel("#))
        XCTAssertNotNil(labelSource.range(of: #".contentShape(Rectangle())"#))
        XCTAssertNotNil(labelSource.range(of: "private var lineLimit: Int {\n        2\n    }"))
        XCTAssertNotNil(labelSource.range(of: #".frame(maxWidth: maxWidth ?? .infinity, minHeight: 44)"#))
    }

    func testSnapResultSecondaryActionsUseReadableHybridOnNarrowPhonesAndGridOnWideLayouts() throws {
        let snapResult = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(snapResult.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(snapResult.range(of: #"secondaryActions(item: item)"#))
        XCTAssertNotNil(snapResult.range(of: #"private func secondaryActions(item: DetectedItem) -> some View"#))
        XCTAssertNotNil(snapResult.range(of: #"if usesRegularSecondaryActionGrid"#))
        XCTAssertNotNil(snapResult.range(of: #"LazyVGrid(columns: secondaryActionColumns, spacing: Spacing.sm)"#))
        XCTAssertNotNil(snapResult.range(of: #"LazyVGrid(columns: compactQuickActionColumns, spacing: Spacing.sm)"#))
        XCTAssertNotNil(snapResult.range(of: #"categoryMenuButton(selected: item.category)"#))
        XCTAssertNotNil(snapResult.range(of: #"conditionMenuButton(selected: item.condition)"#))
        XCTAssertNotNil(snapResult.range(of: #"private var secondaryActionColumns: [GridItem]"#))
        XCTAssertNotNil(snapResult.range(of: #"private var compactQuickActionColumns: [GridItem]"#))
        XCTAssertNotNil(snapResult.range(of: #"private var usesRegularSecondaryActionGrid: Bool"#))
        XCTAssertNotNil(snapResult.range(of: #"(usesRegularWidthLayout || UIScreen.main.bounds.width >= 430)"#))
        XCTAssertNotNil(snapResult.range(of: #"&& dynamicTypeSize.isAccessibilitySize == false"#))
        XCTAssertNotNil(snapResult.range(of: "dynamicTypeSize.isAccessibilitySize\n            ? [GridItem(.flexible())]\n            : [GridItem(.flexible()), GridItem(.flexible())]"))
        XCTAssertNotNil(snapResult.range(of: #"SnapResultMenuLabel(title: "Change category", systemImage: "tag", maxWidth: sheetContentMaxWidth)"#))
        XCTAssertNotNil(snapResult.range(of: #"SnapResultMenuLabel(title: "Change condition", systemImage: "slider.horizontal.3", maxWidth: sheetContentMaxWidth)"#))
        XCTAssertNotNil(m10.range(of: "Narrow-iPhone result actions keep quick retake/retry controls paired while rendering category and condition menu triggers as full-width material rows"))
    }

    func testAuthEmailSignInUsesNavigationPush() throws {
        let authView = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)
        let authStore = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthStore.swift"), encoding: .utf8)

        XCTAssertNotNil(authView.range(of: #"NavigationStack(path: $path)"#))
        XCTAssertNotNil(authView.range(of: #"NavigationLink(value: AuthRoute.email)"#))
        XCTAssertNotNil(authView.range(of: #".navigationDestination(for: AuthRoute.self)"#))
        XCTAssertNotNil(authView.range(of: #"private struct EmailSignInView"#))
        XCTAssertNil(authView.range(of: "showsEmailForm"))
        XCTAssertNil(authStore.range(of: "showsEmailForm"))
    }

    func testAuthSignInProviderActionsUseNativeListRows() throws {
        let authView = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)

        XCTAssertNotNil(authView.range(of: #"Button {"#))
        XCTAssertNotNil(authView.range(of: #"signInWithApple()"#))
        XCTAssertNotNil(authView.range(of: #"Label("Continue with Apple".localized, systemImage: "apple.logo")"#))
        XCTAssertNotNil(authView.range(of: #"NavigationLink(value: AuthRoute.email)"#))
        XCTAssertNotNil(authView.range(of: #"Label("Continue with Email".localized, systemImage: "envelope.fill")"#))
        XCTAssertNil(authView.range(of: #".brandFont("#))
        XCTAssertNotNil(authView.range(of: #".font(.body)"#))
        XCTAssertNil(authView.range(of: #"PrimaryPillButton(title: "Continue with Apple""#))
        XCTAssertNil(authView.range(of: #"SecondaryPillButton(title: "Continue with Email""#))
    }

    func testAuthSetupAndEmailFormUseKeyboardAwareNativeListLayout() throws {
        let authView = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)
        let emailViewRange = try XCTUnwrap(authView.range(of: "private struct EmailSignInView"))
        let routeRange = try XCTUnwrap(authView.range(of: "private enum Field", range: emailViewRange.upperBound..<authView.endIndex))
        let emailView = String(authView[emailViewRange.lowerBound..<routeRange.lowerBound])

        XCTAssertNotNil(authView.range(of: "import UIKit"))
        XCTAssertNotNil(authView.range(of: #"@Environment(\.horizontalSizeClass) private var horizontalSizeClass"#))
        XCTAssertNotNil(authView.range(of: #"private var authContentMaxWidth: CGFloat"#))
        XCTAssertNotNil(authView.range(of: #"usesRegularWidthLayout ? 560 : .infinity"#))
        XCTAssertNotNil(authView.range(of: #".frame(maxWidth: authContentMaxWidth)"#))
        XCTAssertNotNil(authView.range(of: #".scrollDismissesKeyboard(.interactively)"#))
        XCTAssertNotNil(authView.range(of: #"List {"#))
        XCTAssertNotNil(authView.range(of: #".listStyle(.insetGrouped)"#))
        XCTAssertNotNil(authView.range(of: #".navigationTitle("Sign in".localized)"#))
        XCTAssertNotNil(authView.range(of: #"private var closeAuthButton: some View"#))
        XCTAssertNotNil(authView.range(of: #".contentMargins(.bottom, authBottomContentInset, for: .scrollContent)"#))

        XCTAssertNotNil(emailView.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(emailView.range(of: #"@Environment(\.horizontalSizeClass) private var horizontalSizeClass"#))
        XCTAssertNotNil(emailView.range(of: "List {"))
        XCTAssertNotNil(emailView.range(of: ".listStyle(.insetGrouped)"))
        XCTAssertNotNil(emailView.range(of: ".scrollDismissesKeyboard(.interactively)"))
        XCTAssertNotNil(emailView.range(of: ".safeAreaInset(edge: .bottom)"))
        XCTAssertNotNil(emailView.range(of: "emailBottomAction(store)"))
        XCTAssertNotNil(emailView.range(of: #"Label("Sign in".localized, systemImage: "arrow.right")"#))
        XCTAssertNotNil(emailView.range(of: ".buttonStyle(.borderedProminent)"))
        XCTAssertNotNil(emailView.range(of: ".background(.bar)"))
        XCTAssertNil(authView.range(of: ".buttonBorderShape(.capsule)"))
        XCTAssertNil(authView.range(of: ".nativeLiquidGlassControlGroup"))
        XCTAssertNil(emailView.range(of: "PrimaryPillButton("))
        XCTAssertNil(emailView.range(of: ".nativeMaterialBar(tintOpacity: 0.78)"))
        XCTAssertNotNil(emailView.range(of: "private var contentMaxWidth: CGFloat"))
        XCTAssertNotNil(emailView.range(of: "dynamicTypeSize.isAccessibilitySize ? 120 : 96"))
    }

    func testDeleteAccountActionRowPushesConfirmationScreenWithExplicitVoiceOverLabel() throws {
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)

        XCTAssertNotNil(settings.range(of: #"@State private var showDeleteAccount = false"#))
        XCTAssertNotNil(settings.range(of: #"SettingsActionRow("#))
        XCTAssertNotNil(settings.range(of: #"title: "Delete account""#))
        XCTAssertNotNil(settings.range(of: #"systemImage: "person.crop.circle.badge.xmark""#))
        XCTAssertNotNil(settings.range(of: #"accessibilityIdentifier: "Settings.DeleteAccount""#))
        XCTAssertNotNil(settings.range(of: #"showDeleteAccount = true"#))
        XCTAssertNotNil(settings.range(of: #".navigationDestination(isPresented: $showDeleteAccount)"#))
        XCTAssertNotNil(settings.range(of: #"DeleteAccountView()"#))
        XCTAssertNil(settings.range(of: #"NavigationLink {"#))
    }

    func testSettingsPreferenceControlsHaveExplicitVoiceOverLabels() throws {
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)

        XCTAssertNotNil(settings.range(of: #"Picker("Theme".localized"#))
        XCTAssertNotNil(settings.range(of: #".accessibilityLabel("Theme".localized)"#))
        XCTAssertNotNil(settings.range(of: #"Toggle("Reduce Motion".localized"#))
        XCTAssertNotNil(settings.range(of: #".accessibilityLabel("Reduce Motion".localized)"#))
        XCTAssertGreaterThanOrEqual(settings.components(separatedBy: #".tint(Color.brand.primary)"#).count - 1, 2)
        XCTAssertNotNil(settings.range(of: #".onChange(of: store.theme)"#))
        XCTAssertNotNil(settings.range(of: #".onChange(of: store.reduceMotion)"#))
        XCTAssertGreaterThanOrEqual(settings.components(separatedBy: #"Haptics.impact(.light)"#).count - 1, 3)
    }

    func testSettingsAboutLinksUseInAppSafari() throws {
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)

        XCTAssertNotNil(settings.range(of: "import SafariServices"))
        XCTAssertNotNil(settings.range(of: #"title: "Privacy policy""#))
        XCTAssertNotNil(settings.range(of: #"AppStoreLinks.url(for: .privacyPolicy).map(SafariDestination.init)"#))
        XCTAssertNotNil(settings.range(of: #"title: "Terms""#))
        XCTAssertNotNil(settings.range(of: #"AppStoreLinks.url(for: .terms).map(SafariDestination.init)"#))
        XCTAssertNotNil(settings.range(of: #".sheet(item: $safariDestination)"#))
        XCTAssertNotNil(settings.range(of: "private struct SafariView: UIViewControllerRepresentable"))
        XCTAssertNotNil(settings.range(of: "SFSafariViewController(url: url)"))
        XCTAssertNil(settings.range(of: "UIApplication.shared.open"))
    }

    func testSettingsRowsUseNativeDisclosureLabelsWithStableTapHeight() throws {
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)

        XCTAssertNotNil(settings.range(of: "private struct SettingsRowLabel: View"))
        XCTAssertNotNil(settings.range(of: #".frame(width: 32, height: 32)"#))
        XCTAssertNotNil(settings.range(of: #".symbolRenderingMode(.hierarchical)"#))
        XCTAssertNotNil(settings.range(of: #"var showsDisclosureIndicator = false"#))
        XCTAssertNotNil(settings.range(of: #"showsDisclosureIndicator: true"#))
        XCTAssertNotNil(settings.range(of: #"Image(systemName: "chevron.right")"#))
        XCTAssertNil(settings.range(of: "NativeMaterialRoundedBackground("))
        XCTAssertNil(settings.range(of: ".background(iconTint.opacity(0.12)"))
        XCTAssertNotNil(settings.range(of: #".frame(minHeight: 44)"#))
        XCTAssertNotNil(settings.range(of: #".contentShape(Rectangle())"#))
        XCTAssertNotNil(settings.range(of: #".accessibilityElement(children: .combine)"#))
        XCTAssertNotNil(settings.range(of: #"systemImage: "questionmark.circle.fill""#))
        XCTAssertNotNil(settings.range(of: #"systemImage: "trash.fill""#))
        XCTAssertNotNil(settings.range(of: #"systemImage: "star.fill""#))
        XCTAssertNotNil(settings.range(of: #"systemImage: "hand.raised.fill""#))
        XCTAssertNotNil(settings.range(of: #"systemImage: "doc.text.fill""#))
    }

    func testSettingsRowsAdaptValueLayoutForAccessibilityDynamicType() throws {
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)

        XCTAssertNotNil(settings.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(settings.range(of: #"private var labelContent: some View"#))
        XCTAssertNotNil(settings.range(of: #"if let value, dynamicTypeSize.isAccessibilitySize"#))
        XCTAssertNotNil(settings.range(of: #"VStack(alignment: .leading, spacing: Spacing.xxs)"#))
        XCTAssertNotNil(settings.range(of: #"private var titleText: some View"#))
        XCTAssertNotNil(settings.range(of: #"private func valueText(_ value: String) -> some View"#))
        XCTAssertNotNil(settings.range(of: #".lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)"#))
        XCTAssertNil(settings.range(of: #".brandFont("#))
        XCTAssertNotNil(settings.range(of: #".font(.body)"#))
        XCTAssertNotNil(settings.range(of: #".font(.caption)"#))
    }

    func testSettingsActionRowsUseSharedPressFeedbackAndHaptics() throws {
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)

        XCTAssertNotNil(settings.range(of: "private struct SettingsActionRow: View"))
        XCTAssertNotNil(settings.range(of: "Button(role: role)"))
        XCTAssertNotNil(settings.range(of: "Haptics.impact(.light)"))
        XCTAssertNotNil(settings.range(of: ".buttonStyle(.automatic)"))
        XCTAssertNotNil(settings.range(of: ".accessibilityLabel(Text(title.localized))"))
        XCTAssertNotNil(settings.range(of: ".settingsAccessibilityIdentifier(accessibilityIdentifier)"))
        XCTAssertGreaterThanOrEqual(settings.components(separatedBy: "SettingsActionRow(").count - 1, 6)
        XCTAssertNil(settings.range(of: ".buttonStyle(PressButtonStyle())"))
        XCTAssertNil(settings.range(of: #"Button("Close".localized)"#))
    }

    func testSettingsCloseControlsUseNativeToolbarIconButtons() throws {
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)

        XCTAssertNotNil(settings.range(of: #"Label("Close settings".localized, systemImage: "xmark")"#))
        XCTAssertNotNil(settings.range(of: #"Label("Close delete account".localized, systemImage: "xmark")"#))
        XCTAssertGreaterThanOrEqual(settings.components(separatedBy: #".labelStyle(.iconOnly)"#).count - 1, 2)
        XCTAssertNotNil(settings.range(of: #".accessibilityLabel("Close settings".localized)"#))
        XCTAssertNotNil(settings.range(of: #".accessibilityLabel("Close delete account".localized)"#))
        XCTAssertNil(settings.range(of: "IconCircleButton("))
        XCTAssertNil(settings.range(of: "materialForeground: Color.brand.foreground"))
    }

    func testDeleteAccountViewUsesNativeKeyboardAwareListAndActionBar() throws {
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)
        let deleteViewRange = try XCTUnwrap(settings.range(of: "private struct DeleteAccountView"))
        let safariRange = try XCTUnwrap(settings.range(of: "private struct SafariDestination", range: deleteViewRange.upperBound..<settings.endIndex))
        let deleteView = String(settings[deleteViewRange.lowerBound..<safariRange.lowerBound])

        XCTAssertNotNil(deleteView.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(deleteView.range(of: #"@Environment(\.horizontalSizeClass) private var horizontalSizeClass"#))
        XCTAssertNotNil(deleteView.range(of: "List {"))
        XCTAssertNotNil(deleteView.range(of: ".listStyle(.insetGrouped)"))
        XCTAssertNotNil(deleteView.range(of: ".scrollContentBackground(.hidden)"))
        XCTAssertNotNil(deleteView.range(of: #".contentMargins(.bottom, bottomContentInset, for: .scrollContent)"#))
        XCTAssertNotNil(deleteView.range(of: ".scrollDismissesKeyboard(.interactively)"))
        XCTAssertNotNil(deleteView.range(of: ".safeAreaInset(edge: .bottom)"))
        XCTAssertNotNil(deleteView.range(of: "deleteBottomAction"))
        XCTAssertNotNil(deleteView.range(of: "Button(role: .destructive)"))
        XCTAssertNotNil(deleteView.range(of: #"Label(isDeletingAccount ? "Deleting…".localized : "Delete account".localized, systemImage: "person.crop.circle.badge.xmark")"#))
        XCTAssertNotNil(deleteView.range(of: ".buttonStyle(.borderedProminent)"))
        XCTAssertNil(deleteView.range(of: ".buttonBorderShape(.capsule)"))
        XCTAssertNotNil(deleteView.range(of: ".controlSize(.large)"))
        XCTAssertNotNil(deleteView.range(of: ".tint(Color.brand.destructive)"))
        XCTAssertNotNil(deleteView.range(of: ".background(.bar)"))
        XCTAssertNotNil(deleteView.range(of: #".navigationTitle("Delete account".localized)"#))
        XCTAssertNil(deleteView.range(of: "ScrollView {"))
        XCTAssertNil(deleteView.range(of: "PrimaryPillButton("))
        XCTAssertNil(deleteView.range(of: ".nativeMaterialBar("))
        XCTAssertNotNil(deleteView.range(of: "private var contentMaxWidth: CGFloat"))
        XCTAssertNotNil(deleteView.range(of: "usesRegularWidthLayout ? 560 : .infinity"))
        XCTAssertNotNil(deleteView.range(of: "private var bottomContentInset: CGFloat"))
        XCTAssertNotNil(deleteView.range(of: "dynamicTypeSize.isAccessibilitySize ? 136 : 104"))
        XCTAssertNotNil(deleteView.range(of: ".task {"))
        XCTAssertNotNil(deleteView.range(of: "isConfirmationFocused = true"))
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

    func testCameraControlsExposeVoiceOverLabelsAndPhotoImportRecovery() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraView.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"import PhotosUI"#))
        XCTAssertNotNil(source.range(of: #"accessibilityLabel("Take photo".localized)"#))
        XCTAssertNotNil(source.range(of: #"accessibilityHint("Captures the current view".localized)"#))
        XCTAssertNotNil(source.range(of: #"accessibilityLabel("Choose Photo".localized)"#))
        XCTAssertNotNil(source.range(of: #"accessibilityHint("Imports a photo from your library.".localized)"#))
        XCTAssertNotNil(source.range(of: #".accessibilityLabel("Camera preview".localized)"#))
        XCTAssertNotNil(source.range(of: #".accessibilityHint("Tap the item to set focus and exposure.".localized)"#))
        XCTAssertNotNil(source.range(of: #"accessibilityLabel: "Close camera""#))
        XCTAssertNotNil(source.range(of: #"accessibilityLabel: flashAccessibilityLabel"#))
        XCTAssertNotNil(source.range(of: #"accessibilityLabel: cameraSwitchAccessibilityLabel"#))
        XCTAssertNotNil(source.range(of: #"cameraCapabilities.canSwitchCamera"#))
        XCTAssertNotNil(source.range(of: #"systemImage: "arrow.triangle.2.circlepath.camera""#))
        XCTAssertNotNil(source.range(of: #"cameraCapabilities.position == .back ? "Use front camera" : "Use back camera""#))
        XCTAssertNotNil(source.range(of: #"CameraFocusRing()"#))
        XCTAssertNotNil(source.range(of: #".accessibilityHidden(true)"#))
        XCTAssertNotNil(source.range(of: #"guard isFlashAvailable else { return "Flash unavailable" }"#))
        XCTAssertNotNil(source.range(of: #"private func cameraBottomControls(safeAreaBottom: CGFloat) -> some View"#))
        XCTAssertNotNil(source.range(of: #"private var shutterButton: some View"#))
        XCTAssertNotNil(source.range(of: #"private var photoImportButton: some View"#))
        XCTAssertNotNil(source.range(of: #"PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared())"#))
        XCTAssertNotNil(source.range(of: #"private func photoFallbackButton(sortPriority: Double) -> some View"#))
        XCTAssertNotNil(source.range(of: #"private func importPhoto(_ item: PhotosPickerItem?)"#))
        XCTAssertNotNil(source.range(of: #"ImageTools.jpegDataDownscaled(from: data, maxLongEdge: 1600, compression: 0.85)"#))
        XCTAssertNotNil(source.range(of: #"Photo couldn't be imported."#))
        XCTAssertNotNil(source.range(of: #"private var cameraHintLabel: some View"#))
        XCTAssertNil(source.range(of: #".brandFont("#))
        XCTAssertNotNil(source.range(of: #".font(.caption.weight(.semibold))"#))
        XCTAssertNotNil(source.range(of: #".font(.body)"#))
        XCTAssertNotNil(source.range(of: #".font(.title3.weight(.semibold))"#))
        XCTAssertNotNil(source.range(of: #".nativeMaterialPill(tintOpacity: 0.72, strokeOpacity: 0.64)"#))
        XCTAssertNotNil(source.range(of: #"private var cameraBottomPadding: CGFloat"#))
        XCTAssertNotNil(source.range(of: #"dynamicTypeSize.isAccessibilitySize ? Spacing.xxxl : Spacing.xxl"#))
        XCTAssertNotNil(source.range(of: #"private var cameraBottomMaxWidth: CGFloat"#))
        XCTAssertNotNil(source.range(of: #"usesRegularWidthLayout ? 420 : .infinity"#))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: #".lineLimit(2)"#).count - 1, 1)
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: #".minimumScaleFactor(0.82)"#).count - 1, 1)
        XCTAssertNil(source.range(of: "PHPickerViewController"))
        XCTAssertNil(source.range(of: "UIImagePickerController"))
    }

    func testCameraFallbackPanelsAdaptForLargeTextAndRegularWidths() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraView.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(source.range(of: #"@Environment(\.horizontalSizeClass) private var horizontalSizeClass"#))
        XCTAssertNotNil(source.range(of: #"private func fallbackPanel<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View"#))
        XCTAssertNotNil(source.range(of: "GeometryReader { proxy in"))
        XCTAssertNotNil(source.range(of: "ScrollView {"))
        XCTAssertNotNil(source.range(of: ".scrollBounceBehavior(.basedOnSize)"))
        XCTAssertNotNil(source.range(of: ".nativeMaterialPanel(cornerRadius: Radius.xl, tintOpacity: 0.78)"))
        XCTAssertNotNil(source.range(of: ".frame(minHeight: proxy.size.height)"))
        XCTAssertNotNil(source.range(of: "private var fallbackPanelMaxWidth: CGFloat"))
        XCTAssertNotNil(source.range(of: "usesRegularWidthLayout ? 420 : .infinity"))
        XCTAssertNotNil(source.range(of: "private var fallbackActionsFillWidth: Bool"))
        XCTAssertNotNil(source.range(of: "dynamicTypeSize.isAccessibilitySize"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: ".frame(maxWidth: fallbackActionsFillWidth ? fallbackActionMaxWidth : nil)").count - 1, 3)
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: ".frame(maxWidth: fallbackActionsFillWidth ? .infinity : nil)").count - 1, 3)
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: ".minimumScaleFactor(0.82)").count - 1, 2)
        XCTAssertNotNil(source.range(of: #".buttonStyle(.borderedProminent)"#))
        XCTAssertNotNil(source.range(of: #".buttonStyle(.bordered)"#))
        XCTAssertNil(source.range(of: #"PrimaryPillButton("#))
        XCTAssertNil(source.range(of: #"SecondaryPillButton("#))
    }

    func testCameraPlaceholdersKeepPhotoLibraryIconOnlyInImportControls() throws {
        let appSources = try appSwiftFiles()
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
        let camera = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraView.swift"), encoding: .utf8)
        let history = try String(contentsOf: projectURL("BuySellAI/Features/History/HistoryRow.swift"), encoding: .utf8)
        let snapResult = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(camera.range(of: #"Image(systemName: "photo.on.rectangle")"#))
        XCTAssertNil(appSources.range(of: #"Image(systemName: "photo")"#))
        XCTAssertNotNil(history.range(of: #"Image(systemName: "camera.fill")"#))
        XCTAssertNotNil(snapResult.range(of: #"Image(systemName: "camera.fill")"#))
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
        XCTAssertGreaterThanOrEqual(buttons.components(separatedBy: "AppMotion.shouldReduceMotion").count - 1, 2)
        XCTAssertGreaterThanOrEqual(buttons.components(separatedBy: #"@Environment(\.isEnabled) private var isEnabled"#).count - 1, 2)
        XCTAssertNotNil(buttons.range(of: "enum ButtonStateOpacity"))
        XCTAssertEqual(ButtonStateOpacity.opacity(isEnabled: true, isPressed: false), 1.0)
        XCTAssertEqual(ButtonStateOpacity.opacity(isEnabled: true, isPressed: true), 0.82)
        XCTAssertEqual(ButtonStateOpacity.opacity(isEnabled: false, isPressed: true), 0.48)
        XCTAssertNotNil(buttons.range(of: ".opacity(ButtonStateOpacity.opacity(isEnabled: isEnabled, isPressed: configuration.isPressed))"))
        XCTAssertNotNil(toast.range(of: "AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)"))
        XCTAssertNotNil(camera.range(of: "AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)"))
        XCTAssertNotNil(camera.range(of: ".task(id: shouldReduceMotion)"))
        XCTAssertNil(tutorial.range(of: "DragGesture(minimumDistance: 24)"))
        XCTAssertNil(tutorial.range(of: ".symbolEffect("))
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

    func testTutorialUsesConciseNativeGuide() throws {
        let tutorial = try String(contentsOf: projectURL("BuySellAI/Features/Tutorial/HowItWorksView.swift"), encoding: .utf8)

        XCTAssertNotNil(tutorial.range(of: "private struct CompactGuideGraphic"))
        XCTAssertNotNil(tutorial.range(of: "private struct GuideGlyph"))
        XCTAssertNotNil(tutorial.range(of: "private struct TutorialStepRow"))
        XCTAssertNotNil(tutorial.range(of: "private struct TutorialStep"))
        XCTAssertNotNil(tutorial.range(of: "TutorialStep.steps"))
        XCTAssertNotNil(tutorial.range(of: #"Image(systemName: systemName)"#))
        XCTAssertNotNil(tutorial.range(of: #"Image(systemName: step.systemImage)"#))
        XCTAssertNil(tutorial.range(of: #".brandFont("#))
        XCTAssertNotNil(tutorial.range(of: #".font(.largeTitle.weight(.bold))"#))
        XCTAssertNotNil(tutorial.range(of: #".font(.headline.weight(.semibold))"#))
        XCTAssertNotNil(tutorial.range(of: #"Text("Snap · Pick · Sell".localized)"#))
        XCTAssertNil(tutorial.range(of: "List {"))
        XCTAssertNil(tutorial.range(of: "TabView"))
        XCTAssertNil(tutorial.range(of: "TutorialSlidePage"))
        XCTAssertNil(tutorial.range(of: "DotPager"))
    }

    func testTutorialGraphicEchoesHomeHeroVisualLanguage() throws {
        let tutorial = try String(contentsOf: projectURL("BuySellAI/Features/Tutorial/HowItWorksView.swift"), encoding: .utf8)
        let graphicRange = try XCTUnwrap(tutorial.range(of: "private struct CompactGuideGraphic"))
        let guideGlyphRange = try XCTUnwrap(tutorial.range(of: "private struct GuideGlyph", range: graphicRange.upperBound..<tutorial.endIndex))
        let graphicSource = String(tutorial[graphicRange.lowerBound..<guideGlyphRange.lowerBound])

        XCTAssertNotNil(graphicSource.range(of: #"RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)"#))
        XCTAssertNotNil(graphicSource.range(of: #".fill(Color.brand.primaryMuted)"#))
        XCTAssertNotNil(graphicSource.range(of: #".stroke(Color.brand.border.opacity(0.72), lineWidth: 1)"#))
        XCTAssertNotNil(graphicSource.range(of: #"Image(systemName: "camera.viewfinder")"#))
        XCTAssertNotNil(graphicSource.range(of: #".brandSymbol(.heroIcon)"#))
        XCTAssertNotNil(graphicSource.range(of: #"Image(systemName: "sparkles")"#))
        XCTAssertNotNil(graphicSource.range(of: #"Image(systemName: "doc.on.clipboard")"#))
        XCTAssertNotNil(graphicSource.range(of: #"Image(systemName: "tag")"#))
        XCTAssertNotNil(graphicSource.range(of: #"Image(systemName: "checkmark.circle")"#))
        XCTAssertNotNil(graphicSource.range(of: #".foregroundStyle(Color.brand.primaryText.opacity(0.72))"#))
        XCTAssertNotNil(graphicSource.range(of: #".aspectRatio(1, contentMode: .fit)"#))
        XCTAssertNil(graphicSource.range(of: #"GuideGlyph("#))
        XCTAssertNil(graphicSource.range(of: #"Connector()"#))
        XCTAssertNil(graphicSource.range(of: #"sparkles.rectangle.stack"#))
    }

    func testTutorialCopyHonorsConciseGuideRules() throws {
        let tutorial = try String(contentsOf: projectURL("BuySellAI/Features/Tutorial/HowItWorksView.swift"), encoding: .utf8)

        XCTAssertNotNil(tutorial.range(of: #"Text("Snap · Pick · Sell".localized)"#))
        XCTAssertNotNil(tutorial.range(of: #"Text("Sell anything in three taps.".localized)"#))
        XCTAssertNotNil(tutorial.range(of: #"Text("Take a photo. We suggest where to sell and write the listing.".localized)"#))
        XCTAssertNotNil(tutorial.range(of: #"title: "Take a clear photo""#))
        XCTAssertNotNil(tutorial.range(of: #"detail: "Fit the whole item in the frame.""#))
        XCTAssertNotNil(tutorial.range(of: #"title: "Choose where to sell""#))
        XCTAssertNotNil(tutorial.range(of: #"detail: "We suggest the best place first.""#))
        XCTAssertNotNil(tutorial.range(of: #"title: "Copy the listing""#))
        XCTAssertNotNil(tutorial.range(of: #"detail: "Paste it into the marketplace when you are ready.""#))
        XCTAssertNotNil(tutorial.range(of: #"Text("Start selling".localized)"#))
        XCTAssertEqual(tutorial.components(separatedBy: "TutorialStep(").count - 1, 3)
        XCTAssertNil(tutorial.range(of: "TutorialSlide("))
        XCTAssertNil(tutorial.range(of: "Welcome to BuySell."))
        XCTAssertNil(tutorial.range(of: "Turn stuff into cash in three taps."))
        XCTAssertNil(tutorial.range(of: "Just paste it in."))
        XCTAssertNil(tutorial.range(of: "Simply paste it in."))
    }

    func testTutorialKeepsSinglePrimaryActionWithoutPagerNavigation() throws {
        let tutorial = try String(contentsOf: projectURL("BuySellAI/Features/Tutorial/HowItWorksView.swift"), encoding: .utf8)

        XCTAssertNotNil(tutorial.range(of: #"TextActionButton(title: "Skip", minWidth: 64)"#))
        XCTAssertNotNil(tutorial.range(of: #"Text("Start selling".localized)"#))
        XCTAssertNotNil(tutorial.range(of: #".buttonStyle(.borderedProminent)"#))
        XCTAssertNotNil(tutorial.range(of: #".accessibilityLabel("Start selling".localized)"#))
        XCTAssertNil(tutorial.range(of: #""Next""#))
        XCTAssertNil(tutorial.range(of: #""Get started""#))
        XCTAssertNil(tutorial.range(of: "Step %d"))
        XCTAssertNil(tutorial.range(of: "Step %d of %d"))
        XCTAssertNil(tutorial.range(of: ".accessibilityAdjustableAction"))
        XCTAssertNil(tutorial.range(of: "TabView"))
    }

    func testTutorialKeyboardFocusAndFooterAdaptForAccessibilityDynamicType() throws {
        let tutorial = try String(contentsOf: projectURL("BuySellAI/Features/Tutorial/HowItWorksView.swift"), encoding: .utf8)

        XCTAssertNotNil(tutorial.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(tutorial.range(of: #"@FocusState private var isKeyboardFocused: Bool"#))
        XCTAssertNotNil(tutorial.range(of: #".focused($isKeyboardFocused)"#))
        XCTAssertNotNil(tutorial.range(of: #".task {"#))
        XCTAssertNotNil(tutorial.range(of: #"isKeyboardFocused = true"#))
        XCTAssertNotNil(tutorial.range(of: #"private var footerControls: some View"#))
        XCTAssertNotNil(tutorial.range(of: #"dynamicTypeSize.isAccessibilitySize ? Spacing.lg : Spacing.xl"#))
        XCTAssertNotNil(tutorial.range(of: #"dynamicTypeSize.isAccessibilitySize ? 116 : 132"#))
        XCTAssertNotNil(tutorial.range(of: #"VStack(spacing: contentSpacing)"#))
        XCTAssertNotNil(tutorial.range(of: #".frame(minHeight: geometry.size.height, alignment: .top)"#))
        XCTAssertNil(tutorial.range(of: #".frame(minHeight: geometry.size.height, alignment: .center)"#))
        XCTAssertNotNil(tutorial.range(of: #".frame(maxWidth: .infinity, minHeight: 44)"#))
        XCTAssertNotNil(tutorial.range(of: #".buttonStyle(.borderedProminent)"#))
        XCTAssertNil(tutorial.range(of: #".buttonBorderShape(.capsule)"#))
        XCTAssertNotNil(tutorial.range(of: #".controlSize(.large)"#))
        XCTAssertNotNil(tutorial.range(of: #".accessibilityLabel("Start selling".localized)"#))
        XCTAssertNotNil(tutorial.range(of: #".onKeyPress(.space)"#))
        XCTAssertNotNil(tutorial.range(of: #".onKeyPress(.rightArrow)"#))
        XCTAssertNotNil(tutorial.range(of: #".onKeyPress(.leftArrow)"#))
    }

    func testTutorialUsesFullScreenControlsAndConciseGuideAction() throws {
        let tutorial = try String(contentsOf: projectURL("BuySellAI/Features/Tutorial/HowItWorksView.swift"), encoding: .utf8)

        XCTAssertNotNil(tutorial.range(of: #"private var headerControls: some View"#))
        XCTAssertNotNil(tutorial.range(of: #"private var footerControls: some View"#))
        XCTAssertNotNil(tutorial.range(of: #"TextActionButton(title: "Skip", minWidth: 64)"#))
        XCTAssertNotNil(tutorial.range(of: #"CompactGuideGraphic()"#))
        XCTAssertNotNil(tutorial.range(of: #"TutorialStepRow(step: step)"#))
        XCTAssertNotNil(tutorial.range(of: #".padding(.bottom, Spacing.lg)"#))
        XCTAssertNotNil(tutorial.range(of: #".frame(maxWidth: .infinity, minHeight: 44)"#))
        XCTAssertNil(tutorial.range(of: #"DotPager("#))
        XCTAssertNil(tutorial.range(of: #"private var nextButton: some View"#))
        XCTAssertNil(tutorial.range(of: #".toolbar {"#))
        XCTAssertNil(tutorial.range(of: #".safeAreaInset(edge: .bottom)"#))
        XCTAssertNil(tutorial.range(of: #".listStyle(.insetGrouped)"#))
    }

    func testTutorialAvoidsCarouselMotion() throws {
        let tutorial = try String(contentsOf: projectURL("BuySellAI/Features/Tutorial/HowItWorksView.swift"), encoding: .utf8)

        XCTAssertNil(tutorial.range(of: #"DragGesture("#))
        XCTAssertNil(tutorial.range(of: #".gesture("#))
        XCTAssertNil(tutorial.range(of: #".asymmetric("#))
        XCTAssertNil(tutorial.range(of: #".move(edge:"#))
        XCTAssertNil(tutorial.range(of: #".symbolEffect("#))
        XCTAssertNil(tutorial.range(of: #"TutorialSlidePage"#))
        XCTAssertNil(tutorial.range(of: #"DotPager"#))
        XCTAssertNotNil(tutorial.range(of: #".accessibilityElement(children: .contain)"#))
        XCTAssertGreaterThanOrEqual(tutorial.components(separatedBy: #".accessibilityElement(children: .contain)"#).count - 1, 2)
    }

    func testListingGeneratedTextRowMatchesPromptRequirements() throws {
        let listing = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)
        let panelRange = try XCTUnwrap(listing.range(of: "private var listingText: some View"))
        let errorRange = try XCTUnwrap(listing.range(of: "private func error", range: panelRange.upperBound..<listing.endIndex))
        let panelSource = String(listing[panelRange.lowerBound..<errorRange.lowerBound])
        let bottomRange = try XCTUnwrap(listing.range(of: "@ViewBuilder", range: errorRange.upperBound..<listing.endIndex))
        let errorSource = String(listing[errorRange.lowerBound..<bottomRange.lowerBound])

        XCTAssertNotNil(listing.range(of: #"Section("Generated listing text".localized) {"#))
        XCTAssertNotNil(panelSource.range(of: "Text(store.listingText)"))
        XCTAssertNotNil(panelSource.range(of: ".font(.body)"))
        XCTAssertNil(listing.range(of: #".brandFont("#))
        XCTAssertNotNil(panelSource.range(of: ".lineSpacing(4)"))
        XCTAssertNotNil(panelSource.range(of: ".textSelection(.enabled)"))
        XCTAssertNotNil(panelSource.range(of: ".padding(.vertical, Spacing.sm)"))
        XCTAssertNil(panelSource.range(of: ".nativeMaterialPanel("))
        XCTAssertNil(panelSource.range(of: ".background(Color.brand.secondary, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))"))
        XCTAssertNotNil(panelSource.range(of: #".accessibilityLabel("Generated listing text".localized)"#))
        XCTAssertNotNil(panelSource.range(of: #".accessibilityValue(store.listingText)"#))
        XCTAssertNotNil(errorSource.range(of: #".accessibilityIdentifier("Listing.ErrorMessage")"#))
        XCTAssertNotNil(errorSource.range(of: ".buttonStyle(.borderedProminent)"))
        XCTAssertNotNil(errorSource.range(of: ".buttonStyle(.bordered)"))
        XCTAssertNil(errorSource.range(of: ".buttonBorderShape(.capsule)"))
        XCTAssertNotNil(errorSource.range(of: #".task(id: message)"#))
        XCTAssertNotNil(errorSource.range(of: #"appStore.showToast(message, style: .error)"#))
        XCTAssertNil(listing.range(of: #".onChange(of: store.phase)"#))
    }

    func testListingStructuredDraftGuidanceUsesNativeTipRows() throws {
        let listing = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)
        let quickTipsRange = try XCTUnwrap(listing.range(of: #"Section("Quick tips".localized) {"#))
        let failedRange = try XCTUnwrap(listing.range(of: "case .failed(let message):", range: quickTipsRange.upperBound..<listing.endIndex))
        let quickTipsSource = String(listing[quickTipsRange.lowerBound..<failedRange.lowerBound])

        XCTAssertNotNil(quickTipsSource.range(of: #"marketplaceTipRow("#))
        XCTAssertNotNil(quickTipsSource.range(of: #"title: "Details to include""#))
        XCTAssertNotNil(quickTipsSource.range(of: #"systemImage: "list.bullet.rectangle""#))
        XCTAssertNotNil(quickTipsSource.range(of: #"detail: itemSpecifics"#))
        XCTAssertNotNil(quickTipsSource.range(of: #"if let itemSpecifics = joinedDraftValues(store.draft?.itemSpecifics)"#))
        XCTAssertNotNil(quickTipsSource.range(of: #"title: "When posting""#))
        XCTAssertNotNil(quickTipsSource.range(of: #"systemImage: "checklist""#))
        XCTAssertNotNil(quickTipsSource.range(of: #"detail: postingNotes"#))
        XCTAssertNotNil(quickTipsSource.range(of: #"if let postingNotes = joinedDraftValues(store.draft?.postingNotes)"#))
        XCTAssertNotNil(quickTipsSource.range(of: #"title: "Tags""#))
        XCTAssertNotNil(quickTipsSource.range(of: #"systemImage: "tag""#))
        XCTAssertNotNil(quickTipsSource.range(of: #"detail: tags"#))
        XCTAssertNotNil(quickTipsSource.range(of: #"if let tags = joinedDraftValues(store.draft?.tags)"#))
        XCTAssertNil(quickTipsSource.range(of: #"evidenceSummary"#))
        XCTAssertNotNil(listing.range(of: #"private func joinedDraftValues(_ values: [String]?) -> String?"#))
        XCTAssertNotNil(listing.range(of: #".map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }"#))
        XCTAssertNotNil(listing.range(of: #".filter { $0.isEmpty == false }"#))
        XCTAssertNotNil(listing.range(of: #"return cleanValues.joined(separator: ", ")"#))
    }

    func testListingKeepsResearchEvidenceInCompactNativeDisclosure() throws {
        let listing = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)
        let evidenceRange = try XCTUnwrap(listing.range(of: #"private var evidenceDisclosure: some View"#))
        let listingTextRange = try XCTUnwrap(listing.range(of: #"private var listingText: some View"#, range: evidenceRange.upperBound..<listing.endIndex))
        let evidenceSource = String(listing[evidenceRange.lowerBound..<listingTextRange.lowerBound])

        XCTAssertNotNil(listing.range(of: #"@State private var isEvidenceExpanded = false"#))
        XCTAssertNotNil(listing.range(of: #"Section {"#))
        XCTAssertNotNil(listing.range(of: #"evidenceDisclosure"#))
        XCTAssertNotNil(evidenceSource.range(of: #"DisclosureGroup(isExpanded: $isEvidenceExpanded)"#))
        XCTAssertNotNil(evidenceSource.range(of: #"Label("Evidence".localized, systemImage: "checkmark.shield")"#))
        XCTAssertNotNil(evidenceSource.range(of: #".accessibilityIdentifier("Listing.EvidenceDisclosure")"#))
        XCTAssertNotNil(evidenceSource.range(of: #".accessibilityHint("Shows the checks behind this listing.".localized)"#))
        XCTAssertNotNil(evidenceSource.range(of: #"store.draft?.evidenceSummary"#))
        XCTAssertNotNil(evidenceSource.range(of: #"title: "Market check""#))
        XCTAssertNotNil(evidenceSource.range(of: #"if let compRangeText"#))
        XCTAssertNotNil(evidenceSource.range(of: #"title: "Sold range""#))
        XCTAssertNotNil(evidenceSource.range(of: #"if let evidenceSources = store.draft?.evidenceSources"#))
        XCTAssertNotNil(evidenceSource.range(of: #"ForEach(evidenceSources) { source in"#))
        XCTAssertNotNil(evidenceSource.range(of: #"evidenceSourceRow(source)"#))
        XCTAssertNotNil(evidenceSource.range(of: #"context.marketplace.playbookEvidence.feeModelSourceTitle"#))
        XCTAssertNotNil(evidenceSource.range(of: #"context.marketplace.playbookEvidence.feeModelLastChecked"#))
        XCTAssertNotNil(evidenceSource.range(of: #"context.marketplace.playbookEvidence.feeModelSummary"#))
        XCTAssertNotNil(evidenceSource.range(of: #"store.draft?.publicImageQuery"#))
        XCTAssertNotNil(evidenceSource.range(of: #"title: "Image search""#))
        XCTAssertNotNil(evidenceSource.range(of: #"referenceImageURL"#))
        XCTAssertNotNil(evidenceSource.range(of: #"title: "Reference only""#))
        XCTAssertNotNil(evidenceSource.range(of: #"Use this to check the item, not as a listing photo.".localized"#))
        XCTAssertNotNil(evidenceSource.range(of: #"evidenceLink(title: "Open reference image", systemImage: "safari", url: referenceImageURL)"#))
        XCTAssertNotNil(evidenceSource.range(of: #"evidenceLink(title: "Open fee source", systemImage: "safari", url: feeSourceURL)"#))
        XCTAssertNotNil(listing.range(of: #"private func evidenceDetailRow(title: String, systemImage: String, detail: String) -> some View"#))
        XCTAssertNotNil(listing.range(of: #"private func evidenceLink(title: String, systemImage: String, url: URL) -> some View"#))
        XCTAssertNotNil(listing.range(of: #"private func evidenceSourceRow(_ source: ListingEvidenceSource) -> some View"#))
        XCTAssertNotNil(listing.range(of: #"source.detailLine(currencyCode: context.item.currencyCode)"#))
        XCTAssertNotNil(listing.range(of: #"let sourceDetail = ["#))
        XCTAssertNotNil(listing.range(of: #"title: source.sourceMarketplace ?? "Source""#))
        XCTAssertNotNil(listing.range(of: #"detail: sourceDetail.isEmpty ? "Source details".localized : sourceDetail"#))
        XCTAssertNotNil(listing.range(of: #"evidenceLink(title: "Open source", systemImage: "safari", url: url)"#))
        XCTAssertNotNil(listing.range(of: #"private var compRangeText: String?"#))
        XCTAssertNotNil(listing.range(of: #"private var feeSourceURL: URL?"#))
        XCTAssertNotNil(listing.range(of: #"private var referenceImageURL: URL?"#))
    }

    func testListingLeadsWithGeneratedTextBeforeMarketplaceDetails() throws {
        let listing = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)
        let successRange = try XCTUnwrap(listing.range(of: "case .success:"))
        let listingTextRange = try XCTUnwrap(listing.range(of: #"Section("Generated listing text".localized) {"#, range: successRange.upperBound..<listing.endIndex))
        let recommendationRange = try XCTUnwrap(listing.range(of: "listingRecommendationSummary", range: listingTextRange.upperBound..<listing.endIndex))
        let priceRange = try XCTUnwrap(listing.range(of: #"Section("Price plan".localized) {"#, range: recommendationRange.upperBound..<listing.endIndex))

        XCTAssertLessThan(listingTextRange.lowerBound, recommendationRange.lowerBound)
        XCTAssertLessThan(recommendationRange.lowerBound, priceRange.lowerBound)
        XCTAssertNotNil(listing.range(of: #"private var listingRecommendationSummary: some View"#))
        XCTAssertNotNil(listing.range(of: #"Text(String.localizedFormat("Ready for %@", context.marketplace.displayName))"#))
        XCTAssertNotNil(listing.range(of: #"Label(recommendationLabel.localized, systemImage: "checkmark.seal")"#))
        XCTAssertNotNil(listing.range(of: #"Text(recommendationReason)"#))
        XCTAssertNotNil(listing.range(of: #"Text("Take-home".localized)"#))
        XCTAssertNotNil(listing.range(of: #"pricePlan.takeHomeEstimate.currency(code: context.item.currencyCode)"#))
        XCTAssertNotNil(listing.range(of: #"private var selectedRecommendationKind: MarketplaceSummaryKind"#))
        XCTAssertNotNil(listing.range(of: #"MarketplaceSummaryPlanner"#))
        XCTAssertNotNil(listing.range(of: #"MarketplaceEstimator.estimates(for: context.item, details: context.details)"#))
        XCTAssertNotNil(listing.range(of: #"case .mostMoney:"#))
        XCTAssertNotNil(listing.range(of: #""Most money""#))
        XCTAssertNotNil(listing.range(of: #""Fastest sale""#))
        XCTAssertNotNil(listing.range(of: #""Easiest option""#))
        XCTAssertNotNil(listing.range(of: #"context.marketplace.recommendationReason(for: context.item)"#))
        XCTAssertNotNil(listing.range(of: #".accessibilityIdentifier("Listing.RecommendationSummary")"#))
        XCTAssertNotNil(listing.range(of: #".accessibilityValue(String.localizedFormat("%@, %@", "Take-home estimate".localized, pricePlan.takeHomeEstimate.currency(code: context.item.currencyCode)))"#))
    }

    func testListingUsesNativeNavigationListAndToolbarClose() throws {
        let listing = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(listing.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(listing.range(of: #"NavigationStack {"#))
        XCTAssertNotNil(listing.range(of: #"List {"#))
        XCTAssertNotNil(listing.range(of: #".listStyle(.insetGrouped)"#))
        XCTAssertNotNil(listing.range(of: #".navigationTitle("Ready to copy".localized)"#))
        XCTAssertNotNil(listing.range(of: #".navigationBarTitleDisplayMode(.inline)"#))
        XCTAssertNotNil(listing.range(of: #"ToolbarItem(placement: .topBarTrailing) {"#))
        XCTAssertNotNil(listing.range(of: #"private var header: some View"#))
        XCTAssertNotNil(listing.range(of: #"HStack(alignment: .center, spacing: Spacing.md)"#))
        XCTAssertNotNil(listing.range(of: #"private var headerTitle: some View"#))
        XCTAssertNotNil(listing.range(of: #"private var closeListingButton: some View"#))
        XCTAssertNotNil(listing.range(of: #"Label("Close listing".localized, systemImage: "xmark")"#))
        XCTAssertNotNil(listing.range(of: #".labelStyle(.iconOnly)"#))
        XCTAssertNotNil(listing.range(of: #"Haptics.impact(.light)"#))
        XCTAssertNotNil(listing.range(of: #".lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)"#))
        XCTAssertNotNil(listing.range(of: #".fixedSize(horizontal: false, vertical: true)"#))
        XCTAssertNotNil(listing.range(of: #".accessibilityLabel("Close listing".localized)"#))
        XCTAssertNil(listing.range(of: #"private var regularHeader: some View"#))
        XCTAssertNil(listing.range(of: #"private var accessibilityHeader: some View"#))
    }

    func testListingSuccessActionsAreStickyAndOrderedAfterGenerationSucceeds() throws {
        let listing = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)
        let bottomRange = try XCTUnwrap(listing.range(of: "private var successBottomActions: some View"))
        let regenerateRange = try XCTUnwrap(listing.range(of: "private func regenerateListing", range: bottomRange.upperBound..<listing.endIndex))
        let bottomSource = String(listing[bottomRange.lowerBound..<regenerateRange.lowerBound])

        XCTAssertNotNil(listing.range(of: ".safeAreaInset(edge: .bottom)"))
        XCTAssertNotNil(listing.range(of: "case .success:\n            successBottomActions"))
        XCTAssertNotNil(listing.range(of: "case .idle, .loading, .failed:\n            EmptyView()"))
        XCTAssertNotNil(bottomSource.range(of: ".background(.bar)"))
        XCTAssertNotNil(listing.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(listing.range(of: #".contentMargins(.bottom, bottomContentInset, for: .scrollContent)"#))
        XCTAssertNotNil(listing.range(of: #"if dynamicTypeSize.isAccessibilitySize"#))
        XCTAssertNotNil(listing.range(of: #"private var bottomContentInset: CGFloat"#))
        XCTAssertNotNil(listing.range(of: #"dynamicTypeSize.isAccessibilitySize ? 300 : 216"#))
        XCTAssertNotNil(bottomSource.range(of: ".buttonStyle(.borderedProminent)"))
        XCTAssertNotNil(bottomSource.range(of: ".buttonStyle(.bordered)"))
        XCTAssertNil(bottomSource.range(of: ".buttonBorderShape(.capsule)"))
        XCTAssertNotNil(bottomSource.range(of: ".controlSize(.large)"))

        let copyRange = try XCTUnwrap(bottomSource.range(of: #"Label("Copy listing".localized, systemImage: "doc.on.doc.fill")"#))
        let marketplaceRange = try XCTUnwrap(bottomSource.range(of: #"secondaryActionButton(title: "Try another marketplace", systemImage: "arrow.left.arrow.right")"#))
        let retakeRange = try XCTUnwrap(bottomSource.range(of: #"secondaryActionButton(title: "Wrong item — retake", systemImage: "camera.rotate")"#))
        let regenerateButtonRange = try XCTUnwrap(bottomSource.range(of: #"secondaryActionButton(title: "Regenerate", systemImage: "arrow.clockwise")"#))
        let footerRange = try XCTUnwrap(bottomSource.range(of: #"Text("Tip: paste, add photos, hit list. That's it.".localized)"#))

        XCTAssertLessThan(copyRange.lowerBound, retakeRange.lowerBound)
        XCTAssertLessThan(copyRange.lowerBound, marketplaceRange.lowerBound)
        XCTAssertLessThan(marketplaceRange.lowerBound, retakeRange.lowerBound)
        XCTAssertLessThan(retakeRange.lowerBound, regenerateButtonRange.lowerBound)
        XCTAssertLessThan(regenerateButtonRange.lowerBound, footerRange.lowerBound)
        XCTAssertNotNil(listing.range(of: #"appStore.presentMarketplacePicker(item: context.item, imageData: context.imageData)"#))
    }

    func testListingClipboardTextIsContractValidatedBeforeCopying() throws {
        let listing = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)
        let copyRange = try XCTUnwrap(listing.range(of: "private var copyableListingText: String"))
        let statusRange = try XCTUnwrap(listing.range(of: "private func clipboardStatus", range: copyRange.upperBound..<listing.endIndex))
        let copySource = String(listing[copyRange.lowerBound..<statusRange.lowerBound])

        XCTAssertNotNil(copySource.range(of: "ListingTextContract.validatedGenerated(store.listingText)"))
        XCTAssertNil(copySource.range(of: "store.listingText.trimmingCharacters"))
        XCTAssertNil(copySource.range(of: "store.draft?.itemSpecifics"))
        XCTAssertNil(copySource.range(of: "store.draft?.postingNotes"))
        XCTAssertNil(copySource.range(of: "store.draft?.tags"))
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

    private func nearbySource(lines: [String], index: Int, radius: Int) -> String {
        let start = max(0, index - radius)
        let end = min(lines.count - 1, index + radius)
        return lines[start...end].joined(separator: "\n")
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

    private enum ColorAppearance: String, CaseIterable, CustomStringConvertible {
        case light
        case dark

        var description: String { rawValue }
    }

    private struct RGB {
        let red: Double
        let green: Double
        let blue: Double
    }

    private struct Pixel {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8
    }

    private enum TestImageError: Error {
        case invalidPNG
        case invalidBitmapContext
        case invalidPixelCoordinate
    }

    private func pngUInt32(_ data: Data, offset: Int) throws -> UInt32 {
        guard data.count >= offset + 4 else {
            throw TestImageError.invalidPNG
        }

        return data[offset..<(offset + 4)].reduce(UInt32(0)) { value, byte in
            (value << 8) | UInt32(byte)
        }
    }

    private func renderedPixels(from image: CGImage) throws -> [UInt8] {
        let bytesPerPixel = 4
        let bytesPerRow = image.width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: image.height * bytesPerRow)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let didRender = pixels.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard
                let baseAddress = rawBuffer.baseAddress,
                let context = CGContext(
                    data: baseAddress,
                    width: image.width,
                    height: image.height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: bitmapInfo
                )
            else {
                return false
            }

            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }

        guard didRender else {
            throw TestImageError.invalidBitmapContext
        }
        return pixels
    }

    private func pixel(in pixels: [UInt8], image: CGImage, x: Int, y: Int) throws -> Pixel {
        guard x >= 0, x < image.width, y >= 0, y < image.height else {
            throw TestImageError.invalidPixelCoordinate
        }

        let offset = ((y * image.width) + x) * 4
        guard offset + 3 < pixels.count else {
            throw TestImageError.invalidPixelCoordinate
        }

        return Pixel(
            red: pixels[offset],
            green: pixels[offset + 1],
            blue: pixels[offset + 2],
            alpha: pixels[offset + 3]
        )
    }

    private func isWarmBrandOrange(_ pixel: Pixel) -> Bool {
        pixel.alpha >= 250 &&
            pixel.red >= 230 &&
            (110...210).contains(pixel.green) &&
            (35...155).contains(pixel.blue) &&
            pixel.red > pixel.green + 45 &&
            pixel.green > pixel.blue + 25
    }

    private func isCameraWhite(_ pixel: Pixel) -> Bool {
        pixel.alpha >= 250 &&
            pixel.red >= 245 &&
            pixel.green >= 245 &&
            pixel.blue >= 245
    }

    private func colorAsset(_ name: String, appearance: ColorAppearance) throws -> RGB {
        let assetURL = projectURL("BuySellAI/Resources/Assets.xcassets/\(name).colorset/Contents.json")
        let data = try Data(contentsOf: assetURL)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let colors = try XCTUnwrap(json["colors"] as? [[String: Any]])
        let entry = try XCTUnwrap(
            colors.first { colorEntry($0, matches: appearance) },
            "\(name) should include a \(appearance.description) appearance."
        )
        let color = try XCTUnwrap(entry["color"] as? [String: Any])
        let components = try XCTUnwrap(color["components"] as? [String: Any])

        return RGB(
            red: try colorComponent("red", in: components),
            green: try colorComponent("green", in: components),
            blue: try colorComponent("blue", in: components)
        )
    }

    private func colorEntry(_ entry: [String: Any], matches appearance: ColorAppearance) -> Bool {
        let appearances = entry["appearances"] as? [[String: String]] ?? []
        let isDark = appearances.contains { current in
            current["appearance"] == "luminosity" && current["value"] == "dark"
        }

        switch appearance {
        case .light:
            return isDark == false
        case .dark:
            return isDark
        }
    }

    private func colorComponent(_ name: String, in components: [String: Any]) throws -> Double {
        let rawValue = try XCTUnwrap(components[name] as? String)
        return try XCTUnwrap(Double(rawValue))
    }

    private func contrastRatio(_ foreground: RGB, _ background: RGB) -> Double {
        let foregroundLuminance = relativeLuminance(foreground)
        let backgroundLuminance = relativeLuminance(background)
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)

        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: RGB) -> Double {
        0.2126 * linearized(color.red) +
            0.7152 * linearized(color.green) +
            0.0722 * linearized(color.blue)
    }

    private func linearized(_ component: Double) -> Double {
        component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
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
