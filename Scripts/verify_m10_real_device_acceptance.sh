#!/usr/bin/env bash
set -euo pipefail

acceptance_file="${1:-M10_ACCEPTANCE.md}"
allow_pending="${ALLOW_PENDING_ACCEPTANCE:-0}"

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

acceptance_column() {
    local id="$1"
    local column="$2"

    awk -F'|' -v id="$id" -v column="$column" '
        {
            key = $2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            if (key == id) {
                value = $column
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                print value
                exit
            }
        }
    ' "$acceptance_file"
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
    ' "$acceptance_file"
}

is_placeholder() {
    local value="$1"
    case "$value" in
        ""|"TBD"|"Pending"|"-"|"N/A")
            return 0
            ;;
    esac
    return 1
}

numeric_value() {
    awk '
        match($0, /[0-9]+([.][0-9]+)?/) {
            print substr($0, RSTART, RLENGTH)
            exit
        }
    ' <<< "$1"
}

require_metadata_number() {
    local field="$1"
    local label="$2"
    local value

    value="$(metadata_value "$field")"
    if is_placeholder "$value"; then
        return
    fi

    if [[ -z "$(numeric_value "$value")" ]]; then
        pending_items+=("metadata '$field' must include a numeric $label")
    fi
}

require_metadata_date() {
    local field="$1"
    local value

    value="$(metadata_value "$field")"
    if is_placeholder "$value"; then
        return
    fi

    if [[ ! "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        pending_items+=("metadata '$field' must use YYYY-MM-DD")
    fi
}

require_metadata_terms() {
    local field="$1"
    local label="$2"
    shift 2

    local value
    local normalized
    local term
    local missing_terms=()

    value="$(metadata_value "$field")"
    if is_placeholder "$value"; then
        return
    fi

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$value")"
    for term in "$@"; do
        if [[ "$normalized" != *"$term"* ]]; then
            missing_terms+=("$term")
        fi
    done

    if (( ${#missing_terms[@]} > 0 )); then
        pending_items+=("metadata '$field' must mention $label: ${missing_terms[*]}")
    fi
}

require_metadata_any_term() {
    local field="$1"
    local label="$2"
    shift 2

    local value
    local normalized
    local term

    value="$(metadata_value "$field")"
    if is_placeholder "$value"; then
        return
    fi

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$value")"
    for term in "$@"; do
        if [[ "$normalized" == *"$term"* ]]; then
            return
        fi
    done

    pending_items+=("metadata '$field' must mention $label: one of $*")
}

duration_ms_from_text() {
    local value="$1"
    local normalized

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$value")"
    if [[ "$normalized" =~ ([0-9]+([.][0-9]+)?)[[:space:]]*(ms|millisecond|milliseconds) ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi

    if [[ "$normalized" =~ ([0-9]+([.][0-9]+)?)[[:space:]]*(s|sec|secs|second|seconds) ]]; then
        awk -v value="${BASH_REMATCH[1]}" 'BEGIN { printf "%.3f\n", value * 1000 }'
        return 0
    fi

    return 1
}

require_evidence_duration_at_most() {
    local id="$1"
    local limit_ms="$2"
    local label="$3"
    local evidence
    local measured_ms

    evidence="$(acceptance_column "$id" 5)"
    if is_placeholder "$evidence"; then
        return
    fi

    if ! measured_ms="$(duration_ms_from_text "$evidence")"; then
        pending_items+=("$id evidence must include a measured $label duration in ms or seconds")
        return
    fi

    if ! awk -v actual="$measured_ms" -v limit="$limit_ms" 'BEGIN { exit(actual <= limit ? 0 : 1) }'; then
        pending_items+=("$id measured $label duration is ${measured_ms} ms, expected <= ${limit_ms} ms")
    fi
}

require_evidence_terms() {
    local id="$1"
    local label="$2"
    shift 2

    local evidence
    local normalized
    local term
    local missing_terms=()

    evidence="$(acceptance_column "$id" 5)"
    if is_placeholder "$evidence"; then
        return
    fi

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$evidence")"
    for term in "$@"; do
        if [[ "$normalized" != *"$term"* ]]; then
            missing_terms+=("$term")
        fi
    done

    if (( ${#missing_terms[@]} > 0 )); then
        pending_items+=("$id evidence must mention $label: ${missing_terms[*]}")
    fi
}

[[ -f "$acceptance_file" ]] || fail "missing acceptance file at $acceptance_file"

row_count="$(
    awk -F'|' '
        {
            key = $2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            if (key ~ /^A[0-9][0-9]$/) {
                count++
            }
        }
        END { print count + 0 }
    ' "$acceptance_file"
)"
[[ "$row_count" == "15" ]] || fail "expected exactly 15 real-device acceptance rows, found $row_count"

required_metadata=(
    "Device model"
    "iOS version"
    "Backend project"
    "Tester"
    "Date"
    "Release build"
    "Signed archive"
    "App Store validation"
)

required_ids=(
    "A01"
    "A02"
    "A03"
    "A04"
    "A05"
    "A06"
    "A07"
    "A08"
    "A09"
    "A10"
    "A11"
    "A12"
    "A13"
    "A14"
    "A15"
)

required_fragments=(
    "Cold launch reaches Home in under 1 second"
    "opens a live camera preview within 400 ms"
    "result sheet within 300 ms"
    "Analyze returns a name and price"
    "same platforms as"
    "only listing text on the clipboard"
    "Recent listing appears on Home immediately"
    "Swipe-to-delete removes the listing"
    "history persists (guest via SwiftData; signed-in via server)"
    "Reduce Motion in Settings reduces app-wide animation"
    "Dark mode keeps every screen readable"
    "landscape rotation keeps the app portrait"
    "VoiceOver can complete Home"
    "Airplane mode allows capture"
    "Sign in with Apple migrates guest history once"
)

required_marketplace_terms=(
    "27"
    "ebay"
    "craigslist"
    "facebook"
    "poshmark"
    "mercari"
    "offerup"
    "depop"
    "whatnot"
    "grailed"
    "reverb"
    "etsy"
    "stockx"
    "goat"
    "kidizen"
    "vinted"
    "vestiaire"
    "the realreal"
    "swappa"
    "tradesy"
    "chairish"
    "bonanza"
    "curtsy"
    "nextdoor"
    "amazon"
    "shopify"
    "ruby lane"
    "tcgplayer"
)

pending_items=()

for field in "${required_metadata[@]}"; do
    value="$(metadata_value "$field")"
    if is_placeholder "$value"; then
        pending_items+=("metadata '$field' is not recorded")
    fi
done

require_metadata_any_term "Device model" "a physical iPhone or iPad model" "iphone" "ipad"
require_metadata_number "iOS version" "iOS version"
require_metadata_date "Date"
require_metadata_number "Release build" "release build"
require_metadata_terms "Signed archive" "signed archive artifact" "archive"
require_metadata_any_term "App Store validation" "App Store validation proof" "validation" "validated" "altool" "app store" "ipa"

for index in "${!required_ids[@]}"; do
    id="${required_ids[$index]}"
    fragment="${required_fragments[$index]}"
    criterion="$(acceptance_column "$id" 3)"
    result="$(acceptance_column "$id" 4)"
    evidence="$(acceptance_column "$id" 5)"

    [[ -n "$criterion" ]] || fail "missing criterion row for $id"
    [[ "$criterion" == *"$fragment"* ]] || fail "$id criterion drifted; expected fragment '$fragment'"

    if [[ "$result" != "Pass" ]]; then
        pending_items+=("$id result is '$result', expected Pass")
    fi

    if is_placeholder "$evidence"; then
        pending_items+=("$id evidence is not recorded")
    fi
done

require_evidence_duration_at_most "A01" "1000" "cold-launch"
require_evidence_duration_at_most "A02" "400" "camera-ready"
require_evidence_duration_at_most "A03" "300" "capture-to-result"
require_evidence_terms "A01" "Home and no flicker proof" "home" "no flicker"
require_evidence_terms "A02" "camera preview proof" "camera" "preview"
require_evidence_terms "A03" "result sheet and thumbnail proof" "result sheet" "thumbnail"
require_evidence_terms "A04" "analyze item and price proof" "item" "price"
require_evidence_terms "A05" "marketplace list, payouts, Best, Lowest, and all 27 prompt platforms" "platform" "payout" "best" "lowest" "${required_marketplace_terms[@]}"
require_evidence_terms "A06" "clipboard listing text with no leading whitespace or preamble proof" "clipboard" "listing text" "no leading whitespace" "no preamble"
require_evidence_terms "A07" "Home recent listing thumbnail proof" "home" "thumbnail"
require_evidence_terms "A08" "swipe-to-delete and haptic proof" "swipe" "haptic"
require_evidence_terms "A09" "guest SwiftData and signed-in server relaunch persistence proof" "relaunch" "guest" "swiftdata" "signed" "server"
require_evidence_terms "A10" "Settings Reduce Motion app-wide animation proof" "settings" "reduce motion" "animation" "app-wide"
require_evidence_terms "A11" "dark mode contrast proof" "dark" "contrast"
require_evidence_terms "A12" "landscape portrait stability proof" "landscape" "portrait"
require_evidence_terms "A13" "VoiceOver full flow proof" "voiceover" "home" "camera" "result" "picker" "listing" "copy"
require_evidence_terms "A14" "Airplane mode offline toast and retry proof" "airplane" "offline" "you're offline. reconnect and try again." "retry"
require_evidence_terms "A15" "Sign in with Apple one-time migration and duplicate proof" "sign in with apple" "migration" "once" "duplicate"

if (( ${#pending_items[@]} > 0 )); then
    if [[ "$allow_pending" == "1" ]]; then
        printf 'M10 real-device acceptance pending:\n'
        printf ' - %s\n' "${pending_items[@]}"
        printf 'Record metadata, mark A01-A15 as Pass, add evidence notes, then rerun without ALLOW_PENDING_ACCEPTANCE=1.\n'
        exit 0
    fi

    printf 'error: M10 real-device acceptance incomplete:\n' >&2
    printf ' - %s\n' "${pending_items[@]}" >&2
    exit 1
fi

printf 'M10 real-device acceptance evidence passed\n'
printf 'file: %s\n' "$acceptance_file"
