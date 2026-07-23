#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

entrypoints=(
    "supabase/functions/analyze-image/index.ts"
    "supabase/functions/generate-listing/index.ts"
    "supabase/functions/store-apple-token/index.ts"
    "supabase/functions/delete-account/index.ts"
)

deno_cmd=()
if [[ -n "${DENO_BIN:-}" ]]; then
    deno_cmd=("$DENO_BIN")
elif command -v deno >/dev/null 2>&1; then
    deno_cmd=(deno)
elif command -v npx >/dev/null 2>&1; then
    deno_cmd=(npx --yes deno)
else
    printf 'error: deno or npx is required to type-check Supabase functions\n' >&2
    exit 1
fi

export DENO_DIR="${DENO_DIR:-${TMPDIR:-/tmp}/buysell-deno-cache}"

"${deno_cmd[@]}" check "${entrypoints[@]}"

require_source_contains() {
    local file="$1"
    local expected="$2"
    local label="$3"

    if ! grep -Fq "$expected" "$file"; then
        printf 'error: %s is missing %s\n' "$file" "$label" >&2
        exit 1
    fi
}

require_source_contains \
    "supabase/functions/_shared/gemini.ts" \
    "attachGroundingMetadata" \
    "Gemini grounding metadata capture"
require_source_contains \
    "supabase/functions/_shared/gemini.ts" \
    "geminiGroundingSearchQueriesKey" \
    "Gemini search query marker export"
require_source_contains \
    "supabase/functions/_shared/gemini.ts" \
    "geminiGroundingSourcesKey" \
    "Gemini grounding source marker export"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "tools: usesCachedResearch ? [] : [" \
    "cached-research tool gating"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "{ google_search: {} }" \
    "minimal Google Search tool"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "{ url_context: {} }" \
    "minimal URL Context tool"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "result[geminiGroundingSearchQueriesKey]" \
    "saved Gemini grounding queries"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "result[geminiGroundingSourcesKey]" \
    "saved Gemini grounding sources"

printf 'Supabase function Deno check passed\n'
printf 'functions: analyze-image generate-listing store-apple-token delete-account\n'
printf 'listing research tools: google_search url_context gated-by-cache\n'
printf 'listing research cache: Gemini grounding saved\n'
