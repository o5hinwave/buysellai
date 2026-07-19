#!/usr/bin/env bash
set -euo pipefail

project="${PROJECT:-BuySellAI.xcodeproj}"
scheme="${SCHEME:-BuySellAI}"
destination="${DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro}"
result_root="${M10_UI_RESULT_ROOT:-/tmp/buysell-m10-ui-tests}"
continue_on_failure="${M10_UI_CONTINUE_ON_FAILURE:-0}"
timeout_seconds="${M10_UI_TEST_TIMEOUT_SECONDS:-900}"
max_attempts="${M10_UI_MAX_ATTEMPTS:-2}"
source_root="$(pwd -P)"
snapshot_root="${M10_UI_SNAPSHOT_ROOT:-}"
xcodebuild_workdir="$source_root"

tests=(
    "BuySellAIUITests/BuySellAIUITests/testTutorialCanBeSkippedAndHappyPathCopiesListingWithUITestHooks"
    "BuySellAIUITests/BuySellAIUITests/testFirstLaunchTutorialAppearsOnce"
    "BuySellAIUITests/BuySellAIUITests/testSlowHistoryLoadDoesNotBlockHomeLaunch"
    "BuySellAIUITests/BuySellAIUITests/testHomeLaunchReachesPrimaryActionWithinSimulatorBudget"
    "BuySellAIUITests/BuySellAIUITests/testHomeHandlesFiveHundredRecentListingsAndScrolls"
    "BuySellAIUITests/BuySellAIUITests/testIPhonePortraitLockKeepsHomeUsableAfterLandscapeRotation"
    "BuySellAIUITests/BuySellAIUITests/testAccessibilityThreeHomeKeepsPrimaryActionReachable"
    "BuySellAIUITests/BuySellAIUITests/testCompactTutorialGetStartedDismisses"
    "BuySellAIUITests/BuySellAIUITests/testCompactTutorialDoesNotUseSwipeDrivenCarousel"
    "BuySellAIUITests/BuySellAIUITests/testHomeHowItWorksReopensTutorial"
    "BuySellAIUITests/BuySellAIUITests/testSettingsReopensHowItWorksTutorial"
    "BuySellAIUITests/BuySellAIUITests/testSettingsClearHistoryRequiresConfirmationAndRemovesRows"
    "BuySellAIUITests/BuySellAIUITests/testDeleteAccountRequiresTypedConfirmation"
    "BuySellAIUITests/BuySellAIUITests/testSwipeDeleteShowsConfirmationAndRemovesHistoryEntry"
    "BuySellAIUITests/BuySellAIUITests/testAnalyzeOfflineShowsToastAndRetryButton"
    "BuySellAIUITests/BuySellAIUITests/testCameraShutterOfflineAnalyzeShowsThumbnailToastAndRetryButton"
    "BuySellAIUITests/BuySellAIUITests/testCameraSampleCapturePresentsResultThumbnailWithinSimulatorBudget"
    "BuySellAIUITests/BuySellAIUITests/testCameraDeniedShowsSettingsFallbackAndCanClose"
    "BuySellAIUITests/BuySellAIUITests/testCameraReadyOverlayExposesAccessibleControls"
    "BuySellAIUITests/BuySellAIUITests/testCameraReadyOverlayAppearsWithinSimulatorBudget"
    "BuySellAIUITests/BuySellAIUITests/testVoiceOverCriticalPathLabelsStayUnambiguousThroughCopy"
    "BuySellAIUITests/BuySellAIUITests/testAuthCanBeDismissedAndGuestSnapStillWorks"
    "BuySellAIUITests/BuySellAIUITests/testAuthGuestEscapeRemainsReachableAtAccessibilityThree"
    "BuySellAIUITests/BuySellAIUITests/testGuestHistoryPersistsAfterCopyAndRelaunch"
    "BuySellAIUITests/BuySellAIUITests/testRecentListingReopensListingSheetDirectly"
    "BuySellAIUITests/BuySellAIUITests/testMarketplaceBestSummaryOpensListingSheetDirectly"
    "BuySellAIUITests/BuySellAIUITests/testListingRetakeKeepsMarketplaceAndSkipsPicker"
    "BuySellAIUITests/BuySellAIUITests/testCopyListingWritesOnlyListingTextToPasteboard"
    "BuySellAIUITests/BuySellAIUITests/testGenerateListingOfflineShowsToastAndRegenerateButton"
    "BuySellAIUITests/BuySellAIUITests/testSettingsThemeAndReduceMotionPersistAcrossRelaunch"
    "BuySellAIUITests/BuySellAIUITests/testDarkModeSellFlowReachesCopyListing"
    "BuySellAIUITests/BuySellAIUITests/testM10AppStoreScreenshotsCanBeCaptured"
)

if [[ -n "${M10_UI_TESTS:-}" ]]; then
    tests=()
    while IFS= read -r test_id; do
        [[ -n "$test_id" ]] || continue
        tests+=("$test_id")
    done <<< "$M10_UI_TESTS"
fi

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
        *) fail "M10_UI_SNAPSHOT_ROOT must be under /tmp" ;;
    esac
    [[ "$target" != "$source_root" ]] || fail "M10_UI_SNAPSHOT_ROOT must not point at the source checkout"

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

    rsync -a "${entries[@]}" "$target/"
    xcodebuild_workdir="$target"
    snapshot_root="$target"
}

append_summary() {
    printf '%s\n' "$*" >> "$summary_log"
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

is_retryable_failure() {
    local log_file="$1"

    grep -Eq \
        "Simulator device failed to launch|Application failed preflight checks|BSErrorCodeDescription = Busy|Invalid connectionUUID|Failed to install or launch the test runner|waiting for workers to materialize|IDEInstalliPhoneSimulatorWorker|IDELaunchiPhoneSimulatorLauncher|Blocking finish to allow restarting of crashed test operations|timed out after [0-9]+ seconds" \
        "$log_file"
}

run_xcodebuild_attempt() {
    local test_id="$1"
    local result_bundle="$2"
    local log_file="$3"
    local status
    local pid
    local started_at
    local now
    local elapsed
    local timed_out

    timed_out=0
    rm -rf "$result_bundle"
    : > "$log_file"

    set +e
    (
        cd "$xcodebuild_workdir"
        xcodebuild -quiet test \
            -project "$project" \
            -scheme "$scheme" \
            -destination "$destination" \
            -parallel-testing-enabled NO \
            -maximum-concurrent-test-simulator-destinations 1 \
            -only-testing:"$test_id" \
            -resultBundlePath "$result_bundle"
    ) \
        > "$log_file" 2>&1 &
    pid="$!"

    if [[ "$timeout_seconds" -gt 0 ]]; then
        started_at="$(date +%s)"
        while kill -0 "$pid" 2>/dev/null; do
            now="$(date +%s)"
            elapsed=$(( now - started_at ))
            if [[ "$elapsed" -ge "$timeout_seconds" ]]; then
                timed_out=1
                printf 'error: timed out after %s seconds\n' "$timeout_seconds" >> "$log_file"
                kill -TERM "$pid" 2>/dev/null
                sleep 5
                kill -KILL "$pid" 2>/dev/null
                break
            fi
            sleep 5
        done
    fi

    wait "$pid"
    status="$?"
    set -e

    if [[ "$timed_out" == "1" ]]; then
        status=124
        printf 'error: timed out after %s seconds\n' "$timeout_seconds" >> "$log_file"
    fi

    if [[ "$status" -eq 0 && ! -d "$result_bundle" ]]; then
        printf 'error: missing result bundle after xcodebuild success\n' >> "$log_file"
        status=66
    fi

    return "$status"
}

run_test() {
    local test_id="$1"
    local safe_name
    local result_bundle
    local log_file
    local status
    local attempt

    safe_name="$(safe_test_name "$test_id")"
    result_bundle="${result_root}/${safe_name}.xcresult"
    log_file="${result_root}/${safe_name}.log"

    append_summary "test: $test_id"
    append_summary "result bundle: $result_bundle"
    append_summary "log: $log_file"
    printf 'RUN %s\n' "$test_id"

    status=1
    for (( attempt = 1; attempt <= max_attempts; attempt++ )); do
        append_summary "attempt: $attempt/$max_attempts"
        set +e
        run_xcodebuild_attempt "$test_id" "$result_bundle" "$log_file"
        status="$?"
        set -e

        if [[ "$status" -eq 0 ]]; then
            break
        fi

        if [[ "$attempt" -lt "$max_attempts" ]] && { [[ "$status" -eq 124 ]] || is_retryable_failure "$log_file"; }; then
            printf 'RETRY %s after simulator launch failure (attempt %s/%s)\n' "$test_id" "$attempt" "$max_attempts" >&2
            append_summary "retrying test: $test_id"
            sleep 10
            continue
        fi

        break
    done

    append_summary "status: $status"
    if [[ "$status" -eq 0 ]]; then
        append_summary "passed test: $test_id"
        printf 'PASS %s\n' "$test_id"
        return 0
    fi

    append_summary "failed test: $test_id"
    printf 'FAIL %s (status %s)\n' "$test_id" "$status" >&2
    tail -n 80 "$log_file" >&2 || true
    return "$status"
}

[[ "$timeout_seconds" =~ ^[0-9]+$ ]] || fail "M10_UI_TEST_TIMEOUT_SECONDS must be a whole number"
[[ "$max_attempts" =~ ^[0-9]+$ ]] || fail "M10_UI_MAX_ATTEMPTS must be a whole number"
[[ "$max_attempts" -ge 1 ]] || fail "M10_UI_MAX_ATTEMPTS must be at least 1"
[[ "${#tests[@]}" -gt 0 ]] || fail "no UI tests were configured"
prepare_snapshot "$snapshot_root"

mkdir -p "$result_root"
summary_log="${result_root}/summary.log"
: > "$summary_log"

append_summary "M10 UI chunked tests started"
append_summary "project: $project"
append_summary "scheme: $scheme"
append_summary "destination: $destination"
append_summary "source root: $source_root"
append_summary "xcodebuild workdir: $xcodebuild_workdir"
if [[ -n "$snapshot_root" ]]; then
    append_summary "snapshot root: $snapshot_root"
fi
append_summary "tests: ${#tests[@]}"
append_summary "timeout seconds: $timeout_seconds"
append_summary "max attempts: $max_attempts"

failures=()
for test_id in "${tests[@]}"; do
    if run_test "$test_id"; then
        continue
    fi

    failures+=("$test_id")
    if [[ "$continue_on_failure" != "1" ]]; then
        break
    fi
done

if [[ "${#failures[@]}" -gt 0 ]]; then
    append_summary "M10 UI chunked tests failed"
    append_summary "failed tests: ${#failures[@]}"
    for test_id in "${failures[@]}"; do
        append_summary "failed test: $test_id"
    done
    printf 'M10 UI chunked tests failed\n' >&2
    printf 'summary: %s\n' "$summary_log" >&2
    exit 1
fi

append_summary "M10 UI chunked tests passed"
printf 'M10 UI chunked tests passed\n'
printf 'summary: %s\n' "$summary_log"
