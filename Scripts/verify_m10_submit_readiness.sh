#!/usr/bin/env bash
set -euo pipefail

acceptance_file="${1:-M10_ACCEPTANCE.md}"
allow_pending="${ALLOW_PENDING_M10:-0}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
head_epoch="$(git -C "$repo_root" log -1 --format=%ct 2>/dev/null || printf '0')"

full_result="${M10_FULL_XCRESULT:-/tmp/buysell-submit-readiness-full.xcresult}"
focused_result="${M10_FOCUSED_XCRESULT:-/tmp/buysell-submit-readiness-focused.xcresult}"
no_sign_archive="${M10_NOSIGN_ARCHIVE:-/tmp/buysell-submit-readiness-nosign.xcarchive}"
signed_archive="${M10_SIGNED_ARCHIVE:-/tmp/BuySellAI-signed.xcarchive}"
app_store_archive="${M10_APP_STORE_ARCHIVE:-/tmp/BuySellAI-appstore.xcarchive}"
app_store_export="${M10_APP_STORE_EXPORT:-/tmp/BuySellAI-appstore-export}"
app_store_metadata="${M10_APP_STORE_METADATA:-M10_APP_STORE_METADATA.md}"
instruments_evidence="${M10_INSTRUMENTS_EVIDENCE:-M10_INSTRUMENTS.md}"
no_sign_log="${M10_NOSIGN_LOG:-/tmp/buysell-submit-readiness-nosign.log}"
signed_log="${M10_SIGNED_ARCHIVE_LOG:-/tmp/buysell-submit-readiness-signed-preflight.log}"
export_log="${M10_APP_STORE_EXPORT_LOG:-/tmp/buysell-submit-readiness-export-preflight.log}"
validation_log="${M10_APP_STORE_VALIDATION_LOG:-/tmp/buysell-submit-readiness-app-store-validation-preflight.log}"
metadata_log="${M10_APP_STORE_METADATA_LOG:-/tmp/buysell-submit-readiness-app-store-metadata.log}"
backend_log="${M10_BACKEND_LOG:-/tmp/buysell-submit-readiness-backend.log}"
real_device_log="${M10_REAL_DEVICE_LOG:-/tmp/buysell-submit-readiness-real-device-preflight.log}"
secret_log="${M10_SECRET_SCAN_LOG:-/tmp/buysell-submit-readiness-secret-scan.log}"
performance_log="${M10_PERFORMANCE_LOG:-/tmp/buysell-submit-readiness-performance.log}"
instruments_log="${M10_INSTRUMENTS_LOG:-/tmp/buysell-submit-readiness-instruments.log}"
min_tests="${M10_MIN_TESTS:-304}"
min_focused_tests="${M10_MIN_FOCUSED_TESTS:-60}"
required_focused_tests=(
    "ArchivePackagingScriptTests/testLocalArchiveVerifierEnforcesPromptPackageGates()"
    "SignedArchivePreflightScriptTests/testSignedArchivePreflightProducesSignedArchiveWhenTeamIsConfigured()"
    "AppStoreExportPreflightScriptTests/testAppStoreExportPreflightChecksExportedIPAContents()"
    "AppStoreValidationPreflightScriptTests/testAppStoreValidationPreflightChecksPrivacyManifestContents()"
    "RealDevicePreflightScriptTests/testRealDeviceAcceptanceVerifierParsesTimingEvidenceInMillisecondsOrSeconds()"
    "M10PerformanceEvidenceScriptTests/testPerformanceEvidenceScriptRequiresFullSuiteAndNamedBudgetTests()"
    "M10InstrumentsEvidenceScriptTests/testInstrumentsEvidenceScriptEnforcesPromptBudgets()"
    "M10BackendPreflightScriptTests/testBackendPreflightScriptValidatesConfigAndCallsRequiredSupabaseRoutes()"
    "M10AppStoreMetadataScriptTests/testMetadataVerifierRequiresConcreteAppStoreConnectSubmissionFields()"
    "M10SubmitReadinessScriptTests/testSubmitReadinessScriptAggregatesAllM10EvidenceGates()"
    "ConfigSecurityTests/testRuntimeConfigRejectsProviderSecretShapedAnonKeys()"
    "SigningCapabilityTests/testAppTargetBuildConfigurationsUseEntitlementsAndAutomaticSigning()"
)

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

artifact_mtime() {
    local path="$1"

    stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null
}

require_fresh_artifact() {
    local path="$1"
    local label="$2"
    local mtime

    if [[ ! -e "$path" ]] || [[ "$head_epoch" == "0" ]]; then
        return 0
    fi

    if ! mtime="$(artifact_mtime "$path")"; then
        pending "$label freshness could not be checked at $path"
        return
    fi

    if [[ "$mtime" -lt "$head_epoch" ]]; then
        pending "$label is older than the current HEAD commit"
    fi
}

require_fresh_pass_log() {
    local file="$1"
    local pass_marker="$2"
    local label="$3"

    if [[ ! -f "$file" ]] || ! grep -Fq "$pass_marker" "$file"; then
        return 0
    fi

    require_fresh_artifact "$file" "$label"
}

marker_value() {
    local file="$1"
    local marker="$2"

    [[ -f "$file" ]] || return 1
    awk -v marker="$marker" '
        index($0, marker) == 1 {
            value = substr($0, length(marker) + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            print value
            exit
        }
    ' "$file"
}

markdown_metadata_value() {
    local file="$1"
    local field="$2"

    [[ -f "$file" ]] || return 1
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

require_same_marker_value() {
    local source_file="$1"
    local source_marker="$2"
    local source_label="$3"
    local target_file="$4"
    local target_marker="$5"
    local target_label="$6"
    local evidence_label="$7"
    local source_value
    local target_value

    source_value="$(marker_value "$source_file" "$source_marker" || true)"
    target_value="$(marker_value "$target_file" "$target_marker" || true)"

    [[ -n "$source_value" && -n "$target_value" ]] || return 0

    if [[ "$source_value" != "$target_value" ]]; then
        pending "$evidence_label mismatch: $source_label has '$source_value', $target_label has '$target_value'"
    fi
}

require_metadata_references_marker_value() {
    local metadata_file="$1"
    local metadata_field="$2"
    local log_file="$3"
    local marker="$4"
    local log_label="$5"
    local evidence_label="$6"
    local metadata
    local marker_path

    metadata="$(markdown_metadata_value "$metadata_file" "$metadata_field" || true)"
    marker_path="$(marker_value "$log_file" "$marker" || true)"

    [[ -n "$metadata" && -n "$marker_path" ]] || return 0
    is_placeholder_value "$metadata" && return 0

    if [[ "$metadata" != *"$marker_path"* ]]; then
        pending "$evidence_label mismatch: $metadata_file metadata '$metadata_field' must reference '$marker_path' from $log_label"
    fi
}

require_metadata_matches_marker_value() {
    local metadata_file="$1"
    local metadata_field="$2"
    local log_file="$3"
    local marker="$4"
    local log_label="$5"
    local evidence_label="$6"
    local metadata
    local marker_text

    metadata="$(markdown_metadata_value "$metadata_file" "$metadata_field" || true)"
    marker_text="$(marker_value "$log_file" "$marker" || true)"

    [[ -n "$metadata" && -n "$marker_text" ]] || return 0
    is_placeholder_value "$metadata" && return 0

    if [[ "$metadata" != "$marker_text" ]]; then
        pending "$evidence_label mismatch: $metadata_file metadata '$metadata_field' is '$metadata', $log_label has '$marker_text'"
    fi
}

require_same_metadata_value() {
    local source_file="$1"
    local source_field="$2"
    local source_label="$3"
    local target_file="$4"
    local target_field="$5"
    local target_label="$6"
    local evidence_label="$7"
    local source_value
    local target_value

    source_value="$(markdown_metadata_value "$source_file" "$source_field" || true)"
    target_value="$(markdown_metadata_value "$target_file" "$target_field" || true)"

    [[ -n "$source_value" && -n "$target_value" ]] || return 0
    is_placeholder_value "$source_value" && return 0
    is_placeholder_value "$target_value" && return 0

    if [[ "$source_value" != "$target_value" ]]; then
        pending "$evidence_label mismatch: $source_label metadata '$source_field' is '$source_value', $target_label metadata '$target_field' is '$target_value'"
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

trim() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

is_placeholder_value() {
    local value

    value="$(trim "$1")"
    case "$value" in
        ""|"TBD"|"Pending"|"-"|"N/A")
            return 0
            ;;
    esac
    return 1
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

require_xcresult_contains_tests() {
    local result_path="$1"
    local label="$2"
    local tests_json
    local test_id

    if [[ ! -d "$result_path" ]]; then
        return
    fi

    if ! tests_json="$(xcrun xcresulttool get test-results tests --path "$result_path" --format json 2>/dev/null)"; then
        pending "$label result bundle tests could not be read by xcresulttool"
        return
    fi

    for test_id in "${required_focused_tests[@]}"; do
        if ! grep -Fq "\"nodeIdentifier\" : \"${test_id}\"" <<< "$tests_json"; then
            pending "$label is missing required test $test_id"
        fi
    done
}

require_acceptance_evidence() {
    local output

    if ! output="$(bash "${script_dir}/verify_m10_real_device_acceptance.sh" "$acceptance_file" 2>&1)"; then
        pending "real-device acceptance evidence is incomplete: $(head -n 1 <<< "$output")"
    fi
}

require_app_store_metadata_evidence() {
    local output

    if ! output="$(bash "${script_dir}/verify_m10_app_store_metadata.sh" "$app_store_metadata" 2>&1)"; then
        pending "App Store metadata evidence is incomplete: $(head -n 1 <<< "$output")"
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
    local rows=0
    local pass_rows=0
    local metadata_matched_rows=0
    local incomplete_rows=0
    local normalized_notes
    local missing_note_evidence
    local row
    local date
    local tester
    local device
    local ios
    local backend
    local result
    local notes
    local field_name
    local field_value
    local field_index
    local metadata_date
    local metadata_tester
    local metadata_device
    local metadata_ios
    local metadata_backend

    metadata_date="$(markdown_metadata_value "$acceptance_file" "Date" || true)"
    metadata_tester="$(markdown_metadata_value "$acceptance_file" "Tester" || true)"
    metadata_device="$(markdown_metadata_value "$acceptance_file" "Device model" || true)"
    metadata_ios="$(markdown_metadata_value "$acceptance_file" "iOS version" || true)"
    metadata_backend="$(markdown_metadata_value "$acceptance_file" "Backend project" || true)"

    while IFS='|' read -r _ date tester device ios backend result notes _; do
        date="$(trim "$date")"
        tester="$(trim "$tester")"
        device="$(trim "$device")"
        ios="$(trim "$ios")"
        backend="$(trim "$backend")"
        result="$(trim "$result")"
        notes="$(trim "$notes")"

        [[ "$date" == "Date" || "$date" == "---" || -z "$date" ]] && continue

        rows=$((rows + 1))
        row="Result Log row $rows"

        field_index=0
        for field_value in "$date" "$tester" "$device" "$ios" "$backend" "$result" "$notes"; do
            case "$field_index" in
                0) field_name="Date" ;;
                1) field_name="Tester" ;;
                2) field_name="Device" ;;
                3) field_name="iOS" ;;
                4) field_name="Backend" ;;
                5) field_name="Result" ;;
                6) field_name="Notes" ;;
            esac

            if is_placeholder_value "$field_value"; then
                pending "M10_ACCEPTANCE.md $row has placeholder $field_name"
                incomplete_rows=$((incomplete_rows + 1))
            fi
            field_index=$((field_index + 1))
        done

        if [[ "$result" == "Pass" ]]; then
            pass_rows=$((pass_rows + 1))
            normalized_notes="$(tr '[:upper:]' '[:lower:]' <<< "$notes")"
            missing_note_evidence=()

            if ! is_placeholder_value "$metadata_date" \
                && ! is_placeholder_value "$metadata_tester" \
                && ! is_placeholder_value "$metadata_device" \
                && ! is_placeholder_value "$metadata_ios" \
                && ! is_placeholder_value "$metadata_backend" \
                && [[ "$date" == "$metadata_date" ]] \
                && [[ "$tester" == "$metadata_tester" ]] \
                && [[ "$device" == *"$metadata_device"* ]] \
                && [[ "$ios" == "$metadata_ios" ]] \
                && [[ "$backend" == "$metadata_backend" ]]; then
                metadata_matched_rows=$((metadata_matched_rows + 1))
            fi

            if [[ "$normalized_notes" != *"signed"* || "$normalized_notes" != *"archive"* ]]; then
                missing_note_evidence+=("signed archive")
            fi

            if [[ "$normalized_notes" != *"organizer"* && "$normalized_notes" != *"archive validation"* ]]; then
                missing_note_evidence+=("Xcode Organizer signed archive validation")
            fi

            if [[ "$normalized_notes" != *"app store"* || "$normalized_notes" != *"validation"* ]]; then
                missing_note_evidence+=("App Store validation")
            fi

            if [[ "$normalized_notes" != *"real-device"* && "$normalized_notes" != *"real device"* ]]; then
                missing_note_evidence+=("real-device acceptance")
            fi

            if [[ "$normalized_notes" != *"instruments"* ]]; then
                missing_note_evidence+=("Instruments evidence")
            fi

            if (( ${#missing_note_evidence[@]} > 0 )); then
                pending "M10_ACCEPTANCE.md $row Notes must mention final evidence: ${missing_note_evidence[*]}"
                incomplete_rows=$((incomplete_rows + 1))
            fi
        else
            pending "M10_ACCEPTANCE.md $row result is '$result', expected Pass"
            incomplete_rows=$((incomplete_rows + 1))
        fi
    done < <(
        awk '
            /^## Result Log/ { in_section = 1; next }
            /^## / && in_section { in_section = 0 }
            in_section && /^\|/ { print }
        ' "$acceptance_file"
    )

    if [[ "$rows" == "0" ]]; then
        pending "M10_ACCEPTANCE.md Result Log needs at least one completed Pass row"
    fi

    if [[ "$pass_rows" == "0" ]]; then
        pending "M10_ACCEPTANCE.md Result Log has no completed Pass row"
    fi

    if [[ "$pass_rows" != "0" ]] \
        && ! is_placeholder_value "$metadata_date" \
        && ! is_placeholder_value "$metadata_tester" \
        && ! is_placeholder_value "$metadata_device" \
        && ! is_placeholder_value "$metadata_ios" \
        && ! is_placeholder_value "$metadata_backend" \
        && [[ "$metadata_matched_rows" == "0" ]]; then
        pending "M10_ACCEPTANCE.md Result Log needs a Pass row matching recorded Date, Tester, Device model, iOS version, and Backend project metadata"
    fi

    if [[ "$incomplete_rows" != "0" ]]; then
        pending "M10_ACCEPTANCE.md Result Log still has pending rows"
    fi
}

[[ -f "$acceptance_file" ]] || fail "missing acceptance file at $acceptance_file"
[[ -f "$app_store_metadata" ]] || pending "App Store metadata evidence file is missing at $app_store_metadata"

require_xcresult_passed "$full_result" "$min_tests" "full simulator suite"
require_xcresult_passed "$focused_result" "$min_focused_tests" "focused M10 preflight suite"
require_xcresult_contains_tests "$focused_result" "focused M10 preflight suite"
require_directory "$no_sign_archive" "no-sign Release archive"
require_directory "$signed_archive" "signed Release archive"
require_directory "$app_store_archive" "App Store Connect archive"
require_directory "$app_store_export" "App Store export directory"
require_fresh_artifact "$full_result" "full simulator suite result bundle"
require_fresh_artifact "$focused_result" "focused M10 preflight result bundle"
require_fresh_artifact "$no_sign_archive" "no-sign Release archive"
require_fresh_artifact "$signed_archive" "signed Release archive"
require_fresh_artifact "$app_store_archive" "App Store Connect archive"
require_fresh_artifact "$app_store_export" "App Store export directory"
require_file_contains "$no_sign_log" "M10 local archive check passed" "no-sign archive verifier log"
require_file_contains "$no_sign_log" "archive: $no_sign_archive" "no-sign archive verifier log"
require_file_contains "$no_sign_log" "bundle id: com.rhodes.buysellai" "no-sign archive verifier log"
require_file_contains "$no_sign_log" "release build:" "no-sign archive verifier log"
require_file_contains "$no_sign_log" "app icon:" "no-sign archive verifier log"
require_file_contains "$no_sign_log" "app size:" "no-sign archive verifier log"
require_file_contains "$signed_log" "M10 signed archive preflight passed" "signed archive preflight log"
require_file_contains "$signed_log" "archive: $signed_archive" "signed archive preflight log"
require_file_contains "$signed_log" "bundle id: com.rhodes.buysellai" "signed archive preflight log"
require_file_contains "$signed_log" "sign in with apple: Default" "signed archive preflight log"
require_file_contains "$signed_log" "release build:" "signed archive preflight log"
require_file_contains "$export_log" "M10 App Store export preflight passed" "App Store export preflight log"
require_file_contains "$export_log" "archive: $app_store_archive" "App Store export preflight log"
require_file_contains "$export_log" "export: $app_store_export" "App Store export preflight log"
require_file_contains "$export_log" "ipa:" "App Store export preflight log"
require_file_contains "$export_log" "bundle id: com.rhodes.buysellai" "App Store export preflight log"
require_file_contains "$export_log" "sign in with apple: Default" "App Store export preflight log"
require_file_contains "$export_log" "release build:" "App Store export preflight log"
require_file_contains "$validation_log" "M10 App Store validation preflight passed" "App Store validation preflight log"
require_file_contains "$validation_log" "ipa:" "App Store validation preflight log"
require_file_contains "$validation_log" "bundle id: com.rhodes.buysellai" "App Store validation preflight log"
require_file_contains "$validation_log" "sign in with apple: Default" "App Store validation preflight log"
require_file_contains "$validation_log" "release build:" "App Store validation preflight log"
require_file_contains "$metadata_log" "M10 App Store metadata evidence passed" "App Store metadata evidence log"
require_file_contains "$metadata_log" "file: $app_store_metadata" "App Store metadata evidence log"
require_file_contains "$metadata_log" "app name: BuySell AI" "App Store metadata evidence log"
require_file_contains "$metadata_log" "bundle id: com.rhodes.buysellai" "App Store metadata evidence log"
require_file_contains "$metadata_log" "version:" "App Store metadata evidence log"
require_file_contains "$metadata_log" "privacy policy:" "App Store metadata evidence log"
require_file_contains "$metadata_log" "support:" "App Store metadata evidence log"
require_file_contains "$metadata_log" "screenshots:" "App Store metadata evidence log"
require_file_contains "$metadata_log" "screenshot directory:" "App Store metadata evidence log"
require_file_contains "$metadata_log" "screenshot files: 4" "App Store metadata evidence log"
require_file_contains "$metadata_log" "screenshot dimensions: 1206x2622" "App Store metadata evidence log"
require_file_contains "$metadata_log" "app privacy:" "App Store metadata evidence log"
require_same_marker_value "$export_log" "ipa:" "App Store export preflight log" "$validation_log" "ipa:" "App Store validation preflight log" "validated IPA"
require_same_marker_value "$no_sign_log" "bundle id:" "no-sign archive verifier log" "$signed_log" "bundle id:" "signed archive preflight log" "signed bundle id"
require_same_marker_value "$signed_log" "bundle id:" "signed archive preflight log" "$export_log" "bundle id:" "App Store export preflight log" "exported bundle id"
require_same_marker_value "$export_log" "bundle id:" "App Store export preflight log" "$validation_log" "bundle id:" "App Store validation preflight log" "validated bundle id"
require_same_marker_value "$signed_log" "sign in with apple:" "signed archive preflight log" "$export_log" "sign in with apple:" "App Store export preflight log" "Sign in with Apple entitlement"
require_same_marker_value "$export_log" "sign in with apple:" "App Store export preflight log" "$validation_log" "sign in with apple:" "App Store validation preflight log" "validated Sign in with Apple entitlement"
require_same_marker_value "$no_sign_log" "release build:" "no-sign archive verifier log" "$signed_log" "release build:" "signed archive preflight log" "signed release build"
require_same_marker_value "$signed_log" "release build:" "signed archive preflight log" "$export_log" "release build:" "App Store export preflight log" "exported release build"
require_same_marker_value "$export_log" "release build:" "App Store export preflight log" "$validation_log" "release build:" "App Store validation preflight log" "validated release build"
require_file_contains "$backend_log" "M10 backend preflight passed" "backend preflight log"
require_file_contains "$backend_log" "config:" "backend preflight log"
require_file_contains "$backend_log" "project:" "backend preflight log"
require_file_contains "$backend_log" "functions: analyze-image generate-listing" "backend preflight log"
require_file_contains "$backend_log" "analyze item:" "backend preflight log"
require_file_contains "$backend_log" "listing bytes:" "backend preflight log"
require_metadata_references_marker_value "$acceptance_file" "Signed archive" "$signed_log" "archive:" "signed archive preflight log" "signed archive metadata"
require_metadata_references_marker_value "$acceptance_file" "Signed archive validation" "$signed_log" "archive:" "signed archive preflight log" "signed archive validation metadata"
require_metadata_references_marker_value "$acceptance_file" "App Store validation" "$validation_log" "ipa:" "App Store validation preflight log" "App Store validation metadata"
require_metadata_matches_marker_value "$acceptance_file" "Release build" "$signed_log" "release build:" "signed archive preflight log" "acceptance release build metadata"
require_file_contains "$real_device_log" "M10 real-device preflight passed" "real-device preflight log"
require_file_contains "$real_device_log" "device:" "real-device preflight log"
require_file_contains "$real_device_log" "device name:" "real-device preflight log"
require_file_contains "$real_device_log" "device id:" "real-device preflight log"
require_file_contains "$real_device_log" "app:" "real-device preflight log"
require_file_contains "$real_device_log" "bundle id: com.rhodes.buysellai" "real-device preflight log"
require_file_contains "$real_device_log" "sign in with apple: Default" "real-device preflight log"
require_file_contains "$real_device_log" "release build:" "real-device preflight log"
require_same_marker_value "$signed_log" "bundle id:" "signed archive preflight log" "$real_device_log" "bundle id:" "real-device preflight log" "real-device bundle id"
require_same_marker_value "$signed_log" "sign in with apple:" "signed archive preflight log" "$real_device_log" "sign in with apple:" "real-device preflight log" "real-device Sign in with Apple entitlement"
require_same_marker_value "$signed_log" "release build:" "signed archive preflight log" "$real_device_log" "release build:" "real-device preflight log" "real-device release build"
require_metadata_references_marker_value "$acceptance_file" "Device model" "$real_device_log" "device name:" "real-device preflight log" "acceptance device metadata"
require_file_contains "$secret_log" "M10 secret scan self-test passed" "secret scan log"
require_file_contains "$secret_log" "M10 secret scan passed" "secret scan log"
require_file_contains "$performance_log" "M10 performance evidence passed" "performance evidence log"
require_file_contains "$performance_log" "full suite: $full_result" "performance evidence log"
require_file_contains "$performance_log" "archive log: $no_sign_log" "performance evidence log"
require_file_contains "$performance_log" "bundle id: com.rhodes.buysellai" "performance evidence log"
require_file_contains "$performance_log" "release build:" "performance evidence log"
require_file_contains "$performance_log" "performance tests:" "performance evidence log"
require_file_contains "$performance_log" "app size:" "performance evidence log"
require_same_marker_value "$no_sign_log" "bundle id:" "no-sign archive verifier log" "$performance_log" "bundle id:" "performance evidence log" "performance bundle id"
require_same_marker_value "$no_sign_log" "release build:" "no-sign archive verifier log" "$performance_log" "release build:" "performance evidence log" "performance release build"
require_file_contains "$instruments_log" "M10 Instruments evidence passed" "Instruments evidence log"
require_file_contains "$instruments_log" "file: $instruments_evidence" "Instruments evidence log"
require_fresh_pass_log "$no_sign_log" "M10 local archive check passed" "no-sign archive verifier log"
require_fresh_pass_log "$signed_log" "M10 signed archive preflight passed" "signed archive preflight log"
require_fresh_pass_log "$export_log" "M10 App Store export preflight passed" "App Store export preflight log"
require_fresh_pass_log "$validation_log" "M10 App Store validation preflight passed" "App Store validation preflight log"
require_fresh_pass_log "$metadata_log" "M10 App Store metadata evidence passed" "App Store metadata evidence log"
require_fresh_pass_log "$backend_log" "M10 backend preflight passed" "backend preflight log"
require_fresh_pass_log "$real_device_log" "M10 real-device preflight passed" "real-device preflight log"
require_fresh_pass_log "$secret_log" "M10 secret scan passed" "secret scan log"
require_fresh_pass_log "$performance_log" "M10 performance evidence passed" "performance evidence log"
require_fresh_pass_log "$instruments_log" "M10 Instruments evidence passed" "Instruments evidence log"
require_metadata_references_marker_value "$instruments_evidence" "Signed archive" "$signed_log" "archive:" "signed archive preflight log" "Instruments signed archive metadata"
require_metadata_references_marker_value "$instruments_evidence" "Device model" "$real_device_log" "device name:" "real-device preflight log" "Instruments device metadata"
require_metadata_matches_marker_value "$instruments_evidence" "Release build" "$signed_log" "release build:" "signed archive preflight log" "Instruments release build metadata"
require_same_metadata_value "$acceptance_file" "iOS version" "acceptance" "$instruments_evidence" "iOS version" "Instruments" "M10 physical-device iOS version"
require_same_metadata_value "$acceptance_file" "Release build" "acceptance" "$instruments_evidence" "Release build" "Instruments" "M10 physical-device release build"
require_app_store_metadata_evidence
require_acceptance_evidence
require_submit_checkboxes
require_result_log_final

if (( ${#pending_items[@]} > 0 )); then
    if [[ "$allow_pending" == "1" ]]; then
        printf 'M10 submit readiness pending:\n'
        printf ' - %s\n' "${pending_items[@]}"
        printf 'Complete every signed archive, App Store, backend, real-device, and evidence item, then rerun without ALLOW_PENDING_M10=1.\n'
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
printf 'metadata: %s\n' "$app_store_metadata"
