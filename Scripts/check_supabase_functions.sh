#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

entrypoints=(
    "supabase/functions/analyze-image/index.ts"
    "supabase/functions/compare-marketplaces/index.ts"
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

require_source_not_contains() {
    local file="$1"
    local forbidden="$2"
    local label="$3"

    if grep -Fq "$forbidden" "$file"; then
        printf 'error: %s still contains %s\n' "$file" "$label" >&2
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
    "const tools: GeminiTool[] = input.usesCachedResearch ? [] : [" \
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
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "requireStructuredListingDraft" \
    "structured listing draft validation"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "formatListingDraft" \
    "deterministic listing formatting"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "return jsonResponse({ listing, draft })" \
    "structured draft response"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "cleanEvidenceSources(result.evidenceSources, platform)" \
    "structured evidence source validation"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "detailsForPrompt(details, platform)" \
    "selected-marketplace seller detail prompt"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "marketplaceNotes: optionalMarketplaceNotes(details.marketplaceNotes)" \
    "marketplace-specific seller notes"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "{ google_search: {} }" \
    "marketplace compare Google Search tool"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "{ url_context: {} }" \
    "marketplace compare URL Context tool"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "Prioritize sold/completed listing evidence over active asking prices." \
    "sold-comps-first marketplace compare instruction"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "Do not invent sold listings, prices, fees, dates, demand, restrictions, or source URLs." \
    "no-invented marketplace evidence instruction"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "candidateMarketplaces" \
    "minimal marketplace candidate input"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "marketplaceNoteSummary(details.marketplaceNotes)" \
    "marketplace-note comparison context"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "await saveComparisonResearchCache(item, details, result, comparisons)" \
    "marketplace compare research cache save"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "marketplace_research_cache?on_conflict=cache_key" \
    "marketplace compare research cache upsert"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "result[geminiGroundingSearchQueriesKey]" \
    "marketplace compare saved Gemini grounding queries"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "result[geminiGroundingSourcesKey]" \
    "marketplace compare saved Gemini grounding sources"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "SUPABASE_SERVICE_ROLE_KEY" \
    "marketplace compare service-role cache access"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "For every factual market result you rely on, add one evidenceSources object" \
    "structured evidence source instruction"
require_source_not_contains \
    "supabase/functions/generate-listing/index.ts" \
    "List at:" \
    "copyable listing price-plan rows"
require_source_not_contains \
    "supabase/functions/generate-listing/index.ts" \
    "Main photo:" \
    "copyable listing photo guidance rows"

printf 'Supabase function Deno check passed\n'
printf 'functions: analyze-image compare-marketplaces generate-listing store-apple-token delete-account\n'
printf 'listing research tools: google_search url_context gated-by-cache\n'
printf 'marketplace compare: grounded candidate search before picker recommendation\n'
printf 'marketplace compare cache: grounded findings saved for listing reuse\n'
printf 'listing research cache: Gemini grounding saved\n'
printf 'listing draft: structured fields formatted deterministically\n'
printf 'listing evidence sources: structured source/date/status/comparability\n'
