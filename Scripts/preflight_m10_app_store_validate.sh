#!/usr/bin/env bash
set -euo pipefail

artifact_path="${1:-/tmp/BuySellAI-appstore-export}"
allow_missing_asc="${ALLOW_MISSING_ASC:-0}"
api_key_id="${ASC_API_KEY_ID:-}"
api_issuer_id="${ASC_API_ISSUER_ID:-}"
private_keys_dir="${ASC_API_PRIVATE_KEYS_DIR:-${API_PRIVATE_KEYS_DIR:-}}"

ipa_info_plist="$(mktemp "${TMPDIR:-/tmp}/buysell-ipa-info.XXXXXX")"
ipa_privacy_manifest="$(mktemp "${TMPDIR:-/tmp}/buysell-ipa-privacy.XXXXXX")"
ipa_entitlements="$(mktemp "${TMPDIR:-/tmp}/buysell-ipa-entitlements.XXXXXX")"
ipa_extract_dir="$(mktemp -d "${TMPDIR:-/tmp}/buysell-validation-ipa.XXXXXX")"
plist_buddy="/usr/libexec/PlistBuddy"

cleanup() {
    rm -f "$ipa_info_plist" "$ipa_privacy_manifest" "$ipa_entitlements"
    rm -rf "$ipa_extract_dir"
}
trap cleanup EXIT

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

pending_or_fail() {
    if [[ "$allow_missing_asc" == "1" ]]; then
        printf 'M10 App Store validation preflight pending: %s\n' "$*"
        printf 'Export an IPA and set ASC_API_KEY_ID, ASC_API_ISSUER_ID, and optionally ASC_API_PRIVATE_KEYS_DIR, then rerun without ALLOW_MISSING_ASC=1.\n'
        exit 0
    fi

    fail "$*"
}

plist_value() {
    "${plist_buddy}" -c "Print :$1" "$2"
}

plist_array_value() {
    "${plist_buddy}" -c "Print :$1:$2" "$3"
}

plist_raw_value() {
    plutil -extract "$1" raw -o - "$2"
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

ipa_path=""
if [[ -f "$artifact_path" ]]; then
    [[ "$artifact_path" == *.ipa ]] || fail "expected an .ipa file or an export directory"
    ipa_path="$artifact_path"
elif [[ -d "$artifact_path" ]]; then
    ipa_path="$(find "$artifact_path" -maxdepth 1 -type f -name '*.ipa' -print | sort | head -n 1)"
else
    pending_or_fail "missing IPA or export directory at $artifact_path"
fi

[[ -n "$ipa_path" ]] || pending_or_fail "no IPA was found in $artifact_path"
[[ -f "$ipa_path" ]] || pending_or_fail "missing IPA at $ipa_path"

unzip -l "$ipa_path" 'Payload/BuySellAI.app/Info.plist' >/dev/null || fail "IPA is missing Info.plist"
unzip -l "$ipa_path" 'Payload/BuySellAI.app/PrivacyInfo.xcprivacy' >/dev/null || fail "IPA is missing PrivacyInfo.xcprivacy"
unzip -l "$ipa_path" 'Payload/BuySellAI.app/BuySellAI' >/dev/null || fail "IPA is missing app executable"
unzip -q "$ipa_path" 'Payload/BuySellAI.app/*' -d "$ipa_extract_dir" || fail "could not inspect IPA app bundle"
ipa_app_path="${ipa_extract_dir}/Payload/BuySellAI.app"
[[ -d "$ipa_app_path" ]] || fail "IPA is missing app bundle"

unzip -p "$ipa_path" 'Payload/BuySellAI.app/Info.plist' > "$ipa_info_plist"
unzip -p "$ipa_path" 'Payload/BuySellAI.app/PrivacyInfo.xcprivacy' > "$ipa_privacy_manifest"

plutil -lint "$ipa_info_plist" >/dev/null
plutil -lint "$ipa_privacy_manifest" >/dev/null
require_privacy_manifest_values "$ipa_privacy_manifest"

ipa_bundle_id="$(plist_value CFBundleIdentifier "$ipa_info_plist")"
[[ "$ipa_bundle_id" == "com.rhodes.buysellai" ]] || fail "unexpected IPA bundle identifier"
[[ "$(plist_value NSCameraUsageDescription "$ipa_info_plist")" == "BuySell uses your camera to snap photos of items you want to sell." ]] || fail "camera usage description mismatch"
release_version="$(plist_value CFBundleShortVersionString "$ipa_info_plist")"
release_build="$(plist_value CFBundleVersion "$ipa_info_plist")"
[[ -n "$release_version" ]] || fail "IPA Info.plist is missing CFBundleShortVersionString"
[[ -n "$release_build" ]] || fail "IPA Info.plist is missing CFBundleVersion"

codesign -d --entitlements :- "$ipa_app_path" > "$ipa_entitlements" 2>/dev/null || fail "could not read IPA entitlements"
ipa_sign_in_with_apple="$(plist_array_value com.apple.developer.applesignin 0 "$ipa_entitlements" || true)"
[[ "$ipa_sign_in_with_apple" == "Default" ]] || fail "IPA is missing Sign in with Apple entitlement"

[[ -n "$api_key_id" ]] || pending_or_fail "ASC_API_KEY_ID is unset"
[[ -n "$api_issuer_id" ]] || pending_or_fail "ASC_API_ISSUER_ID is unset"

if [[ -n "$private_keys_dir" ]]; then
    [[ -f "${private_keys_dir}/AuthKey_${api_key_id}.p8" ]] || pending_or_fail "missing App Store Connect private key file in ASC_API_PRIVATE_KEYS_DIR"
    export API_PRIVATE_KEYS_DIR="$private_keys_dir"
fi

xcrun altool --validate-app \
    -f "$ipa_path" \
    -t ios \
    --apiKey "$api_key_id" \
    --apiIssuer "$api_issuer_id" \
    --output-format json

printf 'M10 App Store validation preflight passed\n'
printf 'ipa: %s\n' "$ipa_path"
printf 'bundle id: %s\n' "$ipa_bundle_id"
printf 'sign in with apple: %s\n' "$ipa_sign_in_with_apple"
printf 'release build: %s (%s)\n' "$release_version" "$release_build"
