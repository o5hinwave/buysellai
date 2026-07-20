#!/usr/bin/env bash
set -euo pipefail

archive_path="${1:-/tmp/BuySellAI-signed.xcarchive}"
allow_missing_team="${ALLOW_MISSING_TEAM:-0}"
m10_development_team="${M10_DEVELOPMENT_TEAM:-}"
snapshot_root="${M10_SIGNED_ARCHIVE_SNAPSHOT_ROOT:-}"
settings_timeout_seconds="${M10_XCODEBUILD_SETTINGS_TIMEOUT:-60}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_root="$(cd "${script_dir}/.." && pwd)"
work_root="$source_root"
app_path="${archive_path}/Products/Applications/BuySellAI.app"
info_plist="${app_path}/Info.plist"
privacy_manifest="${app_path}/PrivacyInfo.xcprivacy"
signed_entitlements="$(mktemp "${TMPDIR:-/tmp}/buysell-signed-entitlements.XXXXXX")"
build_settings_output="$(mktemp "${TMPDIR:-/tmp}/buysell-signed-build-settings.XXXXXX")"
plist_buddy="/usr/libexec/PlistBuddy"

cleanup() {
    rm -f "$signed_entitlements" "$build_settings_output"
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
        *) fail "M10_SIGNED_ARCHIVE_SNAPSHOT_ROOT must be under /tmp" ;;
    esac
    [[ "$target" != "$source_root" ]] || fail "M10_SIGNED_ARCHIVE_SNAPSHOT_ROOT must not point at the source checkout"

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

print_missing_team_pending() {
    printf 'M10 signed archive preflight pending: DEVELOPMENT_TEAM is unset\n'
    if [[ -n "$snapshot_root" ]]; then
        printf 'snapshot root: %s\n' "$snapshot_root"
    fi
    printf 'Set M10_DEVELOPMENT_TEAM or select an Apple development team in Xcode, then rerun without ALLOW_MISSING_TEAM=1 to produce a signed archive.\n'
}

show_release_build_settings() {
    rm -f "$build_settings_output"

    xcodebuild -showBuildSettings \
        -project "$project_path" \
        -scheme BuySellAI \
        -configuration Release \
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
entitlements_path="${work_root}/BuySellAI/BuySellAI.entitlements"

if [[ -z "$m10_development_team" && "$allow_missing_team" == "1" ]] && ! project_development_team_is_configured; then
    [[ -f "$entitlements_path" ]] || fail "missing BuySellAI.entitlements"
    [[ "$(plist_array_value com.apple.developer.applesignin 0 "$entitlements_path")" == "Default" ]] || fail "Sign in with Apple entitlement is missing from source entitlements"
    print_missing_team_pending
    exit 0
fi

build_settings="$(show_release_build_settings)"

[[ "$(setting PRODUCT_BUNDLE_IDENTIFIER)" == "com.rhodes.buysellai" ]] || fail "unexpected Release bundle identifier"
[[ "$(setting CODE_SIGN_STYLE)" == "Automatic" ]] || fail "Release signing style must be Automatic"
[[ "$(setting CODE_SIGN_ENTITLEMENTS)" == "BuySellAI/BuySellAI.entitlements" ]] || fail "Release build must use BuySellAI.entitlements"
[[ -f "$entitlements_path" ]] || fail "missing BuySellAI.entitlements"
[[ "$(plist_array_value com.apple.developer.applesignin 0 "$entitlements_path")" == "Default" ]] || fail "Sign in with Apple entitlement is missing from source entitlements"

development_team="$(setting DEVELOPMENT_TEAM)"
if [[ -z "$development_team" ]]; then
    if [[ "$allow_missing_team" == "1" ]]; then
        print_missing_team_pending
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
if [[ -n "$snapshot_root" ]]; then
    printf 'snapshot root: %s\n' "$snapshot_root"
fi
printf 'bundle id: %s\n' "$bundle_id"
printf 'sign in with apple: %s\n' "$signed_sign_in_with_apple"
printf 'release build: %s (%s)\n' "$release_version" "$release_build"
