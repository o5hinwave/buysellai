#!/usr/bin/env bash
set -euo pipefail

nomination_file="${1:-${M10_TODAY_FEATURE_NOMINATION:-M10_TODAY_FEATURE_NOMINATION.md}}"
metadata_file="${M10_APP_STORE_METADATA:-M10_APP_STORE_METADATA.md}"

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

metadata_value() {
    local file="$1"
    local field="$2"

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
    ' "$file"
}

is_placeholder() {
    local normalized

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$(trim "$1")")"
    case "$normalized" in
        ""|"tbd"|"pending"|"-")
            return 0
            ;;
    esac
    return 1
}

require_value() {
    local field="$1"
    local value

    value="$(metadata_value "$nomination_file" "$field")"
    if is_placeholder "$value"; then
        fail "nomination field '$field' is not recorded"
    fi
}

require_terms() {
    local field="$1"
    shift

    local value
    local normalized
    local term

    value="$(metadata_value "$nomination_file" "$field")"
    if is_placeholder "$value"; then
        fail "nomination field '$field' is not recorded"
    fi

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$value")"
    for term in "$@"; do
        if [[ "$normalized" != *"$term"* ]]; then
            fail "nomination field '$field' must mention '$term'"
        fi
    done
}

require_file() {
    local path="$1"

    [[ -f "$path" ]] || fail "required nomination asset is missing at $path"
}

[[ -f "$nomination_file" ]] || fail "nomination package is missing at $nomination_file"
[[ -f "$metadata_file" ]] || fail "App Store metadata evidence is missing at $metadata_file"

required_fields=(
    "App Store Connect path"
    "Apple guidance source"
    "App Store Connect help source"
    "Submission lead time"
    "Required App Store Connect role"
    "App"
    "Platform"
    "Nomination type"
    "Preferred placement"
    "Feature title"
    "One-line story"
    "Editorial angle"
    "Why now"
    "New content/functionality"
    "Technology quality"
    "Accessibility story"
    "Privacy story"
    "Screenshots"
    "Support URLs"
    "Reviewer path"
    "App icon"
    "Product screenshots"
    "Visual signal"
    "Accessibility evidence"
)

for field in "${required_fields[@]}"; do
    require_value "$field"
done

require_terms "Preferred placement" "today tab" "apps tab"
require_terms "Submission lead time" "two weeks" "three months"
require_terms "Required App Store Connect role" "account holder" "admin" "app manager" "marketing"
require_terms "Apple guidance source" "developer.apple.com/app-store/getting-featured"
require_terms "App Store Connect help source" "developer.apple.com/help/app-store-connect/manage-featuring-nominations"
require_terms "New content/functionality" "avfoundation" "supabase" "marketplace" "sign in with apple" "swiftdata"
require_terms "Technology quality" "swiftui" "observation" "avfoundation" "swiftdata" "async/await"
require_terms "Accessibility story" "voiceover" "larger text" "reduced motion" "reduce transparency" "44-point"
require_terms "Privacy story" "guest" "optional" "no tracking" "supabase edge function secrets"
require_terms "Screenshots" "appstoreassets/screenshots/iphone-16-pro-max" "appstoreassets/screenshots/ipad-pro-13-inch-m4"
require_terms "Support URLs" "m10_app_store_metadata.md"
require_terms "Visual signal" "warm buysell orange" "no loud gradients" "generic dashboard"

require_file "BuySellAI/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
for directory in AppStoreAssets/Screenshots/iPhone-16-Pro-Max AppStoreAssets/Screenshots/iPad-Pro-13-inch-M4; do
    require_file "$directory/01-home.png"
    require_file "$directory/02-result.png"
    require_file "$directory/03-marketplaces.png"
    require_file "$directory/04-listing.png"
done

support_url="$(metadata_value "$metadata_file" "Support URL")"
privacy_url="$(metadata_value "$metadata_file" "Privacy Policy URL")"
accessibility_url="$(metadata_value "$metadata_file" "Accessibility URL")"
[[ "$support_url" =~ ^https:// ]] || fail "metadata Support URL must be a public HTTPS URL"
[[ "$privacy_url" =~ ^https:// ]] || fail "metadata Privacy Policy URL must be a public HTTPS URL"
[[ "$accessibility_url" =~ ^https:// ]] || fail "metadata Accessibility URL must be a public HTTPS URL"

printf 'M10 Today feature nomination package passed\n'
printf 'file: %s\n' "$nomination_file"
printf 'placement: %s\n' "$(metadata_value "$nomination_file" "Preferred placement")"
printf 'story: %s\n' "$(metadata_value "$nomination_file" "One-line story")"
printf 'lead time: %s\n' "$(metadata_value "$nomination_file" "Submission lead time")"
printf 'role: %s\n' "$(metadata_value "$nomination_file" "Required App Store Connect role")"
printf 'assets: screenshots iPhone 6.9, iPad 13, text-free 1024 icon\n'
printf 'source: Apple Getting Featured on the App Store\n'
