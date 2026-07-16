#!/usr/bin/env bash
set -euo pipefail

acceptance_file="${1:-M10_ACCEPTANCE.md}"
allow_pending="${ALLOW_PENDING_M10:-0}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

full_result="${M10_FULL_XCRESULT:-/tmp/buysell-submit-readiness-full.xcresult}"
focused_result="${M10_FOCUSED_XCRESULT:-/tmp/buysell-submit-readiness-focused.xcresult}"
no_sign_archive="${M10_NOSIGN_ARCHIVE:-/tmp/buysell-submit-readiness-nosign.xcarchive}"
no_sign_log="${M10_NOSIGN_LOG:-/tmp/buysell-submit-readiness-nosign.log}"
signed_log="${M10_SIGNED_ARCHIVE_LOG:-/tmp/buysell-submit-readiness-signed-preflight.log}"
export_log="${M10_APP_STORE_EXPORT_LOG:-/tmp/buysell-submit-readiness-export-preflight.log}"
validation_log="${M10_APP_STORE_VALIDATION_LOG:-/tmp/buysell-submit-readiness-app-store-validation-preflight.log}"
real_device_log="${M10_REAL_DEVICE_LOG:-/tmp/buysell-submit-readiness-real-device-preflight.log}"
secret_log="${M10_SECRET_SCAN_LOG:-/tmp/buysell-submit-readiness-secret-scan.log}"
min_tests="${M10_MIN_TESTS:-284}"
min_focused_tests="${M10_MIN_FOCUSED_TESTS:-29}"

pending_items=()

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

pending() {
    pending_items+=("$*")
}

require_file_contains() {
    local file="$1"
    local expected="$2"
    local label="$3"

    if [[ ! -f "$file" ]]; then
        pending "$label is missing at $file"
        return
    fi

    if ! grep -Fq "$expected" "$file"; then
        pending "$label does not contain '$expected'"
    fi
}

require_directory() {
    local directory="$1"
    local label="$2"

    if [[ ! -d "$directory" ]]; then
        pending "$label is missing at $directory"
    fi
}

json_value() {
    local key="$1"
    awk -F' : ' -v key="\"${key}\"" '
        $1 ~ key {
            value = $2
            gsub(/[",]/, "", value)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            print value
            exit
        }
    '
}

require_xcresult_passed() {
    local result_path="$1"
    local minimum_count="$2"
    local label="$3"
    local summary
    local result
    local count

    if [[ ! -d "$result_path" ]]; then
        pending "$label result bundle is missing at $result_path"
        return
    fi

    if ! summary="$(xcrun xcresulttool get test-results summary --path "$result_path" --format json 2>/dev/null)"; then
        pending "$label result bundle could not be read by xcresulttool"
        return
    fi

    result="$(json_value result <<< "$summary")"
    count="$(json_value totalTestCount <<< "$summary")"

    if [[ "$result" != "Passed" ]]; then
        pending "$label result is '$result', expected Passed"
    fi

    if [[ -z "$count" || "$count" -lt "$minimum_count" ]]; then
        pending "$label has ${count:-0} tests, expected at least $minimum_count"
    fi
}

require_acceptance_evidence() {
    local output

    if ! output="$(bash "${script_dir}/verify_m10_real_device_acceptance.sh" "$acceptance_file" 2>&1)"; then
        pending "real-device acceptance evidence is incomplete: $(head -n 1 <<< "$output")"
    fi
}

require_submit_checkboxes() {
    local unchecked

    unchecked="$(
        awk '
            /^## Submit-Ready Gates/ { in_section = 1; next }
            /^## / && in_section { in_section = 0 }
            in_section && /^- \[ \]/ { count++ }
            END { print count + 0 }
        ' "$acceptance_file"
    )"

    if [[ "$unchecked" != "0" ]]; then
        pending "M10_ACCEPTANCE.md still has $unchecked unchecked Submit-Ready Gates"
    fi
}

require_result_log_final() {
    local pending_rows

    pending_rows="$(
        awk -F'|' '
            /^## Result Log/ { in_section = 1; next }
            /^## / && in_section { in_section = 0 }
            in_section {
                result = $7
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", result)
                if (result == "Pending" || result == "TBD") {
                    count++
                }
            }
            END { print count + 0 }
        ' "$acceptance_file"
    )"

    if [[ "$pending_rows" != "0" ]]; then
        pending "M10_ACCEPTANCE.md Result Log still has pending rows"
    fi
}

[[ -f "$acceptance_file" ]] || fail "missing acceptance file at $acceptance_file"

require_xcresult_passed "$full_result" "$min_tests" "full simulator suite"
require_xcresult_passed "$focused_result" "$min_focused_tests" "focused M10 preflight suite"
require_directory "$no_sign_archive" "no-sign Release archive"
require_file_contains "$no_sign_log" "M10 local archive check passed" "no-sign archive verifier log"
require_file_contains "$signed_log" "M10 signed archive preflight passed" "signed archive preflight log"
require_file_contains "$export_log" "M10 App Store export preflight passed" "App Store export preflight log"
require_file_contains "$validation_log" "M10 App Store validation preflight passed" "App Store validation preflight log"
require_file_contains "$real_device_log" "M10 real-device preflight passed" "real-device preflight log"
require_file_contains "$secret_log" "M10 secret scan passed" "secret scan log"
require_acceptance_evidence
require_submit_checkboxes
require_result_log_final

if (( ${#pending_items[@]} > 0 )); then
    if [[ "$allow_pending" == "1" ]]; then
        printf 'M10 submit readiness pending:\n'
        printf ' - %s\n' "${pending_items[@]}"
        printf 'Complete every signed archive, App Store, real-device, and evidence item, then rerun without ALLOW_PENDING_M10=1.\n'
        exit 0
    fi

    printf 'error: M10 submit readiness incomplete:\n' >&2
    printf ' - %s\n' "${pending_items[@]}" >&2
    exit 1
fi

printf 'M10 submit readiness passed\n'
printf 'acceptance: %s\n' "$acceptance_file"
printf 'full suite: %s\n' "$full_result"
printf 'focused suite: %s\n' "$focused_result"
printf 'archive: %s\n' "$no_sign_archive"
