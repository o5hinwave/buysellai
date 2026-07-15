#!/usr/bin/env bash
set -euo pipefail

allow_missing_device="${ALLOW_MISSING_DEVICE:-0}"
device_identifier="${DEVICE_ID:-}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
project_path="${repo_root}/BuySellAI.xcodeproj"
device_json="$(mktemp "${TMPDIR:-/tmp}/buysell-devices.XXXXXX")"
plist_buddy="/usr/libexec/PlistBuddy"

cleanup() {
    rm -f "$device_json"
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

plist_optional() {
    "${plist_buddy}" -c "Print :$1" "$device_json" 2>/dev/null || true
}

xcrun devicectl list devices --json-output "$device_json" --timeout 15 >/dev/null
plutil -convert xml1 "$device_json"

device_name=""
if [[ -z "$device_identifier" ]]; then
    first_identifier=""
    first_name=""

    for index in $(seq 0 99); do
        candidate_identifier="$(plist_optional "result:devices:${index}:identifier")"
        [[ -n "$candidate_identifier" ]] || break

        candidate_name="$(plist_optional "result:devices:${index}:deviceProperties:name")"
        [[ -n "$candidate_name" ]] || candidate_name="$(plist_optional "result:devices:${index}:name")"

        candidate_platform="$(plist_optional "result:devices:${index}:hardwareProperties:platform")"
        candidate_product_type="$(plist_optional "result:devices:${index}:hardwareProperties:productType")"
        candidate_summary="${candidate_platform} ${candidate_product_type} ${candidate_name}"

        if [[ -z "$first_identifier" ]]; then
            first_identifier="$candidate_identifier"
            first_name="$candidate_name"
        fi

        if [[ "$candidate_summary" =~ (iOS|iPhone|iPad|iphone|ipad) ]]; then
            device_identifier="$candidate_identifier"
            device_name="$candidate_name"
            break
        fi
    done

    if [[ -z "$device_identifier" && -n "$first_identifier" ]]; then
        device_identifier="$first_identifier"
        device_name="$first_name"
    fi
else
    for index in $(seq 0 99); do
        candidate_identifier="$(plist_optional "result:devices:${index}:identifier")"
        [[ -n "$candidate_identifier" ]] || break

        if [[ "$candidate_identifier" == "$device_identifier" ]]; then
            device_name="$(plist_optional "result:devices:${index}:deviceProperties:name")"
            [[ -n "$device_name" ]] || device_name="$(plist_optional "result:devices:${index}:name")"
            break
        fi
    done
fi

if [[ -z "$device_identifier" ]]; then
    if [[ "$allow_missing_device" == "1" ]]; then
        printf 'M10 real-device preflight pending: no connected iPhone or iPad was found by devicectl\n'
        printf 'Connect a trusted device with Developer Mode enabled, then rerun without ALLOW_MISSING_DEVICE=1.\n'
        exit 0
    fi
    fail "no connected iPhone or iPad was found by devicectl"
fi

if [[ -n "${DEVICE_ID:-}" && -z "$device_name" ]]; then
    fail "DEVICE_ID was set but devicectl did not report a matching device"
fi

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
[[ -n "$(setting DEVELOPMENT_TEAM)" ]] || fail "DEVELOPMENT_TEAM is unset. Select an Apple development team before real-device preflight."

xcodebuild build \
    -project "$project_path" \
    -scheme BuySellAI \
    -configuration Release \
    -destination "id=${device_identifier}" \
    -allowProvisioningUpdates

printf 'M10 real-device preflight passed\n'
printf 'device: %s (%s)\n' "${device_name:-Connected device}" "$device_identifier"
