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
require_source_marker "fallbackPresentation"
require_source_marker "NativeLiquidGlassControlGroupModifier"
require_source_marker "nativeLiquidGlassControlGroup"
require_source_marker "LiquidGlassSurfaceGroup(spacing: spacing)"
require_source_marker "NativePrimaryButtonBackgroundModifier"
require_source_marker "nativePrimaryButtonBackground"
require_source_marker "content.background(Color.brand.primary, in: Capsule())"
require_source_marker "NativeStandardButtonBackgroundModifier"
require_source_marker "NativeRoundedButtonBackgroundModifier"
require_source_marker "NativeIconButtonBackgroundModifier"
require_source_marker "nativeStandardButtonBackground"
require_source_marker "nativeRoundedButtonBackground"
require_source_marker "nativeIconButtonBackground"
require_source_marker ".fill(.ultraThinMaterial)"
require_source_marker ".fill(.regularMaterial)"
require_source_marker "accessibilityReduceTransparency"
require_buttons_marker ".nativePrimaryButtonBackground()"
require_buttons_marker ".tint(Color.brand.primary)"
require_buttons_marker ".nativeGlassButtonStyle(.prominent)"
require_buttons_marker ".nativeStandardButtonBackground(tintOpacity: 0.7, strokeOpacity: 0.64)"
require_buttons_marker ".nativeStandardButtonBackground(tintOpacity: 0.64, strokeOpacity: 0.84)"
require_buttons_marker ".nativeIconButtonBackground("
require_chips_marker ".nativeRoundedButtonBackground("
require_chips_marker ".nativeGlassButtonStyle(.standard)"
require_home_marker ".listStyle(.insetGrouped)"
require_home_marker "SnapActionRow()"
require_home_marker ".toolbar {"
require_home_marker '.navigationTitle("BuySell".localized)'
require_camera_marker ".nativeLiquidGlassControlGroup(spacing: Spacing.md)"
require_camera_marker "CameraPreview(session: controller.session) { tap in"
require_camera_marker "handleFocusTap(tap)"
require_camera_marker "CameraFocusRing()"
require_camera_marker 'systemImage: "arrow.triangle.2.circlepath.camera"'
require_camera_marker "cameraCapabilities.canSwitchCamera"
require_auth_marker ".listStyle(.insetGrouped)"
require_auth_marker "NavigationLink(value: AuthRoute.email)"
require_auth_marker ".buttonStyle(.borderedProminent)"
require_auth_marker ".background(.bar)"
require_snap_result_marker "private func categoryMenuItemIcon(for category: Category) -> String"
require_snap_result_marker "private func conditionMenuItemIcon(for condition: Condition) -> String"
require_snap_result_marker "systemImage: categoryMenuItemIcon(for: category)"
require_snap_result_marker "systemImage: conditionMenuItemIcon(for: condition)"
require_snap_result_marker 'Image(systemName: isSelected ? "checkmark.circle.fill" : systemImage)'
require_tutorial_marker ".listStyle(.insetGrouped)"
require_tutorial_marker ".background(.bar)"
require_tutorial_marker ".buttonStyle(.borderedProminent)"

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
        printf 'primary button glass: iOS 26+ prominent glass with orange tint, capsule fallback\n'
        printf 'standard button glass: iOS 26+ standard glass with material fallbacks for secondary, ghost, chip, icon, and remaining custom controls\n'
        printf 'home setup: native inset grouped task list with toolbar account and settings actions\n'
        printf 'camera setup: native top controls, tap focus, camera switching, and capture controls preserve compiler-gated GlassEffectContainer on iOS 26+\n'
        printf 'auth setup: native inset grouped list, NavigationLink email push, and system bottom bars\n'
        printf 'tutorial setup: native inset grouped guide with a system bottom bar\n'
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
printf 'primary button glass: iOS 26+ prominent glass with orange tint, capsule fallback\n'
printf 'standard button glass: iOS 26+ standard glass with material fallbacks for secondary, ghost, chip, icon, and remaining custom controls\n'
printf 'home setup: native inset grouped task list with toolbar account and settings actions\n'
printf 'camera setup: native top controls, tap focus, camera switching, and capture controls preserve compiler-gated GlassEffectContainer on iOS 26+\n'
printf 'auth setup: native inset grouped list, NavigationLink email push, and system bottom bars\n'
printf 'tutorial setup: native inset grouped guide with a system bottom bar\n'
printf 'menu item icons: category and condition menus use SF Symbols with selected checkmarks\n'
printf 'system sheet background: iOS 26+ native Liquid Glass, regularMaterial fallback\n'
printf 'system design: current presentation, no UIDesignRequiresCompatibility\n'
