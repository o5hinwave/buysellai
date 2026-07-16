#!/usr/bin/env bash
set -euo pipefail

allow_missing_device="${ALLOW_MISSING_DEVICE:-0}"
device_identifier="${DEVICE_ID:-}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
project_path="${repo_root}/BuySellAI.xcodeproj"
device_json="$(mktemp "${TMPDIR:-/tmp}/buysell-devices.XXXXXX")"
built_entitlements="$(mktemp "${TMPDIR:-/tmp}/buysell-real-device-entitlements.XXXXXX")"
plist_buddy="/usr/libexec/PlistBuddy"

cleanup() {
    rm -f "$device_json" "$built_entitlements"
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

plist_value() {
    "${plist_buddy}" -c "Print :$1" "$2"
}

plist_array_value() {
    "${plist_buddy}" -c "Print :$1:$2" "$3"
}

is_ios_device() {
    local summary="$1"

    [[ "$summary" =~ (iOS|iPhone|iPad|iphone|ipad) ]]
}

xcrun devicectl list devices --json-output "$device_json" --timeout 15 >/dev/null
plutil -convert xml1 "$device_json"

device_name=""
if [[ -z "$device_identifier" ]]; then
    for index in $(seq 0 99); do
        candidate_identifier="$(plist_optional "result:devices:${index}:identifier")"
        [[ -n "$candidate_identifier" ]] || break

        candidate_name="$(plist_optional "result:devices:${index}:deviceProperties:name")"
        [[ -n "$candidate_name" ]] || candidate_name="$(plist_optional "result:devices:${index}:name")"

        candidate_platform="$(plist_optional "result:devices:${index}:hardwareProperties:platform")"
        candidate_product_type="$(plist_optional "result:devices:${index}:hardwareProperties:productType")"
        candidate_summary="${candidate_platform} ${candidate_product_type} ${candidate_name}"

        if is_ios_device "$candidate_summary"; then
            device_identifier="$candidate_identifier"
            device_name="$candidate_name"
            break
        fi
    done
else
    matched_device="0"
    matched_ios_device="0"

    for index in $(seq 0 99); do
        candidate_identifier="$(plist_optional "result:devices:${index}:identifier")"
        [[ -n "$candidate_identifier" ]] || break

        if [[ "$candidate_identifier" == "$device_identifier" ]]; then
            matched_device="1"
            device_name="$(plist_optional "result:devices:${index}:deviceProperties:name")"
            [[ -n "$device_name" ]] || device_name="$(plist_optional "result:devices:${index}:name")"
            candidate_platform="$(plist_optional "result:devices:${index}:hardwareProperties:platform")"
            candidate_product_type="$(plist_optional "result:devices:${index}:hardwareProperties:productType")"
            candidate_summary="${candidate_platform} ${candidate_product_type} ${device_name}"
            if is_ios_device "$candidate_summary"; then
                matched_ios_device="1"
            fi
            break
        fi
    done

    if [[ "$matched_device" == "1" && "$matched_ios_device" != "1" ]]; then
        fail "DEVICE_ID matched a non-iOS device. Use a trusted iPhone or iPad."
    fi
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
        -destination "id=${device_identifier}" \
        2>/dev/null
)"

[[ "$(setting PRODUCT_BUNDLE_IDENTIFIER)" == "com.rhodes.buysellai" ]] || fail "unexpected Release bundle identifier"
[[ "$(setting CODE_SIGN_STYLE)" == "Automatic" ]] || fail "Release signing style must be Automatic"
[[ "$(setting CODE_SIGN_ENTITLEMENTS)" == "BuySellAI/BuySellAI.entitlements" ]] || fail "Release build must use BuySellAI.entitlements"
[[ -n "$(setting DEVELOPMENT_TEAM)" ]] || fail "DEVELOPMENT_TEAM is unset. Select an Apple development team before real-device preflight."

target_build_dir="$(setting TARGET_BUILD_DIR)"
wrapper_name="$(setting WRAPPER_NAME)"
[[ -n "$target_build_dir" && -n "$wrapper_name" ]] || fail "Release build settings did not include TARGET_BUILD_DIR and WRAPPER_NAME"
built_app_path="${target_build_dir}/${wrapper_name}"
built_info_plist="${built_app_path}/Info.plist"

xcodebuild build \
    -project "$project_path" \
    -scheme BuySellAI \
    -configuration Release \
    -destination "id=${device_identifier}" \
    -allowProvisioningUpdates

[[ -d "$built_app_path" ]] || fail "missing built app at $built_app_path"
[[ -f "$built_info_plist" ]] || fail "missing built app Info.plist at $built_info_plist"
plutil -lint "$built_info_plist" >/dev/null

release_version="$(plist_value CFBundleShortVersionString "$built_info_plist")"
release_build="$(plist_value CFBundleVersion "$built_info_plist")"
[[ -n "$release_version" ]] || fail "built app Info.plist is missing CFBundleShortVersionString"
[[ -n "$release_build" ]] || fail "built app Info.plist is missing CFBundleVersion"

codesign -d --entitlements :- "$built_app_path" > "$built_entitlements" 2>/dev/null || fail "could not read real-device build entitlements"
built_sign_in_with_apple="$(plist_array_value com.apple.developer.applesignin 0 "$built_entitlements" || true)"
[[ "$built_sign_in_with_apple" == "Default" ]] || fail "real-device build is missing Sign in with Apple entitlement"

printf 'M10 real-device preflight passed\n'
printf 'device: %s (%s)\n' "${device_name:-Connected device}" "$device_identifier"
printf 'device name: %s\n' "${device_name:-Connected device}"
printf 'device id: %s\n' "$device_identifier"
printf 'app: %s\n' "$built_app_path"
printf 'sign in with apple: %s\n' "$built_sign_in_with_apple"
printf 'release build: %s (%s)\n' "$release_version" "$release_build"
