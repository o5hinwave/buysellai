#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

entrypoints=(
    "supabase/functions/backend-health/index.ts"
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
"${deno_cmd[@]}" test --allow-env supabase/functions/_shared/entitlements_test.ts supabase/functions/_shared/gemini_test.ts

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
    "supabase/functions/backend-health/index.ts" \
    "requiredMigrations" \
    "backend health required migration marker"
require_source_contains \
    "supabase/functions/backend-health/index.ts" \
    "daily_analysis_limit: 18" \
    "backend health early-access analysis limit"
require_source_contains \
    "supabase/functions/backend-health/index.ts" \
    "daily_ai_action_limit: 54" \
    "backend health early-access AI action limit"
require_source_contains \
    "supabase/functions/backend-health/index.ts" \
    "SUPABASE_SERVICE_ROLE_KEY" \
    "backend health server-side entitlement query"
require_source_contains \
    "supabase/functions/_shared/entitlements.ts" \
    "consumeEarlyAccessUsage" \
    "shared early-access usage gate"
require_source_contains \
    "supabase/functions/_shared/entitlements.ts" \
    "entitlement_config" \
    "server-controlled entitlement config"
require_source_contains \
    "supabase/functions/_shared/entitlements.ts" \
    "entitlement_usage_events" \
    "privacy-conscious usage event storage"
require_source_contains \
    "supabase/functions/_shared/entitlements.ts" \
    "x-buysell-device-id" \
    "per-device abuse protection header"
require_source_contains \
    "supabase/functions/analyze-image/index.ts" \
    'consumeEarlyAccessUsage(request, "analysis"' \
    "analyze early-access usage gate"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    'consumeEarlyAccessUsage(request, "marketplace_research"' \
    "marketplace research early-access usage gate"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    'consumeEarlyAccessUsage(request, "listing_generation"' \
    "listing early-access usage gate"
require_source_contains \
    "supabase/functions/_shared/http.ts" \
    "x-buysell-device-id" \
    "early-access device header CORS"
require_source_contains \
    "supabase/functions/_shared/gemini.ts" \
    "attachGroundingMetadata" \
    "Gemini grounding metadata capture"
require_source_contains \
    "supabase/functions/_shared/gemini.ts" \
    "shouldRetryGeminiJson" \
    "Gemini malformed JSON retry guard"
require_source_contains \
    "supabase/functions/_shared/gemini.ts" \
    "The previous provider response was not valid JSON for the app contract." \
    "Gemini retry repair instruction"
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
    "return jsonResponse({ listing, draft, entitlement })" \
    "structured draft response"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "cleanEvidenceSources(result.evidenceSources, platform)" \
    "structured evidence source validation"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "const soldPrices = soldEvidencePrices(evidenceSources)" \
    "listing sold comp source price collection"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "const compLowPrice = hasPricedSoldCompEvidence ? lowEvidencePrice(soldPrices) : null" \
    "listing sold comp source-derived low price"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "const compMedianPrice = hasPricedSoldCompEvidence ? medianEvidencePrice(soldPrices) : null" \
    "listing sold comp source-derived median price"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "function soldEvidencePrices(sources: StructuredEvidenceSource[]): number[]" \
    "listing sold evidence price derivation helper"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "evidenceSummary: listingEvidenceSummaryForDisplay(" \
    "listing evidence summary grounded display guard"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "no verified sold comps for this final listing" \
    "listing active-only evidence limitation copy"
require_source_not_contains \
    "supabase/functions/generate-listing/index.ts" \
    "optionalPositiveNumber(result.compLowPrice) ?? priorCompLowPrice" \
    "model-provided listing comp low fallback"
require_source_not_contains \
    "supabase/functions/generate-listing/index.ts" \
    "evidenceSummary: optionalCleanDraftText(result.evidenceSummary, 260) ?? priorComparison?.evidenceSummary ?? null" \
    "direct listing evidence summary fallback"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "function listingStatusFromPriceFields(record: Record<string, unknown>): string | null" \
    "listing source status inference"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "function isSoldEvidenceSource(source: StructuredEvidenceSource): boolean" \
    "listing sold evidence predicate"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "detailsForPrompt(details, platform)" \
    "selected-marketplace seller detail prompt"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "marketplaceNotes: optionalMarketplaceNotes(details.marketplaceNotes)" \
    "marketplace-specific seller notes"
require_source_contains \
    "supabase/functions/analyze-image/index.ts" \
    "fetchVisionWebDetectionEvidence(imageDataUrl)" \
    "analyze image visual web detection"
require_source_contains \
    "supabase/functions/analyze-image/index.ts" \
    "GOOGLE_CLOUD_VISION_API_KEY" \
    "analyze image Google Vision secret"
require_source_contains \
    "supabase/functions/analyze-image/index.ts" \
    "WEB_DETECTION" \
    "analyze image web detection feature"
require_source_contains \
    "supabase/functions/analyze-image/index.ts" \
    "analysis.referenceImages" \
    "analyze image reference image contract"
require_source_contains \
    "supabase/functions/analyze-image/index.ts" \
    "Do not ask generic catch-all questions" \
    "analyze image adaptive question specificity instruction"
require_source_contains \
    "supabase/functions/analyze-image/index.ts" \
    "isSpecificAdaptiveQuestion(question, reason, choices, unknownFollowUpQuestion, unknownFollowUpChoices)" \
    "analyze image adaptive question specificity guard"
require_source_contains \
    "supabase/functions/analyze-image/index.ts" \
    "adaptiveQuestionValueScore(searchableText) >= 2" \
    "analyze image adaptive question value scoring guard"
require_source_contains \
    "supabase/functions/analyze-image/index.ts" \
    "isButtonSizedAdaptiveChoice" \
    "analyze image button-sized choice guard"
require_source_contains \
    "supabase/functions/analyze-image/index.ts" \
    "identification checking only" \
    "reference images identification-only instruction"
require_source_contains \
    "supabase/functions/analyze-image/index.ts" \
    "normalizeReferenceImages" \
    "reference image sanitizer"
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
    "compLowPrice: hasPricedSoldEvidence ? lowPrice(soldEvidencePrices) : null" \
    "marketplace compare sold comp source-derived guard"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "Active listings and asking prices may appear in evidenceSources, but they must never populate sold comp price fields." \
    "marketplace compare active asking price exclusion"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "return soldEvidenceCount > 0 ? \"grounded\" : \"limited\"" \
    "marketplace compare grounded requires sold evidence guard"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "function listingStatusFromPriceFields(record: Record<string, unknown>): string | null" \
    "marketplace compare source status inference"
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
    "await saveComparisonResearchCache(item, details, identificationProfile, result, comparisons)" \
    "marketplace compare research cache save"
require_source_contains \
    "supabase/functions/compare-marketplaces/index.ts" \
    "Item identification profile" \
    "profile-aware marketplace compare prompt"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "identificationProfileForPrompt(identificationProfile)" \
    "profile-aware listing prompt"
require_source_contains \
    "supabase/functions/generate-listing/index.ts" \
    "const profileKey = normalizedIdentifier(profileSearchTerms(identificationProfile).join(\" \")).slice(0, 90) || \"noprofile\"" \
    "profile-aware listing cache key"
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
printf 'functions: backend-health analyze-image compare-marketplaces generate-listing store-apple-token delete-account\n'
printf 'listing research tools: google_search url_context gated-by-cache\n'
printf 'marketplace compare: grounded candidate search before picker recommendation\n'
printf 'marketplace compare cache: grounded findings saved for listing reuse\n'
printf 'listing research cache: Gemini grounding saved\n'
printf 'listing draft: structured fields formatted deterministically\n'
printf 'listing evidence sources: sold-comp guarded structured source/date/status/comparability\n'
printf 'early access: server-controlled entitlements with usage protection\n'
