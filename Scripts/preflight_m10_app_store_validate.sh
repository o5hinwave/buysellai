#!/usr/bin/env bash
set -euo pipefail

artifact_path="${1:-/tmp/BuySellAI-appstore-export}"
allow_missing_asc="${ALLOW_MISSING_ASC:-0}"
api_key_id="${ASC_API_KEY_ID:-}"
api_issuer_id="${ASC_API_ISSUER_ID:-}"
private_keys_dir="${ASC_API_PRIVATE_KEYS_DIR:-${API_PRIVATE_KEYS_DIR:-}}"

ipa_info_plist="$(mktemp "${TMPDIR:-/tmp}/buysell-ipa-info.XXXXXX")"
ipa_privacy_manifest="$(mktemp "${TMPDIR:-/tmp}/buysell-ipa-privacy.XXXXXX")"
plist_buddy="/usr/libexec/PlistBuddy"

cleanup() {
    rm -f "$ipa_info_plist" "$ipa_privacy_manifest"
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

unzip -p "$ipa_path" 'Payload/BuySellAI.app/Info.plist' > "$ipa_info_plist"
unzip -p "$ipa_path" 'Payload/BuySellAI.app/PrivacyInfo.xcprivacy' > "$ipa_privacy_manifest"

plutil -lint "$ipa_info_plist" >/dev/null
plutil -lint "$ipa_privacy_manifest" >/dev/null

[[ "$(plist_value CFBundleIdentifier "$ipa_info_plist")" == "com.rhodes.buysellai" ]] || fail "unexpected IPA bundle identifier"
[[ "$(plist_value NSCameraUsageDescription "$ipa_info_plist")" == "BuySell uses your camera to snap photos of items you want to sell." ]] || fail "camera usage description mismatch"

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
