#!/usr/bin/env bash
set -euo pipefail

metadata_file="${1:-${M10_APP_STORE_METADATA:-M10_APP_STORE_METADATA.md}}"
allow_pending="${ALLOW_PENDING_METADATA:-0}"
screenshot_dir="${M10_APP_STORE_SCREENSHOT_DIR:-AppStoreAssets/Screenshots/iPhone-16-Pro}"
expected_screenshot_width="${M10_APP_STORE_SCREENSHOT_WIDTH:-1206}"
expected_screenshot_height="${M10_APP_STORE_SCREENSHOT_HEIGHT:-2622}"
screenshot_capture_test="BuySellAIUITests/testM10AppStoreScreenshotsCanBeCaptured()"
required_screenshots=(
    "01-home.png"
    "02-result.png"
    "03-marketplaces.png"
    "04-listing.png"
)
pending_items=()

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

trim() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

is_placeholder() {
    local value
    local normalized

    value="$(trim "$1")"
    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$value")"
    case "$normalized" in
        ""|"tbd"|"pending"|"-"|"n/a")
            return 0
            ;;
    esac
    return 1
}

strip_inline_code() {
    local value

    value="$(trim "$1")"
    value="${value#\`}"
    value="${value%\`}"
    printf '%s' "$value"
}

metadata_value() {
    local field="$1"

    awk -F'|' -v field="$field" '
        {
            key = $2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            if (key == field) {
                value = $3
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                print value
                exit
            }
        }
    ' "$metadata_file"
}

pending() {
    pending_items+=("$*")
}

require_value() {
    local field="$1"
    local value

    value="$(metadata_value "$field")"
    if is_placeholder "$value"; then
        pending "metadata '$field' is not recorded"
    fi
}

require_exact() {
    local field="$1"
    local expected="$2"
    local value

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    if [[ "$value" != "$expected" ]]; then
        pending "metadata '$field' is '$value', expected '$expected'"
    fi
}

require_any_term() {
    local field="$1"
    local label="$2"
    shift 2

    local value
    local normalized
    local term

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$value")"
    for term in "$@"; do
        if [[ "$normalized" == *"$term"* ]]; then
            return
        fi
    done

    pending "metadata '$field' must mention $label: one of $*"
}

require_terms() {
    local field="$1"
    local label="$2"
    shift 2

    local value
    local normalized
    local term
    local missing_terms=()

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$value")"
    for term in "$@"; do
        if [[ "$normalized" != *"$term"* ]]; then
            missing_terms+=("$term")
        fi
    done

    if (( ${#missing_terms[@]} > 0 )); then
        pending "metadata '$field' must mention $label: ${missing_terms[*]}"
    fi
}

require_https_url() {
    local field="$1"
    local value

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    if [[ ! "$value" =~ ^https://[^[:space:]]+\.[^[:space:]]+ ]]; then
        pending "metadata '$field' must be a full https URL"
    fi
}

require_public_https_url() {
    local field="$1"
    local value
    local status
    local timeout_seconds

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    [[ "$value" =~ ^https://[^[:space:]]+\.[^[:space:]]+ ]] || return

    if ! command -v curl >/dev/null 2>&1; then
        pending "metadata '$field' requires curl to verify public URL reachability"
        return
    fi

    timeout_seconds="${M10_METADATA_URL_TIMEOUT:-10}"
    if ! status="$(
        curl -L -sS -o /dev/null -w "%{http_code}" \
            --max-time "$timeout_seconds" \
            "$value" 2>/dev/null
    )"; then
        pending "metadata '$field' must be publicly reachable without authentication"
        return
    fi

    if [[ ! "$status" =~ ^[0-9][0-9][0-9]$ ]] || (( status < 200 || status >= 400 )); then
        pending "metadata '$field' must be publicly reachable without authentication (HTTP $status)"
    fi
}

require_length_at_most() {
    local field="$1"
    local max_bytes="$2"
    local value
    local byte_count

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    byte_count="$(printf '%s' "$value" | wc -c | tr -d '[:space:]')"
    if [[ "$byte_count" -gt "$max_bytes" ]]; then
        pending "metadata '$field' is ${byte_count} bytes, expected <= ${max_bytes}"
    fi
}

require_not_generic_pass() {
    local field="$1"
    local value
    local normalized

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$(trim "$value")")"
    case "$normalized" in
        "passed"|"pass"|"done"|"complete"|"completed")
            pending "metadata '$field' must cite concrete evidence, not '$value'"
            ;;
    esac
}

require_screenshot_assets() {
    local screenshots_value
    local file
    local path
    local format
    local width
    local height

    if ! command -v sips >/dev/null 2>&1; then
        pending "screenshot evidence requires sips to verify PNG dimensions"
        return
    fi

    screenshots_value="$(metadata_value "Screenshots")"

    for file in "${required_screenshots[@]}"; do
        path="${screenshot_dir%/}/$file"

        if [[ ! -f "$path" ]]; then
            pending "screenshot asset is missing at $path"
            continue
        fi

        format="$(sips -g format "$path" 2>/dev/null | awk -F': ' '/format:/ { print $2; exit }')"
        width="$(sips -g pixelWidth "$path" 2>/dev/null | awk -F': ' '/pixelWidth:/ { print $2; exit }')"
        height="$(sips -g pixelHeight "$path" 2>/dev/null | awk -F': ' '/pixelHeight:/ { print $2; exit }')"

        if [[ "$format" != "png" ]]; then
            pending "screenshot asset $path is '$format', expected png"
        fi

        if [[ "$width" != "$expected_screenshot_width" || "$height" != "$expected_screenshot_height" ]]; then
            pending "screenshot asset $path is ${width:-0}x${height:-0}, expected ${expected_screenshot_width}x${expected_screenshot_height}"
        fi

        if ! is_placeholder "$screenshots_value" && [[ "$screenshots_value" != *"$file"* ]]; then
            pending "metadata 'Screenshots' must reference screenshot file $file"
        fi
    done
}

require_screenshot_capture_result() {
    local result_bundle
    local tests_json

    result_bundle="$(strip_inline_code "$(metadata_value "Result bundle")")"
    if is_placeholder "$result_bundle"; then
        pending "metadata 'Result bundle' is not recorded"
        return
    fi

    if [[ ! -d "$result_bundle" ]]; then
        pending "screenshot result bundle is missing at $result_bundle"
        return
    fi

    if ! tests_json="$(xcrun xcresulttool get test-results tests --path "$result_bundle" --format json 2>/dev/null)"; then
        pending "screenshot result bundle could not be read by xcresulttool"
        return
    fi

    if ! awk -v test_id="\"nodeIdentifier\" : \"${screenshot_capture_test}\"" '
        index($0, test_id) > 0 { found = 1; window = 0 }
        found && /"result" : "Passed"/ { passed = 1; exit }
        found {
            window++
            if (window > 8) {
                exit
            }
        }
        END { exit !(found && passed) }
    ' <<< "$tests_json"; then
        pending "screenshot capture test did not pass in $result_bundle"
    fi
}

[[ -f "$metadata_file" ]] || fail "missing App Store metadata file at $metadata_file"

required_fields=(
    "App name"
    "Bundle ID"
    "SKU"
    "Primary language"
    "Primary category"
    "Age rating"
    "Made for Kids"
    "DSA trader status"
    "License agreement"
    "Version number"
    "Copyright"
    "Subtitle"
    "Description"
    "Keywords"
    "Support URL"
    "Privacy Policy URL"
    "Screenshots"
    "App Review notes"
    "App privacy data types"
    "Data linked to user"
    "Data used for tracking"
    "Tracking domains"
    "Data use purpose"
    "Account deletion"
    "Export compliance"
)

for field in "${required_fields[@]}"; do
    require_value "$field"
    require_not_generic_pass "$field"
done

require_exact "App name" "BuySell AI"
require_exact "Bundle ID" "com.rhodes.buysellai"
require_exact "Made for Kids" "No"
require_exact "Data linked to user" "Yes"
require_exact "Data used for tracking" "No"
require_exact "Tracking domains" "None"
require_exact "Data use purpose" "App Functionality"
require_terms "License agreement" "license agreement" "apple" "standard"
require_terms "Primary category" "primary category" "shopping"
require_any_term "Age rating" "age rating" "4+" "9+" "12+" "17+"
require_any_term "DSA trader status" "Digital Services Act trader status" "trader" "not a trader"
require_terms "Description" "core product flow" "snap" "photo" "marketplace" "listing"
require_terms "App privacy data types" "App Store privacy data types" "email address" "user id" "photos or videos" "other user content"
require_terms "Account deletion" "in-app account deletion path" "delete account" "settings"
require_terms "Export compliance" "export compliance answer" "itsappusesnonexemptencryption=false" "https"
require_terms "Screenshots" "screenshot evidence" "screenshot" "iphone"
require_terms "App Review notes" "review instructions" "camera" "sign in with apple" "guest" "supabase"
require_https_url "Support URL"
require_https_url "Privacy Policy URL"
require_public_https_url "Support URL"
require_public_https_url "Privacy Policy URL"
require_length_at_most "App name" 30
require_length_at_most "Subtitle" 30
require_length_at_most "Keywords" 100
require_screenshot_assets
require_screenshot_capture_result

if (( ${#pending_items[@]} > 0 )); then
    if [[ "$allow_pending" == "1" ]]; then
        printf 'M10 App Store metadata pending:\n'
        printf ' - %s\n' "${pending_items[@]}"
        printf 'Complete the listed App Store Connect metadata items, then rerun without ALLOW_PENDING_METADATA=1.\n'
        exit 0
    fi

    printf 'error: M10 App Store metadata incomplete:\n' >&2
    printf ' - %s\n' "${pending_items[@]}" >&2
    exit 1
fi

printf 'M10 App Store metadata evidence passed\n'
printf 'file: %s\n' "$metadata_file"
printf 'app name: %s\n' "$(metadata_value "App name")"
printf 'bundle id: %s\n' "$(metadata_value "Bundle ID")"
printf 'version: %s\n' "$(metadata_value "Version number")"
printf 'privacy policy: %s\n' "$(metadata_value "Privacy Policy URL")"
printf 'support: %s\n' "$(metadata_value "Support URL")"
printf 'screenshots: %s\n' "$(metadata_value "Screenshots")"
printf 'screenshot directory: %s\n' "$screenshot_dir"
printf 'screenshot files: %s\n' "${#required_screenshots[@]}"
printf 'screenshot dimensions: %sx%s\n' "$expected_screenshot_width" "$expected_screenshot_height"
printf 'screenshot result bundle: %s\n' "$(strip_inline_code "$(metadata_value "Result bundle")")"
printf 'screenshot capture test: %s\n' "$screenshot_capture_test"
printf 'app privacy: %s; tracking: %s\n' "$(metadata_value "App privacy data types")" "$(metadata_value "Data used for tracking")"
