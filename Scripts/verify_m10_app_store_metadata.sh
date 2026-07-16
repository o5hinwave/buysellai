#!/usr/bin/env bash
set -euo pipefail

metadata_file="${1:-${M10_APP_STORE_METADATA:-M10_APP_STORE_METADATA.md}}"
allow_pending="${ALLOW_PENDING_METADATA:-0}"
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
require_length_at_most "App name" 30
require_length_at_most "Subtitle" 30
require_length_at_most "Keywords" 100

if (( ${#pending_items[@]} > 0 )); then
    if [[ "$allow_pending" == "1" ]]; then
        printf 'M10 App Store metadata pending:\n'
        printf ' - %s\n' "${pending_items[@]}"
        printf 'Complete App Store Connect metadata, screenshots, privacy/support URLs, age rating, DSA status, and review notes, then rerun without ALLOW_PENDING_METADATA=1.\n'
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
printf 'app privacy: %s; tracking: %s\n' "$(metadata_value "App privacy data types")" "$(metadata_value "Data used for tracking")"
