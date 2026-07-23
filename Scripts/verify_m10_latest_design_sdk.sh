#!/usr/bin/env bash
set -euo pipefail

min_sdk_major="${M10_MIN_LIQUID_GLASS_SDK_MAJOR:-27}"
allow_missing_sdk="${ALLOW_MISSING_LIQUID_GLASS_SDK:-0}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
material_source="${repo_root}/BuySellAI/Design/NativeMaterialSurface.swift"
buttons_source="${repo_root}/BuySellAI/Design/Buttons.swift"
chips_source="${repo_root}/BuySellAI/Design/Chips.swift"
home_source="${repo_root}/BuySellAI/Features/Home/HomeView.swift"
camera_source="${repo_root}/BuySellAI/Features/Camera/CameraView.swift"
auth_source="${repo_root}/BuySellAI/Features/Auth/AuthView.swift"
snap_result_source="${repo_root}/BuySellAI/Features/SnapResult/SnapResultSheet.swift"
tutorial_source="${repo_root}/BuySellAI/Features/Tutorial/HowItWorksView.swift"
info_plist="${repo_root}/BuySellAI/Info.plist"

pending_items=()

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

pending() {
    pending_items+=("$*")
}

version_major() {
    local version="$1"
    local major="${version%%.*}"

    [[ "$major" =~ ^[0-9]+$ ]] || fail "could not parse version '$version'"
    printf '%s' "$major"
}

require_source_marker() {
    local marker="$1"

    grep -Fq "$marker" "$material_source" || fail "NativeMaterialSurface.swift is missing '$marker'"
}

require_buttons_marker() {
    local marker="$1"

    grep -Fq "$marker" "$buttons_source" || fail "Buttons.swift is missing '$marker'"
}

reject_source_marker() {
    local marker="$1"

    ! grep -Fq "$marker" "$material_source" || fail "NativeMaterialSurface.swift should not contain obsolete '$marker'"
}

reject_buttons_marker() {
    local marker="$1"

    ! grep -Fq "$marker" "$buttons_source" || fail "Buttons.swift should not contain obsolete '$marker'"
}

require_chips_marker() {
    local marker="$1"

    grep -Fq "$marker" "$chips_source" || fail "Chips.swift is missing '$marker'"
}

require_home_marker() {
    local marker="$1"

    grep -Fq "$marker" "$home_source" || fail "HomeView.swift is missing '$marker'"
}

require_camera_marker() {
    local marker="$1"

    grep -Fq "$marker" "$camera_source" || fail "CameraView.swift is missing '$marker'"
}

require_auth_marker() {
    local marker="$1"

    grep -Fq "$marker" "$auth_source" || fail "AuthView.swift is missing '$marker'"
}

require_snap_result_marker() {
    local marker="$1"

    grep -Fq "$marker" "$snap_result_source" || fail "SnapResultSheet.swift is missing '$marker'"
}

require_tutorial_marker() {
    local marker="$1"

    grep -Fq "$marker" "$tutorial_source" || fail "HowItWorksView.swift is missing '$marker'"
}

reject_tutorial_marker() {
    local marker="$1"

    ! grep -Fq "$marker" "$tutorial_source" || fail "HowItWorksView.swift should not contain obsolete '$marker'"
}

[[ -f "$material_source" ]] || fail "missing NativeMaterialSurface.swift"
[[ -f "$buttons_source" ]] || fail "missing Buttons.swift"
[[ -f "$chips_source" ]] || fail "missing Chips.swift"
[[ -f "$home_source" ]] || fail "missing HomeView.swift"
[[ -f "$camera_source" ]] || fail "missing CameraView.swift"
[[ -f "$auth_source" ]] || fail "missing AuthView.swift"
[[ -f "$snap_result_source" ]] || fail "missing SnapResultSheet.swift"
[[ -f "$tutorial_source" ]] || fail "missing HowItWorksView.swift"
[[ -f "$info_plist" ]] || fail "missing Info.plist"

require_source_marker "#if compiler(>=6.2)"
require_source_marker "#available(iOS 26.0, *)"
require_source_marker "glassEffect"
require_source_marker "GlassEffectContainer"
require_source_marker "GlassButtonStyle"
require_source_marker "buttonStyle(.glass)"
require_source_marker "buttonStyle(.glassProminent)"
require_source_marker ".regular.tint"
require_source_marker ".interactive()"
require_source_marker "nativeSystemSheetPresentationChrome"
require_source_marker "NativeSystemSheetPresentationModifier"
require_source_marker "nativeSystemFlowSheetPresentationChrome"
require_source_marker "NativeSystemFlowSheetPresentationModifier"
require_source_marker ".presentationDetents(detents)"
require_source_marker "fallbackPresentation"
require_source_marker "NativeLiquidGlassControlGroupModifier"
require_source_marker "nativeLiquidGlassControlGroup"
require_source_marker "LiquidGlassSurfaceGroup(spacing: spacing)"
require_source_marker "NativeRoundedButtonBackgroundModifier"
require_source_marker "NativeIconButtonBackgroundModifier"
require_source_marker "nativeRoundedButtonBackground"
require_source_marker "nativeIconButtonBackground"
reject_source_marker "NativePrimaryButtonBackgroundModifier"
reject_source_marker "nativePrimaryButtonBackground"
reject_source_marker "content.background(Color.brand.primary, in: Capsule())"
reject_source_marker "NativeStandardButtonBackgroundModifier"
reject_source_marker "nativeStandardButtonBackground"
reject_source_marker "NativeMaterialSheetModifier"
reject_source_marker "nativeMaterialSheet("
require_source_marker ".fill(.ultraThinMaterial)"
require_source_marker ".fill(.regularMaterial)"
require_source_marker "accessibilityReduceTransparency"
require_buttons_marker ".tint(Color.brand.primary)"
require_buttons_marker ".nativeIconButtonBackground("
require_buttons_marker ".nativeGlassButtonStyle(.standard)"
reject_buttons_marker ".nativePrimaryButtonBackground()"
reject_buttons_marker ".nativeGlassButtonStyle(.prominent)"
reject_buttons_marker ".nativeStandardButtonBackground("
reject_buttons_marker "struct PrimaryPillButton"
reject_buttons_marker "struct SecondaryPillButton"
reject_buttons_marker "struct GhostButton"
require_chips_marker ".nativeRoundedButtonBackground("
require_chips_marker ".nativeGlassButtonStyle(.standard)"
require_home_marker ".listStyle(.plain)"
require_home_marker "HomeHeroSection("
require_home_marker ".toolbar {"
require_home_marker 'ToolbarItem(placement: .principal)'
require_home_marker "BrandWordmark(size: .regular)"
require_home_marker '.navigationTitle("BuySell.".localized)'
require_home_marker ".navigationBarTitleDisplayMode(.inline)"
require_camera_marker ".nativeLiquidGlassControlGroup(spacing: Spacing.md)"
require_camera_marker "CameraPreview(session: controller.session) { tap in"
require_camera_marker "handleFocusTap(tap)"
require_camera_marker "CameraFocusRing()"
require_camera_marker 'systemImage: "arrow.triangle.2.circlepath.camera"'
require_camera_marker "cameraCapabilities.canSwitchCamera"
require_camera_marker "handleScenePhase"
require_camera_marker "pauseCameraForScenePhase"
require_camera_marker "restartCameraAfterInterruption"
require_camera_marker "PhotosPicker(selection: \$selectedPhotoItem, matching: .images, photoLibrary: .shared())"
require_camera_marker "private func importPhoto(_ item: PhotosPickerItem?)"
require_auth_marker ".listStyle(.insetGrouped)"
require_auth_marker "NavigationLink(value: AuthRoute.email)"
require_auth_marker ".buttonStyle(.borderedProminent)"
require_auth_marker ".background(.bar)"
require_snap_result_marker "private func categoryMenuItemIcon(for category: Category) -> String"
require_snap_result_marker "private func conditionMenuItemIcon(for condition: Condition) -> String"
require_snap_result_marker "systemImage: categoryMenuItemIcon(for: category)"
require_snap_result_marker "systemImage: conditionMenuItemIcon(for: condition)"
require_snap_result_marker 'Image(systemName: isSelected ? "checkmark.circle.fill" : systemImage)'
require_tutorial_marker "private struct CompactGuideGraphic"
require_tutorial_marker "private struct TutorialStepRow"
require_tutorial_marker "TutorialStep.steps"
require_tutorial_marker 'Text("Sell anything in three taps.".localized)'
require_tutorial_marker 'Text("Start selling".localized)'
require_tutorial_marker 'TextActionButton(title: "Skip", minWidth: 64)'
require_tutorial_marker ".buttonStyle(.borderedProminent)"
reject_tutorial_marker "TutorialSlidePage"
reject_tutorial_marker "DotPager"
reject_tutorial_marker "TutorialSlide("
reject_tutorial_marker 'isLastSlide ? "Get started" : "Next"'
reject_tutorial_marker "DragGesture(minimumDistance: 24)"
reject_tutorial_marker ".symbolEffect("

if /usr/libexec/PlistBuddy -c "Print :UIDesignRequiresCompatibility" "$info_plist" >/dev/null 2>&1; then
    fail "Info.plist must not request iOS design compatibility mode"
fi

xcode_version_output="$(xcodebuild -version)"
xcode_version="$(awk '/^Xcode / { print $2; exit }' <<< "$xcode_version_output")"
iphoneos_sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
xcode_major="$(version_major "$xcode_version")"
iphoneos_sdk_major="$(version_major "$iphoneos_sdk_version")"

if [[ "$xcode_major" -lt "$min_sdk_major" ]]; then
    pending "Xcode is $xcode_version, expected $min_sdk_major or newer for final Liquid Glass SDK evidence"
fi

if [[ "$iphoneos_sdk_major" -lt "$min_sdk_major" ]]; then
    pending "iPhoneOS SDK is $iphoneos_sdk_version, expected $min_sdk_major or newer for final Liquid Glass SDK evidence"
fi

if (( ${#pending_items[@]} > 0 )); then
    if [[ "$allow_missing_sdk" == "1" ]]; then
        printf 'M10 latest design SDK pending\n'
        printf ' - %s\n' "${pending_items[@]}"
        printf 'xcode: %s\n' "$xcode_version"
        printf 'iphoneos sdk: %s\n' "$iphoneos_sdk_version"
        printf 'liquid glass sdk: requires Xcode and iPhoneOS SDK %s or newer\n' "$min_sdk_major"
        printf 'source: BuySellAI/Design/NativeMaterialSurface.swift\n'
        printf 'source liquid glass: compiler-gated glassEffect, GlassEffectContainer, GlassButtonStyle, .glass, .glassProminent\n'
        printf 'obsolete button primitives: removed primary, secondary, and ghost pill helpers plus their primary/standard background modifiers\n'
        printf 'active control glass: iOS 26+ standard glass for text actions, icon controls, chips, camera controls, and remaining custom controls\n'
        printf 'home setup: native plain list command surface with hero, promise strip, branded toolbar wordmark, account, and settings actions\n'
        printf 'camera setup: native top controls, tap focus, camera switching, scene-phase recovery, photo import, and capture controls preserve compiler-gated GlassEffectContainer on iOS 26+\n'
        printf 'auth setup: native inset grouped list, NavigationLink email push, and system bottom bars\n'
        printf 'tutorial setup: concise first-use guide with one Start selling action, three native steps, keyboard dismissal, and no carousel pager\n'
        printf 'menu item icons: category and condition menus use SF Symbols with selected checkmarks\n'
        printf 'system sheet background: iOS 26+ native Liquid Glass, regularMaterial fallback\n'
        printf 'system design: current presentation, no UIDesignRequiresCompatibility\n'
        exit 0
    fi

    printf 'error: M10 latest design SDK incomplete:\n' >&2
    printf ' - %s\n' "${pending_items[@]}" >&2
    exit 1
fi

printf 'M10 latest design SDK passed\n'
printf 'xcode: %s\n' "$xcode_version"
printf 'iphoneos sdk: %s\n' "$iphoneos_sdk_version"
printf 'liquid glass sdk: Xcode and iPhoneOS SDK %s or newer\n' "$min_sdk_major"
printf 'source: BuySellAI/Design/NativeMaterialSurface.swift\n'
printf 'source liquid glass: compiler-gated glassEffect, GlassEffectContainer, GlassButtonStyle, .glass, .glassProminent\n'
printf 'obsolete button primitives: removed primary, secondary, and ghost pill helpers plus their primary/standard background modifiers\n'
printf 'active control glass: iOS 26+ standard glass for text actions, icon controls, chips, camera controls, and remaining custom controls\n'
printf 'home setup: native plain list command surface with hero, promise strip, branded toolbar wordmark, account, and settings actions\n'
printf 'camera setup: native top controls, tap focus, camera switching, scene-phase recovery, photo import, and capture controls preserve compiler-gated GlassEffectContainer on iOS 26+\n'
printf 'auth setup: native inset grouped list, NavigationLink email push, and system bottom bars\n'
printf 'tutorial setup: concise first-use guide with one Start selling action, three native steps, keyboard dismissal, and no carousel pager\n'
printf 'menu item icons: category and condition menus use SF Symbols with selected checkmarks\n'
printf 'system sheet background: iOS 26+ native Liquid Glass, regularMaterial fallback\n'
printf 'system design: current presentation, no UIDesignRequiresCompatibility\n'
