#!/usr/bin/env bash
set -euo pipefail

archive_path="${1:-/tmp/BuySellAI-nosign.xcarchive}"
max_app_size_kb="${MAX_APP_SIZE_KB:-20480}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
app_path="${archive_path}/Products/Applications/BuySellAI.app"
info_plist="${app_path}/Info.plist"
privacy_manifest="${app_path}/PrivacyInfo.xcprivacy"
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

rm -rf "$archive_path"

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

plutil -lint "$info_plist" >/dev/null
plutil -lint "$privacy_manifest" >/dev/null

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
printf 'app size: %sKB / %sKB\n' "$app_size_kb" "$max_app_size_kb"
