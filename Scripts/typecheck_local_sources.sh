#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

sdk_path="$(xcrun --sdk iphonesimulator --show-sdk-path)"
developer_dir="$(xcode-select -p)"
simulator_developer_dir="${developer_dir}/Platforms/iPhoneSimulator.platform/Developer"
module_dir="${BUYSELL_TYPECHECK_MODULE_DIR:-${TMPDIR:-/tmp}/buysell-local-typecheck-module}"
target_triple="${BUYSELL_TYPECHECK_TARGET:-arm64-apple-ios17.0-simulator}"

case "$module_dir" in
    ""|"/"|".")
        printf 'error: unsafe BUYSELL_TYPECHECK_MODULE_DIR: %s\n' "$module_dir" >&2
        exit 1
        ;;
    /*)
        ;;
    *)
        printf 'error: BUYSELL_TYPECHECK_MODULE_DIR must be absolute: %s\n' "$module_dir" >&2
        exit 1
        ;;
esac

case "$module_dir" in
    "$repo_root"|"$repo_root"/*)
        printf 'error: BUYSELL_TYPECHECK_MODULE_DIR must be outside the repository: %s\n' "$module_dir" >&2
        exit 1
        ;;
esac

rm -rf "$module_dir"
mkdir -p "$module_dir"

app_sources=()
unit_test_sources=()
ui_test_sources=()

while IFS= read -r source_file; do
    app_sources+=("$source_file")
done < <(rg --files BuySellAI -g '*.swift' | sort)

while IFS= read -r source_file; do
    unit_test_sources+=("$source_file")
done < <(rg --files BuySellAITests -g '*.swift' | sort)

while IFS= read -r source_file; do
    ui_test_sources+=("$source_file")
done < <(rg --files BuySellAIUITests -g '*.swift' | sort)

swift_common=(
    -swift-version 5
    -target "$target_triple"
    -sdk "$sdk_path"
    -enable-testing
)

swift_debug=(
    "${swift_common[@]}"
    -D DEBUG
)

xctest_imports=(
    -F "${simulator_developer_dir}/Library/Frameworks"
    -I "${simulator_developer_dir}/usr/lib"
    -I "$module_dir"
)

xcrun swiftc -emit-module \
    -module-name BuySellAIRelease \
    -emit-module-path "${module_dir}/BuySellAIRelease.swiftmodule" \
    "${swift_common[@]}" \
    -parse-as-library \
    "${app_sources[@]}"

xcrun swiftc -emit-module \
    -module-name BuySellAI \
    -emit-module-path "${module_dir}/BuySellAI.swiftmodule" \
    "${swift_debug[@]}" \
    -parse-as-library \
    "${app_sources[@]}"

xcrun swiftc -typecheck \
    "${swift_debug[@]}" \
    "${xctest_imports[@]}" \
    "${unit_test_sources[@]}"

xcrun swiftc -typecheck \
    "${swift_debug[@]}" \
    "${xctest_imports[@]}" \
    "${ui_test_sources[@]}"

printf 'BuySellAI local source typecheck passed\n'
printf 'swift module: %s\n' "$module_dir"
printf 'target: %s\n' "$target_triple"
printf 'sdk: %s\n' "$sdk_path"
printf 'sources: app unit ui\n'
printf 'modes: release app debug app unit ui\n'
