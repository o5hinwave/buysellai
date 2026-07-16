#!/usr/bin/env bash
set -euo pipefail

archive_path="${1:-/tmp/BuySellAI-signed.xcarchive}"
allow_missing_team="${ALLOW_MISSING_TEAM:-0}"
m10_development_team="${M10_DEVELOPMENT_TEAM:-}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
project_path="${repo_root}/BuySellAI.xcodeproj"
entitlements_path="${repo_root}/BuySellAI/BuySellAI.entitlements"
app_path="${archive_path}/Products/Applications/BuySellAI.app"
info_plist="${app_path}/Info.plist"
privacy_manifest="${app_path}/PrivacyInfo.xcprivacy"
signed_entitlements="$(mktemp "${TMPDIR:-/tmp}/buysell-signed-entitlements.XXXXXX")"
plist_buddy="/usr/libexec/PlistBuddy"

cleanup() {
    rm -f "$signed_entitlements"
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

plist_value() {
    "${plist_buddy}" -c "Print :$1" "$2"
}

plist_array_value() {
    "${plist_buddy}" -c "Print :$1:$2" "$3"
}

team_build_setting=""
if [[ -n "$m10_development_team" ]]; then
    team_build_setting="DEVELOPMENT_TEAM=${m10_development_team}"
fi

build_settings="$(
    xcodebuild -showBuildSettings \
        -project "$project_path" \
        -scheme BuySellAI \
        -configuration Release \
        ${team_build_setting:+"$team_build_setting"} \
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
        printf 'M10 signed archive preflight pending: DEVELOPMENT_TEAM is unset\n'
        printf 'Set M10_DEVELOPMENT_TEAM or select an Apple development team in Xcode, then rerun without ALLOW_MISSING_TEAM=1 to produce a signed archive.\n'
        exit 0
    fi
    fail "DEVELOPMENT_TEAM is unset. Set M10_DEVELOPMENT_TEAM or select an Apple development team before producing the signed archive."
fi

rm -rf "$archive_path"

xcodebuild archive \
    -project "$project_path" \
    -scheme BuySellAI \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive_path" \
    -allowProvisioningUpdates \
    ${team_build_setting:+"$team_build_setting"}

[[ -d "$app_path" ]] || fail "missing archived app at $app_path"
[[ -x "${app_path}/BuySellAI" ]] || fail "missing archived executable"
[[ -f "$info_plist" ]] || fail "missing archived Info.plist"
[[ -f "$privacy_manifest" ]] || fail "missing PrivacyInfo.xcprivacy"

plutil -lint "$info_plist" >/dev/null
plutil -lint "$privacy_manifest" >/dev/null

release_version="$(plist_value CFBundleShortVersionString "$info_plist")"
release_build="$(plist_value CFBundleVersion "$info_plist")"
bundle_id="$(plist_value CFBundleIdentifier "$info_plist")"
[[ "$bundle_id" == "com.rhodes.buysellai" ]] || fail "unexpected archived bundle identifier"
[[ -n "$release_version" ]] || fail "archived Info.plist is missing CFBundleShortVersionString"
[[ -n "$release_build" ]] || fail "archived Info.plist is missing CFBundleVersion"

codesign -d --entitlements :- "$app_path" > "$signed_entitlements" 2>/dev/null || fail "could not read signed archive entitlements"
signed_sign_in_with_apple="$(plist_array_value com.apple.developer.applesignin 0 "$signed_entitlements" || true)"
[[ "$signed_sign_in_with_apple" == "Default" ]] || fail "signed archive is missing Sign in with Apple entitlement"

printf 'M10 signed archive preflight passed\n'
printf 'archive: %s\n' "$archive_path"
printf 'bundle id: %s\n' "$bundle_id"
printf 'sign in with apple: %s\n' "$signed_sign_in_with_apple"
printf 'release build: %s (%s)\n' "$release_version" "$release_build"
