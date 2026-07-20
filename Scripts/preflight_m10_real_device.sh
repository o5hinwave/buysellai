#!/usr/bin/env bash
set -euo pipefail

allow_missing_device="${ALLOW_MISSING_DEVICE:-0}"
device_identifier="${DEVICE_ID:-}"
m10_development_team="${M10_DEVELOPMENT_TEAM:-}"
snapshot_root="${M10_REAL_DEVICE_SNAPSHOT_ROOT:-}"
settings_timeout_seconds="${M10_XCODEBUILD_SETTINGS_TIMEOUT:-60}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_root="$(cd "${script_dir}/.." && pwd)"
work_root="$source_root"
device_json="$(mktemp "${TMPDIR:-/tmp}/buysell-devices.XXXXXX")"
built_entitlements="$(mktemp "${TMPDIR:-/tmp}/buysell-real-device-entitlements.XXXXXX")"
build_settings_output="$(mktemp "${TMPDIR:-/tmp}/buysell-real-device-build-settings.XXXXXX")"
plist_buddy="/usr/libexec/PlistBuddy"

cleanup() {
    rm -f "$device_json" "$built_entitlements" "$build_settings_output"
}
trap cleanup EXIT

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

prepare_snapshot() {
    local target="$1"
    local parent
    local name
    local -a entries

    [[ -n "$target" ]] || return 0

    parent="$(dirname "$target")"
    name="$(basename "$target")"
    mkdir -p "$parent"
    parent="$(cd "$parent" && pwd -P)"
    target="${parent}/${name}"

    case "$target" in
        /tmp/*|/private/tmp/*) ;;
        *) fail "M10_REAL_DEVICE_SNAPSHOT_ROOT must be under /tmp" ;;
    esac
    [[ "$target" != "$source_root" ]] || fail "M10_REAL_DEVICE_SNAPSHOT_ROOT must not point at the source checkout"

    rm -rf "$target"
    mkdir -p "$target"

    entries=(
        "BuySellAI"
        "BuySellAI.xcodeproj"
        "BuySellAITests"
        "BuySellAIUITests"
        "Scripts"
        "supabase"
        "AppStoreAssets"
        "M10_ACCEPTANCE.md"
        "M10_APP_STORE_METADATA.md"
        "M10_INSTRUMENTS.md"
        "README.md"
        ".gitignore"
    )

    for entry in "${entries[@]}"; do
        rsync -a "${source_root}/${entry}" "$target/"
    done

    work_root="$target"
    snapshot_root="$target"
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

project_development_team_is_configured() {
    local project_file="${project_path}/project.pbxproj"

    [[ -f "$project_file" ]] || fail "missing Xcode project file at $project_file"
    grep -Eq 'DEVELOPMENT_TEAM = [A-Za-z0-9]+' "$project_file"
}

show_release_build_settings() {
    rm -f "$build_settings_output"

    xcodebuild -showBuildSettings \
        -project "$project_path" \
        -scheme BuySellAI \
        -configuration Release \
        -destination "id=${device_identifier}" \
        ${team_build_setting:+"$team_build_setting"} \
        > "$build_settings_output" 2>/dev/null &

    local settings_pid=$!
    local elapsed=0

    while kill -0 "$settings_pid" 2>/dev/null; do
        if [[ "$settings_timeout_seconds" -gt 0 && "$elapsed" -ge "$settings_timeout_seconds" ]]; then
            kill -TERM "$settings_pid" 2>/dev/null || true
            wait "$settings_pid" 2>/dev/null || true
            fail "xcodebuild -showBuildSettings timed out after ${settings_timeout_seconds}s. Set M10_XCODEBUILD_SETTINGS_TIMEOUT to a larger value after confirming the checkout is fully local."
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    wait "$settings_pid" || fail "xcodebuild -showBuildSettings failed"
    cat "$build_settings_output"
}

team_build_setting=""
if [[ -n "$m10_development_team" ]]; then
    team_build_setting="DEVELOPMENT_TEAM=${m10_development_team}"
fi

[[ "$settings_timeout_seconds" =~ ^[0-9]+$ ]] || fail "M10_XCODEBUILD_SETTINGS_TIMEOUT must be a whole number"

prepare_snapshot "$snapshot_root"
project_path="${work_root}/BuySellAI.xcodeproj"

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
        if [[ -n "$snapshot_root" ]]; then
            printf 'snapshot root: %s\n' "$snapshot_root"
        fi
        printf 'Connect a trusted device with Developer Mode enabled, then rerun without ALLOW_MISSING_DEVICE=1.\n'
        exit 0
    fi
    fail "no connected iPhone or iPad was found by devicectl"
fi

if [[ -n "${DEVICE_ID:-}" && -z "$device_name" ]]; then
    fail "DEVICE_ID was set but devicectl did not report a matching device"
fi

if [[ -z "$m10_development_team" ]] && ! project_development_team_is_configured; then
    fail "DEVELOPMENT_TEAM is unset. Set M10_DEVELOPMENT_TEAM or select an Apple development team before real-device preflight."
fi

build_settings="$(show_release_build_settings)"

[[ "$(setting PRODUCT_BUNDLE_IDENTIFIER)" == "com.rhodes.buysellai" ]] || fail "unexpected Release bundle identifier"
[[ "$(setting CODE_SIGN_STYLE)" == "Automatic" ]] || fail "Release signing style must be Automatic"
[[ "$(setting CODE_SIGN_ENTITLEMENTS)" == "BuySellAI/BuySellAI.entitlements" ]] || fail "Release build must use BuySellAI.entitlements"
[[ -n "$(setting DEVELOPMENT_TEAM)" ]] || fail "DEVELOPMENT_TEAM is unset. Set M10_DEVELOPMENT_TEAM or select an Apple development team before real-device preflight."

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
    -allowProvisioningUpdates \
    ${team_build_setting:+"$team_build_setting"}

[[ -d "$built_app_path" ]] || fail "missing built app at $built_app_path"
[[ -f "$built_info_plist" ]] || fail "missing built app Info.plist at $built_info_plist"
plutil -lint "$built_info_plist" >/dev/null

release_version="$(plist_value CFBundleShortVersionString "$built_info_plist")"
release_build="$(plist_value CFBundleVersion "$built_info_plist")"
built_bundle_id="$(plist_value CFBundleIdentifier "$built_info_plist")"
[[ "$built_bundle_id" == "com.rhodes.buysellai" ]] || fail "unexpected real-device build bundle identifier"
[[ -n "$release_version" ]] || fail "built app Info.plist is missing CFBundleShortVersionString"
[[ -n "$release_build" ]] || fail "built app Info.plist is missing CFBundleVersion"

codesign -d --entitlements :- "$built_app_path" > "$built_entitlements" 2>/dev/null || fail "could not read real-device build entitlements"
built_sign_in_with_apple="$(plist_array_value com.apple.developer.applesignin 0 "$built_entitlements" || true)"
[[ "$built_sign_in_with_apple" == "Default" ]] || fail "real-device build is missing Sign in with Apple entitlement"

printf 'M10 real-device preflight passed\n'
printf 'device: %s (%s)\n' "${device_name:-Connected device}" "$device_identifier"
printf 'device name: %s\n' "${device_name:-Connected device}"
printf 'device id: %s\n' "$device_identifier"
if [[ -n "$snapshot_root" ]]; then
    printf 'snapshot root: %s\n' "$snapshot_root"
fi
printf 'app: %s\n' "$built_app_path"
printf 'bundle id: %s\n' "$built_bundle_id"
printf 'sign in with apple: %s\n' "$built_sign_in_with_apple"
printf 'release build: %s (%s)\n' "$release_version" "$release_build"
