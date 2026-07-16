#!/usr/bin/env bash
set -euo pipefail

evidence_file="${1:-M10_INSTRUMENTS.md}"
allow_pending="${ALLOW_PENDING_INSTRUMENTS:-0}"
evidence_dir=""

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

table_column() {
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
    ' "$evidence_file"
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
    ' "$evidence_file"
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

require_max_metric() {
    local field="$1"
    local limit="$2"
    local unit="$3"
    local value
    local number

    value="$(metadata_value "$field")"
    if is_placeholder "$value"; then
        pending_items+=("metadata '$field' is not recorded")
        return
    fi

    number="$(numeric_value "$value")"
    if [[ -z "$number" ]]; then
        pending_items+=("metadata '$field' does not include a numeric $unit value")
        return
    fi

    if ! awk -v actual="$number" -v limit="$limit" 'BEGIN { exit(actual <= limit ? 0 : 1) }'; then
        pending_items+=("metadata '$field' is ${number}${unit}, expected <= ${limit}${unit}")
    fi
}

require_scroll_evidence() {
    local value
    local number

    value="$(metadata_value "Home scroll FPS")"
    if is_placeholder "$value"; then
        pending_items+=("metadata 'Home scroll FPS' is not recorded")
        return
    fi

    if [[ "$value" == *"no dropped"* || "$value" == *"No dropped"* ]]; then
        return
    fi

    number="$(numeric_value "$value")"
    if [[ -z "$number" ]]; then
        pending_items+=("metadata 'Home scroll FPS' must include 120 fps evidence or a no dropped frames note")
        return
    fi

    if ! awk -v actual="$number" 'BEGIN { exit(actual >= 120 ? 0 : 1) }'; then
        pending_items+=("metadata 'Home scroll FPS' is ${number} fps, expected >= 120 or no dropped frames")
    fi
}

require_trace_metadata() {
    local field="$1"
    local value
    local trace_path

    value="$(metadata_value "$field")"
    if is_placeholder "$value"; then
        pending_items+=("metadata '$field' is not recorded")
        return
    fi

    trace_path="$value"
    if [[ "$trace_path" != /* ]]; then
        trace_path="${evidence_dir}/${trace_path}"
    fi

    if [[ ! -e "$trace_path" ]]; then
        pending_items+=("metadata '$field' retained trace path does not exist: $value")
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

    evidence="$(table_column "$id" 5)"
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

require_evidence_any_term() {
    local id="$1"
    local label="$2"
    shift 2

    local evidence
    local normalized
    local term

    evidence="$(table_column "$id" 5)"
    if is_placeholder "$evidence"; then
        return
    fi

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$evidence")"
    for term in "$@"; do
        if [[ "$normalized" == *"$term"* ]]; then
            return
        fi
    done

    pending_items+=("$id evidence must mention $label: one of $*")
}

[[ -f "$evidence_file" ]] || fail "missing Instruments evidence file at $evidence_file"
evidence_dir="$(cd "$(dirname "$evidence_file")" && pwd)"

row_count="$(
    awk -F'|' '
        {
            key = $2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            if (key ~ /^P[0-9][0-9]$/) {
                count++
            }
        }
        END { print count + 0 }
    ' "$evidence_file"
)"
[[ "$row_count" == "5" ]] || fail "expected exactly 5 Instruments evidence rows, found $row_count"

required_metadata=(
    "Device model"
    "iOS version"
    "Release build"
    "Signed archive"
    "Tester"
    "Date"
)

required_ids=(
    "P01"
    "P02"
    "P03"
    "P04"
    "P05"
)

required_fragments=(
    "Cold launch reaches Home in under 900 ms"
    "opens a live camera preview within 400 ms"
    "sustains 120 fps"
    "Home steady-state memory stays under 120 MB"
    "Time Profiler and Allocations traces are recorded"
)

pending_items=()

for field in "${required_metadata[@]}"; do
    value="$(metadata_value "$field")"
    if is_placeholder "$value"; then
        pending_items+=("metadata '$field' is not recorded")
    fi
done

require_trace_metadata "Time Profiler trace"
require_trace_metadata "Allocations trace"
require_max_metric "Home launch duration" "900" " ms"
require_max_metric "Camera ready duration" "400" " ms"
require_scroll_evidence
require_max_metric "Home steady memory" "120" " MB"

for index in "${!required_ids[@]}"; do
    id="${required_ids[$index]}"
    fragment="${required_fragments[$index]}"
    criterion="$(table_column "$id" 3)"
    result="$(table_column "$id" 4)"
    evidence="$(table_column "$id" 5)"

    [[ -n "$criterion" ]] || fail "missing criterion row for $id"
    [[ "$criterion" == *"$fragment"* ]] || fail "$id criterion drifted; expected fragment '$fragment'"

    if [[ "$result" != "Pass" ]]; then
        pending_items+=("$id result is '$result', expected Pass")
    fi

    if is_placeholder "$evidence"; then
        pending_items+=("$id evidence is not recorded")
    fi
done

require_evidence_terms "P01" "Home launch timing proof" "home" "launch" "ms"
require_evidence_terms "P02" "camera preview timing proof" "camera" "preview" "ms"
require_evidence_terms "P03" "scroll frame-rate proof" "scroll"
require_evidence_any_term "P03" "scroll frame-rate proof" "fps" "no dropped"
require_evidence_terms "P04" "memory allocation proof" "memory" "mb"
require_evidence_terms "P05" "retained profiling trace proof" "time profiler" "allocations" "trace"

if (( ${#pending_items[@]} > 0 )); then
    if [[ "$allow_pending" == "1" ]]; then
        printf 'M10 Instruments evidence pending:\n'
        printf ' - %s\n' "${pending_items[@]}"
        printf 'Record Time Profiler and Allocations traces, mark P01-P05 as Pass, add evidence notes, then rerun without ALLOW_PENDING_INSTRUMENTS=1.\n'
        exit 0
    fi

    printf 'error: M10 Instruments evidence incomplete:\n' >&2
    printf ' - %s\n' "${pending_items[@]}" >&2
    exit 1
fi

printf 'M10 Instruments evidence passed\n'
printf 'file: %s\n' "$evidence_file"
