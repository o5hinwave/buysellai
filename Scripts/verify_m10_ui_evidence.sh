#!/usr/bin/env bash
set -euo pipefail

result_root="${1:-${M10_UI_RESULT_ROOT:-/tmp/buysell-m10-ui-tests}}"
ui_test_source="${M10_UI_TEST_SOURCE:-BuySellAIUITests/BuySellAIUITests.swift}"
min_tests="${M10_MIN_UI_TESTS:-32}"
summary_log="${result_root}/summary.log"

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

safe_test_name() {
    local test_id="$1"
    local safe_name

    safe_name="$test_id"
    safe_name="${safe_name//\//_}"
    safe_name="${safe_name//(/_}"
    safe_name="${safe_name//)/_}"
    safe_name="${safe_name// /_}"
    printf '%s' "$safe_name"
}

require_summary_line() {
    local expected="$1"

    grep -Fqx "$expected" "$summary_log" || fail "UI summary does not contain '$expected'"
}

expected_tests=()
[[ -f "$ui_test_source" ]] || fail "missing UI test source at $ui_test_source"
while IFS= read -r test_id; do
    [[ -n "$test_id" ]] || continue
    expected_tests+=("$test_id")
done < <(
    sed -nE 's/^[[:space:]]*func (test[A-Za-z0-9_]+)\(\)( throws)?[[:space:]]*\{.*/BuySellAIUITests\/BuySellAIUITests\/\1/p' "$ui_test_source"
)

[[ "${#expected_tests[@]}" -ge "$min_tests" ]] || fail "found ${#expected_tests[@]} UI tests, expected at least $min_tests"
[[ -d "$result_root" ]] || fail "missing chunked UI result root at $result_root"
[[ -f "$summary_log" ]] || fail "missing chunked UI summary at $summary_log"

require_summary_line "tests: ${#expected_tests[@]}"
require_summary_line "M10 UI chunked tests passed"

status_count="$(grep -Fc "status: 0" "$summary_log")"
passed_count="$(grep -Fc "passed test:" "$summary_log")"
[[ "$status_count" -eq "${#expected_tests[@]}" ]] || fail "UI summary has $status_count passing statuses, expected ${#expected_tests[@]}"
[[ "$passed_count" -eq "${#expected_tests[@]}" ]] || fail "UI summary has $passed_count passed-test rows, expected ${#expected_tests[@]}"

for test_id in "${expected_tests[@]}"; do
    safe_name="$(safe_test_name "$test_id")"
    result_bundle="${result_root}/${safe_name}.xcresult"
    node_identifier="BuySellAIUITests/${test_id##*/}()"

    require_summary_line "test: $test_id"
    require_summary_line "result bundle: $result_bundle"
    require_summary_line "log: ${result_root}/${safe_name}.log"
    require_summary_line "passed test: $test_id"
    [[ -d "$result_bundle" ]] || fail "missing result bundle for $test_id at $result_bundle"

    summary="$(xcrun xcresulttool get test-results summary --path "$result_bundle" --format json 2>/dev/null)" || fail "could not read result summary for $test_id"
    result="$(json_value result <<< "$summary")"
    test_count="$(json_value totalTestCount <<< "$summary")"
    [[ "$result" == "Passed" ]] || fail "$test_id result is '$result', expected Passed"
    [[ "$test_count" == "1" ]] || fail "$test_id bundle has ${test_count:-0} tests, expected 1"

    tests_json="$(xcrun xcresulttool get test-results tests --path "$result_bundle" --format json 2>/dev/null)" || fail "could not read result tests for $test_id"
    grep -Fq "\"nodeIdentifier\" : \"${node_identifier}\"" <<< "$tests_json" || fail "$test_id bundle is missing node identifier $node_identifier"
done

printf 'M10 UI evidence passed\n'
printf 'summary: %s\n' "$summary_log"
printf 'result root: %s\n' "$result_root"
printf 'tests: %s\n' "${#expected_tests[@]}"
for test_id in "${expected_tests[@]}"; do
    printf 'test: %s\n' "$test_id"
done
