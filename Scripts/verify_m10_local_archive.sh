#!/usr/bin/env bash
set -euo pipefail

archive_path="${1:-/tmp/BuySellAI-nosign.xcarchive}"
max_app_size_kb="${MAX_APP_SIZE_KB:-20480}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
app_path="${archive_path}/Products/Applications/BuySellAI.app"
info_plist="${app_path}/Info.plist"
privacy_manifest="${app_path}/PrivacyInfo.xcprivacy"
app_icon_contents="${repo_root}/BuySellAI/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json"
app_icon_source="${repo_root}/BuySellAI/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
iphone_icon="${app_path}/AppIcon60x60@2x.png"
ipad_icon="${app_path}/AppIcon76x76@2x~ipad.png"
plist_buddy="/usr/libexec/PlistBuddy"

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

plist_value() {
    "${plist_buddy}" -c "Print :$1" "$2"
}

plist_key_exists() {
    "${plist_buddy}" -c "Print :$1" "$2" >/dev/null 2>&1
}

plist_raw_value() {
    plutil -extract "$1" raw -o - "$2"
}

sips_property() {
    local file="$1"
    local property="$2"

    sips -g "$property" "$file" 2>/dev/null | awk -v key="${property}:" '$1 == key { print $2; exit }'
}

require_png_dimensions() {
    local file="$1"
    local expected_width="$2"
    local expected_height="$3"
    local label="$4"
    local format
    local width
    local height
    local has_alpha

    [[ -f "$file" ]] || fail "missing $label at $file"
    format="$(sips_property "$file" format)"
    width="$(sips_property "$file" pixelWidth)"
    height="$(sips_property "$file" pixelHeight)"
    has_alpha="$(sips_property "$file" hasAlpha)"

    [[ "$format" == "png" ]] || fail "$label must be a PNG"
    [[ "$width" == "$expected_width" ]] || fail "$label width is ${width}, expected ${expected_width}"
    [[ "$height" == "$expected_height" ]] || fail "$label height is ${height}, expected ${expected_height}"
    [[ "$has_alpha" == "no" ]] || fail "$label must not include an alpha channel"
}

require_privacy_manifest_values() {
    local manifest="$1"
    local data_count
    local accessed_count
    local tracking_domains_count
    local data_type
    local linked
    local tracking
    local purpose_count
    local purpose
    local expected_data_types

    [[ "$(plist_raw_value NSPrivacyTracking "$manifest")" == "false" ]] || fail "privacy manifest must declare NSPrivacyTracking=false"

    tracking_domains_count="$(plist_raw_value NSPrivacyTrackingDomains "$manifest")"
    [[ "$tracking_domains_count" == "0" ]] || fail "privacy manifest must not declare tracking domains"

    data_count="$(plist_raw_value NSPrivacyCollectedDataTypes "$manifest")"
    [[ "$data_count" == "4" ]] || fail "privacy manifest must declare exactly 4 collected data types"

    expected_data_types=(
        "NSPrivacyCollectedDataTypeEmailAddress"
        "NSPrivacyCollectedDataTypeUserID"
        "NSPrivacyCollectedDataTypePhotosorVideos"
        "NSPrivacyCollectedDataTypeOtherUserContent"
    )

    for index in "${!expected_data_types[@]}"; do
        data_type="$(plist_value "NSPrivacyCollectedDataTypes:${index}:NSPrivacyCollectedDataType" "$manifest")"
        linked="$(plist_raw_value "NSPrivacyCollectedDataTypes.${index}.NSPrivacyCollectedDataTypeLinked" "$manifest")"
        tracking="$(plist_raw_value "NSPrivacyCollectedDataTypes.${index}.NSPrivacyCollectedDataTypeTracking" "$manifest")"
        purpose_count="$(plist_raw_value "NSPrivacyCollectedDataTypes.${index}.NSPrivacyCollectedDataTypePurposes" "$manifest")"
        purpose="$(plist_value "NSPrivacyCollectedDataTypes:${index}:NSPrivacyCollectedDataTypePurposes:0" "$manifest")"

        [[ "$data_type" == "${expected_data_types[$index]}" ]] || fail "privacy manifest collected data type $index is '$data_type'"
        [[ "$linked" == "true" ]] || fail "privacy manifest collected data type $index must be linked to the user"
        [[ "$tracking" == "false" ]] || fail "privacy manifest collected data type $index must not be used for tracking"
        [[ "$purpose_count" == "1" ]] || fail "privacy manifest collected data type $index must declare exactly one purpose"
        [[ "$purpose" == "NSPrivacyCollectedDataTypePurposeAppFunctionality" ]] || fail "privacy manifest collected data type $index must be for app functionality"
    done

    accessed_count="$(plist_raw_value NSPrivacyAccessedAPITypes "$manifest")"
    [[ "$accessed_count" == "1" ]] || fail "privacy manifest must declare exactly one accessed API type"
    [[ "$(plist_value NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPIType "$manifest")" == "NSPrivacyAccessedAPICategoryUserDefaults" ]] || fail "privacy manifest accessed API must be UserDefaults"
    [[ "$(plist_raw_value NSPrivacyAccessedAPITypes.0.NSPrivacyAccessedAPITypeReasons "$manifest")" == "1" ]] || fail "privacy manifest UserDefaults reason must have exactly one value"
    [[ "$(plist_value NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:0 "$manifest")" == "CA92.1" ]] || fail "privacy manifest UserDefaults reason must be CA92.1"
}

rm -rf "$archive_path"

[[ -f "$app_icon_contents" ]] || fail "missing AppIcon Contents.json"
grep -Fq '"size" : "1024x1024"' "$app_icon_contents" || fail "AppIcon asset catalog must declare a 1024x1024 iOS icon"
grep -Fq '"filename" : "AppIcon-1024.png"' "$app_icon_contents" || fail "AppIcon asset catalog must reference AppIcon-1024.png"
require_png_dimensions "$app_icon_source" 1024 1024 "source App Store icon"

xcodebuild archive \
    -project "${repo_root}/BuySellAI.xcodeproj" \
    -scheme BuySellAI \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive_path" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY=""

[[ -d "$app_path" ]] || fail "missing archived app at $app_path"
[[ -x "${app_path}/BuySellAI" ]] || fail "missing archived executable"
[[ -f "$info_plist" ]] || fail "missing archived Info.plist"
[[ -f "$privacy_manifest" ]] || fail "missing PrivacyInfo.xcprivacy"
require_png_dimensions "$iphone_icon" 120 120 "archived iPhone app icon"
require_png_dimensions "$ipad_icon" 152 152 "archived iPad app icon"

plutil -lint "$info_plist" >/dev/null
plutil -lint "$privacy_manifest" >/dev/null
require_privacy_manifest_values "$privacy_manifest"

app_size_kb="$(du -sk "$app_path" | awk '{print $1}')"
[[ "$app_size_kb" -le "$max_app_size_kb" ]] || fail "app bundle is ${app_size_kb}KB, above ${max_app_size_kb}KB"

bundle_id="$(plist_value CFBundleIdentifier "$info_plist")"
[[ "$bundle_id" == "com.rhodes.buysellai" ]] || fail "unexpected bundle identifier"
release_version="$(plist_value CFBundleShortVersionString "$info_plist")"
release_build="$(plist_value CFBundleVersion "$info_plist")"
[[ -n "$release_version" ]] || fail "archived Info.plist is missing CFBundleShortVersionString"
[[ -n "$release_build" ]] || fail "archived Info.plist is missing CFBundleVersion"
[[ "$(plist_value NSCameraUsageDescription "$info_plist")" == "BuySell uses your camera to snap photos of items you want to sell." ]] || fail "camera usage description mismatch"
[[ "$(plist_value ITSAppUsesNonExemptEncryption "$info_plist")" == "false" ]] || fail "non-exempt encryption must be false"
[[ "$(plist_value CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName "$info_plist")" == "AppIcon" ]] || fail "iPhone primary icon name must be AppIcon"
[[ "$(plist_value CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles:0 "$info_plist")" == "AppIcon60x60" ]] || fail "iPhone primary icon file must include AppIcon60x60"
[[ "$(plist_value CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconName "$info_plist")" == "AppIcon" ]] || fail "iPad primary icon name must be AppIcon"
[[ "$(plist_value CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconFiles:0 "$info_plist")" == "AppIcon60x60" ]] || fail "iPad primary icon files must include AppIcon60x60"
[[ "$(plist_value CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconFiles:1 "$info_plist")" == "AppIcon76x76" ]] || fail "iPad primary icon files must include AppIcon76x76"

if plist_key_exists NSPhotoLibraryUsageDescription "$info_plist"; then
    fail "camera-only build should not request photo-library read permission"
fi

if plist_key_exists NSPhotoLibraryAddUsageDescription "$info_plist"; then
    fail "camera-only build should not request photo-library add permission"
fi

printf 'M10 local archive check passed\n'
printf 'archive: %s\n' "$archive_path"
printf 'bundle id: %s\n' "$bundle_id"
printf 'release build: %s (%s)\n' "$release_version" "$release_build"
printf 'app icon: AppIcon 1024x1024 source, 120x120 iPhone, 152x152 iPad\n'
printf 'app size: %sKB / %sKB\n' "$app_size_kb" "$max_app_size_kb"
