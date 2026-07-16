#!/usr/bin/env bash
set -euo pipefail

result_path="${1:-${M10_PERFORMANCE_XCRESULT:-/tmp/buysell-submit-readiness-full.xcresult}}"
archive_log="${2:-${M10_PERFORMANCE_ARCHIVE_LOG:-/tmp/buysell-submit-readiness-nosign.log}}"
min_tests="${M10_MIN_TESTS:-300}"
max_app_size_kb="${M10_MAX_APP_SIZE_KB:-20480}"

required_tests=(
    "BuySellAIUITests/testHomeLaunchReachesPrimaryActionWithinSimulatorBudget()"
    "BuySellAIUITests/testCameraReadyOverlayAppearsWithinSimulatorBudget()"
    "BuySellAIUITests/testCameraSampleCapturePresentsResultThumbnailWithinSimulatorBudget()"
    "BuySellAIUITests/testSlowHistoryLoadDoesNotBlockHomeLaunch()"
    "BuySellAIUITests/testHomeHandlesFiveHundredRecentListingsAndScrolls()"
)

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
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

require_passed_test() {
    local test_id="$1"
    local tests_json="$2"

    if ! awk -v test_id="\"nodeIdentifier\" : \"${test_id}\"" '
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
        fail "required performance test did not pass: $test_id"
    fi
}

marker_value() {
    local marker="$1"
    local file="$2"

    awk -v marker="$marker" '
        index($0, marker) == 1 {
            value = substr($0, length(marker) + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            print value
            exit
        }
    ' "$file"
}

[[ -d "$result_path" ]] || fail "missing full-suite result bundle at $result_path"
[[ -f "$archive_log" ]] || fail "missing no-sign archive verifier log at $archive_log"

summary="$(xcrun xcresulttool get test-results summary --path "$result_path" --format json)"
tests_json="$(xcrun xcresulttool get test-results tests --path "$result_path" --format json)"

result="$(json_value result <<< "$summary")"
count="$(json_value totalTestCount <<< "$summary")"

[[ "$result" == "Passed" ]] || fail "full-suite result is '$result', expected Passed"
[[ -n "$count" && "$count" -ge "$min_tests" ]] || fail "full suite has ${count:-0} tests, expected at least $min_tests"

for test_id in "${required_tests[@]}"; do
    require_passed_test "$test_id" "$tests_json"
done

grep -Fq "M10 local archive check passed" "$archive_log" || fail "archive log does not prove the local archive verifier passed"

bundle_id="$(marker_value "bundle id:" "$archive_log")"
release_build="$(marker_value "release build:" "$archive_log")"
[[ "$bundle_id" == "com.rhodes.buysellai" ]] || fail "archive log does not include BuySell bundle id"
[[ -n "$release_build" ]] || fail "archive log does not include release build"

app_size_kb="$(
    awk '
        /^app size:/ {
            size = $3
            sub(/KB$/, "", size)
            print size
            exit
        }
    ' "$archive_log"
)"

[[ -n "$app_size_kb" ]] || fail "archive log does not include app size"
[[ "$app_size_kb" -le "$max_app_size_kb" ]] || fail "app bundle is ${app_size_kb}KB, above ${max_app_size_kb}KB"

printf 'M10 performance evidence passed\n'
printf 'full suite: %s\n' "$result_path"
printf 'archive log: %s\n' "$archive_log"
printf 'bundle id: %s\n' "$bundle_id"
printf 'release build: %s\n' "$release_build"
printf 'performance tests: %s\n' "${#required_tests[@]}"
printf 'app size: %sKB / %sKB\n' "$app_size_kb" "$max_app_size_kb"
