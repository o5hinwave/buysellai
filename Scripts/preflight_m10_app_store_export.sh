#!/usr/bin/env bash
set -euo pipefail

archive_path="${1:-/tmp/BuySellAI-appstore.xcarchive}"
export_path="${2:-/tmp/BuySellAI-appstore-export}"
allow_missing_team="${ALLOW_MISSING_TEAM:-0}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
project_path="${repo_root}/BuySellAI.xcodeproj"
entitlements_path="${repo_root}/BuySellAI/BuySellAI.entitlements"
app_path="${archive_path}/Products/Applications/BuySellAI.app"
info_plist="${app_path}/Info.plist"
privacy_manifest="${app_path}/PrivacyInfo.xcprivacy"
signed_entitlements="$(mktemp "${TMPDIR:-/tmp}/buysell-appstore-entitlements.XXXXXX")"
export_options="$(mktemp "${TMPDIR:-/tmp}/buysell-appstore-export-options.XXXXXX")"
plist_buddy="/usr/libexec/PlistBuddy"

cleanup() {
    rm -f "$signed_entitlements" "$export_options"
}
trap cleanup EXIT

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

setting() {
    awk -F' = ' -v key="$1" '
        $1 ~ "^[[:space:]]*" key "$" {
            value = $2
            sub(/;$/, "", value)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            print value
            exit
        }
    ' <<< "$build_settings"
}

plist_array_value() {
    "${plist_buddy}" -c "Print :$1:$2" "$3"
}

plist_value() {
    "${plist_buddy}" -c "Print :$1" "$2"
}

build_settings="$(
    xcodebuild -showBuildSettings \
        -project "$project_path" \
        -scheme BuySellAI \
        -configuration Release \
        2>/dev/null
)"

[[ "$(setting PRODUCT_BUNDLE_IDENTIFIER)" == "com.rhodes.buysellai" ]] || fail "unexpected Release bundle identifier"
[[ "$(setting CODE_SIGN_STYLE)" == "Automatic" ]] || fail "Release signing style must be Automatic"
[[ "$(setting CODE_SIGN_ENTITLEMENTS)" == "BuySellAI/BuySellAI.entitlements" ]] || fail "Release build must use BuySellAI.entitlements"
[[ -f "$entitlements_path" ]] || fail "missing BuySellAI.entitlements"
[[ "$(plist_array_value com.apple.developer.applesignin 0 "$entitlements_path")" == "Default" ]] || fail "Sign in with Apple entitlement is missing from source entitlements"

development_team="$(setting DEVELOPMENT_TEAM)"
if [[ -z "$development_team" ]]; then
    if [[ "$allow_missing_team" == "1" ]]; then
        printf 'M10 App Store export preflight pending: DEVELOPMENT_TEAM is unset\n'
        printf 'Set an Apple development team, then rerun without ALLOW_MISSING_TEAM=1 to export the App Store Connect IPA.\n'
        exit 0
    fi
    fail "DEVELOPMENT_TEAM is unset. Select an Apple development team before exporting the App Store Connect IPA."
fi

cat > "$export_options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>${development_team}</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "$export_options" >/dev/null

rm -rf "$archive_path" "$export_path"

xcodebuild archive \
    -project "$project_path" \
    -scheme BuySellAI \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive_path" \
    -allowProvisioningUpdates

[[ -d "$app_path" ]] || fail "missing archived app at $app_path"
[[ -x "${app_path}/BuySellAI" ]] || fail "missing archived executable"
[[ -f "$info_plist" ]] || fail "missing archived Info.plist"
[[ -f "$privacy_manifest" ]] || fail "missing PrivacyInfo.xcprivacy"

plutil -lint "$info_plist" >/dev/null
plutil -lint "$privacy_manifest" >/dev/null

release_version="$(plist_value CFBundleShortVersionString "$info_plist")"
release_build="$(plist_value CFBundleVersion "$info_plist")"
[[ -n "$release_version" ]] || fail "archived Info.plist is missing CFBundleShortVersionString"
[[ -n "$release_build" ]] || fail "archived Info.plist is missing CFBundleVersion"

codesign -d --entitlements :- "$app_path" > "$signed_entitlements" 2>/dev/null
[[ "$(plist_array_value com.apple.developer.applesignin 0 "$signed_entitlements")" == "Default" ]] || fail "signed archive is missing Sign in with Apple entitlement"

xcodebuild -exportArchive \
    -archivePath "$archive_path" \
    -exportPath "$export_path" \
    -exportOptionsPlist "$export_options" \
    -allowProvisioningUpdates

ipa_path="$(find "$export_path" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
[[ -n "$ipa_path" ]] || fail "App Store export did not produce an IPA"

unzip -l "$ipa_path" 'Payload/BuySellAI.app/Info.plist' >/dev/null || fail "exported IPA is missing Info.plist"
unzip -l "$ipa_path" 'Payload/BuySellAI.app/PrivacyInfo.xcprivacy' >/dev/null || fail "exported IPA is missing PrivacyInfo.xcprivacy"
unzip -l "$ipa_path" 'Payload/BuySellAI.app/BuySellAI' >/dev/null || fail "exported IPA is missing app executable"

printf 'M10 App Store export preflight passed\n'
printf 'archive: %s\n' "$archive_path"
printf 'export: %s\n' "$export_path"
printf 'ipa: %s\n' "$ipa_path"
printf 'release build: %s (%s)\n' "$release_version" "$release_build"
