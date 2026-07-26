#!/usr/bin/env bash
set -euo pipefail

allow_pending="${ALLOW_DATALLESS_WORKSPACE:-0}"
expect_support_site="${M10_EXPECT_SUPPORT_SITE:-1}"
max_tree_examples="${M10_MATERIALIZATION_MAX_EXAMPLES:-12}"
git_check_timeout_seconds="${M10_GIT_CHECK_TIMEOUT:-20}"

case "$max_tree_examples" in
    ''|*[!0-9]*)
        max_tree_examples=12
        ;;
esac

if (( max_tree_examples < 1 )); then
    max_tree_examples=1
fi

case "$git_check_timeout_seconds" in
    ''|*[!0-9]*)
        git_check_timeout_seconds=20
        ;;
esac

if (( git_check_timeout_seconds < 1 )); then
    git_check_timeout_seconds=20
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
cd "$repo_root"

pending_items=()

pending() {
    pending_items+=("$*")
}

path_has_dataless_flag() {
    local path="$1"

    ls -ldO "$path" 2>/dev/null | grep -q 'dataless'
}

git_with_timeout() {
    env LC_ALL=C LANG=C perl -e 'alarm shift @ARGV; exec @ARGV' \
        "$git_check_timeout_seconds" \
        git -c core.fsmonitor=false "$@"
}

materialize_if_dataless() {
    local path="$1"

    path_has_dataless_flag "$path" || return 0
    [[ -f "$path" ]] || return 0

    cat "$path" >/dev/null 2>&1 || return 0
}

check_not_dataless() {
    local path="$1"
    local label="$2"

    if [[ ! -e "$path" ]]; then
        pending "$label is missing at $path"
        return
    fi

    materialize_if_dataless "$path"

    if path_has_dataless_flag "$path"; then
        pending "$label is dataless and must be materialized before release verification: $path"
    fi
}

check_text_readable() {
    local path="$1"
    local label="$2"
    local line_count

    check_not_dataless "$path" "$label"
    [[ -f "$path" ]] || return

    if ! line_count="$(awk 'END { print NR + 0 }' "$path" 2>/dev/null)"; then
        pending "$label could not be read at $path"
        return
    fi

    if [[ "$line_count" == "0" ]]; then
        pending "$label read as zero lines at $path"
    fi
}

check_png_dimensions() {
    local path="$1"
    local expected_width="$2"
    local expected_height="$3"
    local label="$4"
    local metadata

    check_not_dataless "$path" "$label"
    [[ -f "$path" ]] || return

    if ! metadata="$(sips -g pixelWidth -g pixelHeight "$path" 2>/dev/null)"; then
        pending "$label could not be inspected as a PNG at $path"
        return
    fi

    if ! grep -Fq "pixelWidth: $expected_width" <<< "$metadata" \
        || ! grep -Fq "pixelHeight: $expected_height" <<< "$metadata"; then
        pending "$label dimensions are not ${expected_width}x${expected_height} at $path"
    fi
}

check_tree_not_dataless() {
    local root="$1"
    local label="$2"
    local path
    local count=0
    local shown=0

    [[ -e "$root" ]] || {
        pending "$label is missing at $root"
        return
    }

    while IFS= read -r -d '' path; do
        materialize_if_dataless "$path"

        if path_has_dataless_flag "$path"; then
            count=$((count + 1))
            if (( shown < max_tree_examples )); then
                pending "$label contains dataless file: $path"
                shown=$((shown + 1))
            fi
        fi
    done < <(find "$root" -type f -print0)

    if (( count > max_tree_examples )); then
        pending "$label contains $count dataless files under $root (showing first $shown)"
    fi
}

check_git_head_resolves() {
    if ! git_with_timeout rev-parse --verify HEAD >/dev/null 2>&1; then
        pending "git HEAD could not be resolved; fetch or repair the checkout before release verification"
    fi
}

check_text_readable ".git/HEAD" "git HEAD"
check_text_readable ".git/config" "git config"
if [[ -f ".git/refs/heads/main" ]]; then
    check_text_readable ".git/refs/heads/main" "git main ref"
fi
check_git_head_resolves
check_text_readable "README.md" "README"
check_text_readable "M10_ACCEPTANCE.md" "M10 acceptance checklist"
check_text_readable "M10_APP_STORE_METADATA.md" "App Store metadata evidence"
check_text_readable "M10_TODAY_FEATURE_NOMINATION.md" "Today feature nomination package"
check_text_readable "Scripts/verify_m10_submit_readiness.sh" "M10 submit-readiness verifier"
check_text_readable "Scripts/verify_m10_app_store_metadata.sh" "App Store metadata verifier"
check_text_readable "Scripts/verify_m10_today_feature_nomination.sh" "Today feature nomination verifier"

check_tree_not_dataless "BuySellAI" "app source tree"
check_tree_not_dataless "BuySellAITests" "unit test tree"
check_tree_not_dataless "BuySellAIUITests" "UI test tree"
check_tree_not_dataless "supabase" "Supabase source tree"
if [[ "$expect_support_site" == "1" ]]; then
    check_tree_not_dataless "AppStoreSite/app" "support-site app source tree"
    check_tree_not_dataless "AppStoreSite/public" "support-site public asset tree"
fi

for device in iPhone-16-Pro-Max iPad-Pro-13-inch-M4; do
    case "$device" in
        iPhone-16-Pro-Max)
            width=1320
            height=2868
            ;;
        iPad-Pro-13-inch-M4)
            width=2064
            height=2752
            ;;
    esac

    for name in 01-home 02-result 03-marketplaces 04-listing; do
        check_png_dimensions "AppStoreAssets/Screenshots/$device/$name.png" "$width" "$height" "$device screenshot $name"
    done
done

if ! git_with_timeout status --short >/dev/null 2>&1; then
    pending "git status could not index the worktree; materialize dataless tracked files before release verification"
fi

if (( ${#pending_items[@]} > 0 )); then
    if [[ "$allow_pending" == "1" ]]; then
        printf 'M10 workspace materialization pending:\n'
        printf ' - %s\n' "${pending_items[@]}"
        printf 'Materialize every listed file, then rerun without ALLOW_DATALLESS_WORKSPACE=1 before App Store readiness verification.\n'
        exit 0
    fi

    printf 'error: M10 workspace materialization incomplete:\n' >&2
    printf ' - %s\n' "${pending_items[@]}" >&2
    exit 1
fi

printf 'M10 workspace materialization passed\n'
printf 'git: status can index worktree\n'
if [[ "$expect_support_site" == "1" ]]; then
    printf 'sources: app unit ui supabase support-site\n'
else
    printf 'sources: app unit ui supabase\n'
    printf 'support-site: external Sites project\n'
fi
printf 'screenshots: iPhone 6.9 1320x2868, iPad 13 2064x2752\n'
printf 'docs: README M10 acceptance metadata Today nomination\n'
