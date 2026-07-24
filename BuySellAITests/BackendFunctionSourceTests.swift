import Foundation
import XCTest
@testable import BuySellAI

final class BackendFunctionSourceTests: XCTestCase {
    func testSupabaseFunctionSourcesExistForAllAppRoutes() throws {
        for path in [
            "supabase/config.toml",
            "supabase/functions/analyze-image/index.ts",
            "supabase/functions/compare-marketplaces/index.ts",
            "supabase/functions/generate-listing/index.ts",
            "supabase/functions/store-apple-token/index.ts",
            "supabase/functions/delete-account/index.ts",
            "supabase/functions/_shared/apple.ts",
            "supabase/functions/_shared/gemini.ts",
            "supabase/functions/_shared/http.ts",
            "supabase/migrations/20260717000100_create_remote_history_and_apple_auth_tokens.sql",
            "supabase/migrations/20260718000100_harden_history_constraints.sql",
            "supabase/migrations/20260718000200_harden_apple_auth_token_identity.sql",
            "supabase/migrations/20260722000100_create_marketplace_research_cache.sql"
        ] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: projectURL(path).path), "\(path) should exist")
        }
    }

    func testSupabaseMigrationCreatesHistoryAndPrivateAppleTokenStorage() throws {
        let migration = try read("supabase/migrations/20260717000100_create_remote_history_and_apple_auth_tokens.sql")

        XCTAssertNotNil(migration.range(of: "create table if not exists public.history"))
        XCTAssertNotNil(migration.range(of: "user_id uuid not null default auth.uid() references auth.users(id) on delete cascade"))
        XCTAssertNotNil(migration.range(of: "alter table public.history enable row level security"))
        XCTAssertNotNil(migration.range(of: "alter table public.history force row level security"))
        XCTAssertNotNil(migration.range(of: #"create policy "Users can manage their own history""#))
        XCTAssertNotNil(migration.range(of: "to authenticated"))
        XCTAssertNotNil(migration.range(of: "using ((select auth.uid()) = user_id)"))
        XCTAssertNotNil(migration.range(of: "with check ((select auth.uid()) = user_id)"))
        XCTAssertNil(migration.range(of: "using (user_id = auth.uid())"))
        XCTAssertNil(migration.range(of: "with check (user_id = auth.uid())"))
        XCTAssertNotNil(migration.range(of: "create index if not exists history_user_created_at_idx"))
        XCTAssertNotNil(migration.range(of: "grant select, insert, update, delete on table public.history to authenticated"))
        XCTAssertNotNil(migration.range(of: "revoke all on table public.history from anon"))

        XCTAssertNotNil(migration.range(of: "create table if not exists public.apple_auth_tokens"))
        XCTAssertNotNil(migration.range(of: "user_id uuid primary key references auth.users(id) on delete cascade"))
        XCTAssertNotNil(migration.range(of: "refresh_token text not null"))
        XCTAssertNotNil(migration.range(of: "alter table public.apple_auth_tokens enable row level security"))
        XCTAssertNotNil(migration.range(of: "alter table public.apple_auth_tokens force row level security"))
        XCTAssertNotNil(migration.range(of: "revoke all on table public.apple_auth_tokens from anon"))
        XCTAssertNotNil(migration.range(of: "revoke all on table public.apple_auth_tokens from authenticated"))
        XCTAssertNotNil(migration.range(of: "grant all on table public.apple_auth_tokens to service_role"))
        XCTAssertNil(migration.range(of: #"create policy .*apple_auth_tokens"#, options: .regularExpression))
    }

    func testSupabaseHistoryHardeningMigrationConstrainsNativeValues() throws {
        let migration = try read("supabase/migrations/20260718000100_harden_history_constraints.sql")

        XCTAssertNotNil(migration.range(of: "do $$"))
        XCTAssertNotNil(migration.range(of: "if not exists"))
        XCTAssertNil(migration.range(of: "add constraint if not exists", options: .caseInsensitive))
        XCTAssertNotNil(migration.range(of: "history_category_known"))
        XCTAssertNotNil(migration.range(of: "history_condition_known"))
        XCTAssertNotNil(migration.range(of: "history_marketplace_known"))
        XCTAssertNotNil(migration.range(of: "history_listing_text_has_sections"))
        XCTAssertNotNil(migration.range(of: "category is null or category in"))
        XCTAssertNotNil(migration.range(of: "condition is null or condition in"))
        XCTAssertNotNil(migration.range(of: "marketplace in"))
        XCTAssertNotNil(migration.range(of: "listing_text ~* '^[[:space:]]*title[[:space:]]*:'"))
        XCTAssertNotNil(migration.range(of: "listing_text ~* 'description[[:space:]]*:'"))

        for category in Category.allCases {
            XCTAssertNotNil(migration.range(of: "'\(category.rawValue)'"), "\(category.rawValue) should be valid remote history category")
        }
        for condition in Condition.allCases {
            XCTAssertNotNil(migration.range(of: "'\(condition.rawValue)'"), "\(condition.rawValue) should be valid remote history condition")
        }
        for marketplace in Marketplace.allCases {
            XCTAssertNotNil(migration.range(of: "'\(marketplace.rawValue)'"), "\(marketplace.rawValue) should be valid remote history marketplace")
        }
    }

    func testSupabaseAppleTokenHardeningMigrationPreventsDuplicateAppleSubjects() throws {
        let migration = try read("supabase/migrations/20260718000200_harden_apple_auth_token_identity.sql")

        XCTAssertNotNil(migration.range(of: "do $$"))
        XCTAssertNotNil(migration.range(of: "if not exists"))
        XCTAssertNil(migration.range(of: "add constraint if not exists", options: .caseInsensitive))
        XCTAssertNotNil(migration.range(of: "apple_auth_tokens_apple_user_id_unique"))
        XCTAssertNotNil(migration.range(of: "conrelid = 'public.apple_auth_tokens'::regclass"))
        XCTAssertNotNil(migration.range(of: "unique (apple_user_id)"))
    }

    func testSupabaseMigrationCreatesServiceOnlyMarketplaceResearchCache() throws {
        let migration = try read("supabase/migrations/20260722000100_create_marketplace_research_cache.sql")

        XCTAssertNotNil(migration.range(of: "create table if not exists public.marketplace_research_cache"))
        XCTAssertNotNil(migration.range(of: "cache_key text primary key"))
        XCTAssertNotNil(migration.range(of: "search_queries text[] not null default '{}'"))
        XCTAssertNotNil(migration.range(of: "useful_findings text[] not null default '{}'"))
        XCTAssertNotNil(migration.range(of: "official_sources text[] not null default '{}'"))
        XCTAssertNotNil(migration.range(of: "research_summary text not null"))
        XCTAssertNotNil(migration.range(of: "expires_at timestamptz not null"))
        XCTAssertNotNil(migration.range(of: "marketplace_research_expires_after_updated"))
        XCTAssertNotNil(migration.range(of: "alter table public.marketplace_research_cache enable row level security"))
        XCTAssertNotNil(migration.range(of: "alter table public.marketplace_research_cache force row level security"))
        XCTAssertNotNil(migration.range(of: "revoke all on table public.marketplace_research_cache from anon"))
        XCTAssertNotNil(migration.range(of: "revoke all on table public.marketplace_research_cache from authenticated"))
        XCTAssertNotNil(migration.range(of: "grant all on table public.marketplace_research_cache to service_role"))
        XCTAssertNil(migration.range(of: #"create policy .*marketplace_research_cache"#, options: .regularExpression))
    }

    func testAnonymousAnalyzeAndGenerateFunctionsUseGeminiServerSideSecret() throws {
        let config = try read("supabase/config.toml")
        XCTAssertNotNil(config.range(of: #"\[functions\.analyze-image\]\s+verify_jwt = false"#, options: .regularExpression))
        XCTAssertNotNil(config.range(of: #"\[functions\.generate-listing\]\s+verify_jwt = false"#, options: .regularExpression))
        XCTAssertNotNil(config.range(of: #"\[functions\.store-apple-token\]\s+verify_jwt = true"#, options: .regularExpression))
        XCTAssertNotNil(config.range(of: #"\[functions\.delete-account\]\s+verify_jwt = true"#, options: .regularExpression))

        let gemini = try read("supabase/functions/_shared/gemini.ts")
        XCTAssertNotNil(gemini.range(of: #"requireEnv("GEMINI_API_KEY")"#))
        XCTAssertNotNil(gemini.range(of: "generativelanguage.googleapis.com/v1beta/models/"))
        XCTAssertNotNil(gemini.range(of: ":generateContent"))
        XCTAssertNil(gemini.range(of: "?key="))
        XCTAssertNotNil(gemini.range(of: #""x-goog-api-key": apiKey"#))
        XCTAssertNotNil(gemini.range(of: "gemini-2.5-flash"))
        XCTAssertNil(gemini.range(of: "gemini-flash-latest"))
        XCTAssertNotNil(gemini.range(of: "GEMINI_MODEL"))
        XCTAssertNotNil(gemini.range(of: "response.text()"))
        XCTAssertNotNil(gemini.range(of: "response.status === 429 ? 429 : 502"))
        XCTAssertNotNil(gemini.range(of: "fetchWithTimeout"))
        XCTAssertNotNil(gemini.range(of: #"timeoutFromEnv("GEMINI_TIMEOUT_MS", 18_000)"#))
        XCTAssertNotNil(gemini.range(of: "Provider request timed out"))
        XCTAssertNotNil(gemini.range(of: "Provider transport failed"))
        XCTAssertNotNil(gemini.range(of: "parseProviderPayload"))
        XCTAssertNotNil(gemini.range(of: "Provider response was not valid JSON"))
        XCTAssertNotNil(gemini.range(of: "Provider response was not valid model JSON"))
        XCTAssertNotNil(gemini.range(of: "generationConfig"))
        XCTAssertNil(gemini.range(of: "generation_config"))
        XCTAssertNotNil(gemini.range(of: "const usesTools = (options.tools?.length ?? 0) > 0"))
        XCTAssertNotNil(gemini.range(of: "...(!usesTools"))
        XCTAssertNotNil(gemini.range(of: "responseMimeType"))
        XCTAssertNotNil(gemini.range(of: "responseSchema"))
        XCTAssertNotNil(gemini.range(of: "export type GeminiTool"))
        XCTAssertNotNil(gemini.range(of: "type GeminiRequestOptions"))
        XCTAssertNotNil(gemini.range(of: "options: GeminiRequestOptions = {}"))
        XCTAssertNotNil(gemini.range(of: #"tools: options.tools"#))
        XCTAssertNotNil(gemini.range(of: "maxOutputTokens"))
        XCTAssertNotNil(gemini.range(of: "groundingMetadata"))
        XCTAssertNotNil(gemini.range(of: "webSearchQueries"))
        XCTAssertNotNil(gemini.range(of: "groundingChunks"))
        XCTAssertNotNil(gemini.range(of: "url_context_metadata"))
        XCTAssertNotNil(gemini.range(of: "url_metadata"))
        XCTAssertNotNil(gemini.range(of: "geminiGroundingSearchQueriesKey"))
        XCTAssertNotNil(gemini.range(of: "geminiGroundingSourcesKey"))
        XCTAssertNotNil(gemini.range(of: "attachGroundingMetadata"))
        XCTAssertNotNil(gemini.range(of: "application/json"))
        XCTAssertNil(gemini.range(of: #"AQ\.[0-9A-Za-z_-]{20,}|AIza[0-9A-Za-z_-]{20,}|sk-[0-9A-Za-z_-]{20,}|sb_secret_[0-9A-Za-z_-]{20,}"#, options: .regularExpression))
    }

    func testAnalyzeFunctionPreservesNativeAnalyzeContract() throws {
        let source = try read("supabase/functions/analyze-image/index.ts")

        XCTAssertNotNil(source.range(of: "imageDataUrl"))
        XCTAssertNotNil(source.range(of: "data:image/jpeg;base64,"))
        XCTAssertNotNil(source.range(of: "const maxImageBytes = 6_000_000"))
        XCTAssertNotNil(source.range(of: "decodeImageBase64"))
        XCTAssertNotNil(source.range(of: "const binary = atob(base64)"))
        XCTAssertNotNil(source.range(of: "Uint8Array.from(binary"))
        XCTAssertNotNil(source.range(of: "isJpegBytes"))
        XCTAssertNotNil(source.range(of: "imageDataUrl must contain JPEG bytes"))
        XCTAssertNotNil(source.range(of: "imageDataUrl is too large"))
        XCTAssertNotNil(source.range(of: #"inline_data: \{ mime_type: "image/jpeg""#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: "name"))
        XCTAssertNotNil(source.range(of: "category"))
        XCTAssertNotNil(source.range(of: "condition"))
        XCTAssertNotNil(source.range(of: "currentPrice"))
        XCTAssertNotNil(source.range(of: "analysis.itemFacts"))
        XCTAssertNotNil(source.range(of: "confidence from 0 to 1"))
        XCTAssertNotNil(source.range(of: "missingFacts"))
        XCTAssertNotNil(source.range(of: "photoPrompt"))
        XCTAssertNotNil(source.range(of: "analysis.likelyMatches"))
        XCTAssertNotNil(source.range(of: "up to 3 specific possible matches"))
        XCTAssertNotNil(source.range(of: "distinguishingQuestion"))
        XCTAssertNotNil(source.range(of: "fetchVisionWebDetectionEvidence(imageDataUrl)"))
        XCTAssertNotNil(source.range(of: "GOOGLE_CLOUD_VISION_API_KEY"))
        XCTAssertNotNil(source.range(of: "WEB_DETECTION"))
        XCTAssertNotNil(source.range(of: "visuallySimilarImages"))
        XCTAssertNotNil(source.range(of: "Visual web evidence"))
        XCTAssertNotNil(source.range(of: "analysis.referenceImages"))
        XCTAssertNotNil(source.range(of: "identification checking only"))
        XCTAssertNotNil(source.range(of: "They are not listing photos"))
        XCTAssertNotNil(source.range(of: "normalizeAnalyzeIntelligence"))
        XCTAssertNotNil(source.range(of: "normalizeAnalyzeFact"))
        XCTAssertNotNil(source.range(of: "normalizeLikelyMatch"))
        XCTAssertNotNil(source.range(of: "normalizeReferenceImages"))
        XCTAssertNotNil(source.range(of: "optionalHttpUrl"))
        XCTAssertNotNil(source.range(of: #"required: \["label", "value", "confidence"\]"#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: #"required: \["name", "distinguishingQuestion", "confidence"\]"#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: #"required: \["title", "url"\]"#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: "follow-up-question"))
        XCTAssertNotNil(source.range(of: "deductible"))
        XCTAssertNotNil(source.range(of: "tax"))
    }

    func testGenerateListingFunctionPreservesNativeListingContract() throws {
        let source = try read("supabase/functions/generate-listing/index.ts")

        XCTAssertNotNil(source.range(of: "item"))
        XCTAssertNotNil(source.range(of: "platform"))
        XCTAssertNotNil(source.range(of: "originalPrice"))
        XCTAssertNotNil(source.range(of: "currentPrice"))
        XCTAssertNotNil(source.range(of: "optionalItemDetails(body.details)"))
        XCTAssertNotNil(source.range(of: "optionalImageDataUrl(body.imageDataUrl)"))
        XCTAssertNotNil(source.range(of: "fetchVisionWebDetectionEvidence(imageDataUrl)"))
        XCTAssertNotNil(source.range(of: "GOOGLE_CLOUD_VISION_API_KEY"))
        XCTAssertNotNil(source.range(of: "WEB_DETECTION"))
        XCTAssertNotNil(source.range(of: "visuallySimilarImages"))
        XCTAssertNotNil(source.range(of: "bestGuessLabels"))
        XCTAssertNotNil(source.range(of: "TITLE"))
        XCTAssertNotNil(source.range(of: "DESCRIPTION"))
        XCTAssertNotNil(source.range(of: "listing"))
        XCTAssertNotNil(source.range(of: "marketplaceProfiles"))
        XCTAssertNotNil(source.range(of: "titleMaxCharacters"))
        XCTAssertNotNil(source.range(of: "Keep TITLE at or below"))
        XCTAssertNotNil(source.range(of: "Marketplace title formula"))
        XCTAssertNotNil(source.range(of: "Marketplace search focus"))
        XCTAssertNotNil(source.range(of: "Photo guidance to mention if helpful"))
        XCTAssertNotNil(source.range(of: "Featured guidance to respect"))
        XCTAssertNotNil(source.range(of: "createMarketplaceResearchPlan"))
        XCTAssertNotNil(source.range(of: "fetchMarketplaceResearchCache"))
        XCTAssertNotNil(source.range(of: "saveMarketplaceResearchCache"))
        XCTAssertNotNil(source.range(of: "geminiGroundingSearchQueriesKey"))
        XCTAssertNotNil(source.range(of: "geminiGroundingSourcesKey"))
        XCTAssertNotNil(source.range(of: "Use Google Search and URL Context only for the minimal research plan provided"))
        XCTAssertNotNil(source.range(of: "Prefer official marketplace guidance over stale assumptions"))
        XCTAssertNotNil(source.range(of: "use grounded search for real marketplace fees, sold/completed comps, comparable price history, and marketplace rules"))
        XCTAssertNotNil(source.range(of: "Distinguish sold/completed comps from active asking prices"))
        XCTAssertNotNil(source.range(of: "Active listings and asking prices may appear in evidenceSources, but they must never populate sold comp price fields."))
        XCTAssertNotNil(source.range(of: "Never invent brand, model, size, defects, sold prices, fees, or public image URLs"))
        XCTAssertNotNil(source.range(of: "referenceImageURL must be a public image URL"))
        XCTAssertNotNil(source.range(of: "Visual web evidence"))
        XCTAssertNotNil(source.range(of: "Seller details"))
        XCTAssertNotNil(source.range(of: "detailsForPrompt(details, platform)"))
        XCTAssertNotNil(source.range(of: "marketplaceNotes: optionalMarketplaceNotes(details.marketplaceNotes)"))
        XCTAssertNotNil(source.range(of: "marketplaceNoteSummary(details.marketplaceNotes, platform)"))
        XCTAssertNotNil(source.range(of: "Saved marketplace research"))
        XCTAssertNotNil(source.range(of: "result[geminiGroundingSourcesKey]"))
        XCTAssertNotNil(source.range(of: "result[geminiGroundingSearchQueriesKey]"))
        XCTAssertNotNil(source.range(of: "uniqueStrings"))
        XCTAssertNotNil(source.range(of: #"const researchSummaryForCache = researchSummary ?? (usefulFindings.join(" ") || officialSources.join(" "))"#))
        XCTAssertNotNil(source.range(of: "if (!researchSummaryForCache) return"))
        XCTAssertNotNil(source.range(of: "official_sources: officialSources"))
        XCTAssertNotNil(source.range(of: "research_summary: researchSummaryForCache"))
        XCTAssertNotNil(source.range(of: "search_queries: searchedFor.length > 0 ? searchedFor : plan.searchQuestions"))
        XCTAssertNotNil(source.range(of: "searchQuestions: searchQuestions.slice(0, 3)"))
        XCTAssertNotNil(source.range(of: "marketplace_research_cache"))
        XCTAssertNotNil(source.range(of: "expires_at=gt."))
        XCTAssertNotNil(source.range(of: "resolution=merge-duplicates,return=minimal"))
        XCTAssertNotNil(source.range(of: "generateListingDraftJson"))
        XCTAssertNotNil(source.range(of: "listingDraftResponseSchema"))
        XCTAssertNotNil(source.range(of: "const tools: GeminiTool[] = input.usesCachedResearch ? [] : ["))
        XCTAssertNotNil(source.range(of: "{ url_context: {} }"))
        XCTAssertNotNil(source.range(of: "{ google_search: {} }"))
        XCTAssertNotNil(source.range(of: "input.usesCachedResearch ? []"))
        XCTAssertNotNil(source.range(of: "Grounded research returned no final draft text."))
        XCTAssertNotNil(source.range(of: "Do not claim current fees, sold prices, public image URLs, rarity, brand, model, size, or defects unless those facts are already provided."))
        XCTAssertNotNil(source.range(of: "deterministicListingDraft"))
        XCTAssertNotNil(source.range(of: "Current marketplace research returned no final draft, so this uses only the item facts provided."))
        XCTAssertNotNil(source.range(of: "isRateLimitedProviderError"))
        XCTAssertNotNil(source.range(of: "maxOutputTokens: 4_096"))
        XCTAssertNotNil(source.range(of: "Return structured draft fields only; BuySell formats the final listing text"))
        XCTAssertNotNil(source.range(of: "Do not return a listing field, markdown, preambles, watermarks, or section headings"))
        XCTAssertNotNil(source.range(of: "Required fields: title, description, listPrice, likelySalePrice, takeHomeEstimate, firstPhoto, fitReason"))
        XCTAssertNotNil(source.range(of: "requireStructuredListingDraft"))
        XCTAssertNotNil(source.range(of: "formatListingDraft"))
        XCTAssertNotNil(source.range(of: "title: { type: \"STRING\" }"))
        XCTAssertNotNil(source.range(of: "description: { type: \"STRING\" }"))
        XCTAssertNotNil(source.range(of: "listPrice: { type: \"NUMBER\", minimum: 1 }"))
        XCTAssertNotNil(source.range(of: "likelySalePrice: { type: \"NUMBER\", minimum: 1 }"))
        XCTAssertNotNil(source.range(of: "takeHomeEstimate: { type: \"NUMBER\", minimum: 1 }"))
        XCTAssertNotNil(source.range(of: "firstPhoto: { type: \"STRING\" }"))
        XCTAssertNotNil(source.range(of: "fitReason: { type: \"STRING\" }"))
        XCTAssertNotNil(source.range(of: "compLowPrice: { type: \"NUMBER\", minimum: 1 }"))
        XCTAssertNotNil(source.range(of: "compHighPrice: { type: \"NUMBER\", minimum: 1 }"))
        XCTAssertNotNil(source.range(of: "compMedianPrice: { type: \"NUMBER\", minimum: 1 }"))
        XCTAssertNotNil(source.range(of: "feeSummary: { type: \"STRING\" }"))
        XCTAssertNotNil(source.range(of: "pricingStrategy: { type: \"STRING\" }"))
        XCTAssertNotNil(source.range(of: "evidenceSummary: { type: \"STRING\" }"))
        XCTAssertNotNil(source.range(of: "referenceImageURL: { type: \"STRING\" }"))
        XCTAssertNotNil(source.range(of: "evidenceSources: {"))
        XCTAssertNotNil(source.range(of: "sourceMarketplace: { type: \"STRING\" }"))
        XCTAssertNotNil(source.range(of: "dateChecked: { type: \"STRING\" }"))
        XCTAssertNotNil(source.range(of: "listingStatus: { type: \"STRING\" }"))
        XCTAssertNotNil(source.range(of: "conditionAndVariant: { type: \"STRING\" }"))
        XCTAssertNotNil(source.range(of: "comparability: { type: \"STRING\" }"))
        XCTAssertNotNil(source.range(of: "const evidenceSources = cleanEvidenceSources(result.evidenceSources, platform)"))
        XCTAssertNotNil(source.range(of: "const hasSoldCompEvidence = evidenceSources.some(isSoldEvidenceSource)"))
        XCTAssertNotNil(source.range(of: "compLowPrice = hasSoldCompEvidence ? optionalPositiveNumber(result.compLowPrice) : null"))
        XCTAssertNotNil(source.range(of: "compMedianPrice = hasSoldCompEvidence ? optionalPositiveNumber(result.compMedianPrice) : null"))
        XCTAssertNotNil(source.range(of: "compHighPrice = hasSoldCompEvidence ? optionalPositiveNumber(result.compHighPrice) : null"))
        XCTAssertNotNil(source.range(of: "optionalReferenceImageURL(result.referenceImageURL)"))
        XCTAssertNotNil(source.range(of: "cleanEvidenceSources(result.evidenceSources, platform)"))
        XCTAssertNotNil(source.range(of: "For every factual market result you rely on, add one evidenceSources object"))
        XCTAssertNotNil(source.range(of: "Do not add evidenceSources entries for guessed prices"))
        XCTAssertNotNil(source.range(of: "function cleanEvidenceSources(value: unknown, platform: MarketplaceId): StructuredEvidenceSource[]"))
        XCTAssertNotNil(source.range(of: "function cleanListingStatus(value: unknown): string | null"))
        XCTAssertNotNil(source.range(of: "function listingStatusFromPriceFields(record: Record<string, unknown>): string | null"))
        XCTAssertNotNil(source.range(of: "function isSoldEvidenceSource(source: StructuredEvidenceSource): boolean"))
        XCTAssertNotNil(source.range(of: "optionalPositiveNumber(record.soldPrice) !== null"))
        XCTAssertNotNil(source.range(of: "optionalPositiveNumber(record.activePrice ?? record.askingPrice) !== null"))
        XCTAssertNotNil(source.range(of: "return jsonResponse({ listing, draft })"))
        XCTAssertNotNil(source.range(of: "requireCleanListing"))
        XCTAssertNil(source.range(of: #"\bSEO\b"#, options: [.regularExpression, .caseInsensitive]))
        XCTAssertNotNil(source.range(of: "cleanDraftText"))
        XCTAssertNotNil(source.range(of: "rejectUnsafeDraftText"))
        XCTAssertNil(source.range(of: "formatUsd"))
        XCTAssertNil(source.range(of: "List at:"))
        XCTAssertNil(source.range(of: "Likely sells for:"))
        XCTAssertNil(source.range(of: "Take-home estimate:"))
        XCTAssertNil(source.range(of: "Main photo:"))
        XCTAssertNil(source.range(of: "Why ${marketplaceDisplayNames[platform]}"))
        XCTAssertNotNil(source.range(of: "function formatListingDraft(draft: StructuredListingDraft): string"))
        XCTAssertNotNil(source.range(of: "draft.title"))
        XCTAssertNotNil(source.range(of: "draft.description"))
        XCTAssertNotNil(source.range(of: "Listing response was not plain text"))
        XCTAssertNotNil(source.range(of: #"/```/i.test(listing)"#))
        XCTAssertNil(source.range(of: #"/^```/i.test(listing) || /```$/i.test(listing)"#))
        XCTAssertNotNil(source.range(of: "Listing response included a preamble"))
        XCTAssertNotNil(source.range(of: "Listing response missing required sections"))
        XCTAssertNotNil(source.range(of: "Listing response missing section text"))
        XCTAssertNotNil(source.range(of: "Listing response title too long"))
        XCTAssertNotNil(source.range(of: "const titleMatch"))
        XCTAssertNotNil(source.range(of: "const afterTitle"))
        XCTAssertNotNil(source.range(of: "const descriptionMatch"))
        XCTAssertNotNil(source.range(of: "const titleBody"))
        XCTAssertNotNil(source.range(of: "const descriptionBody"))
        XCTAssertNotNil(source.range(of: "titleBody.length > titleMaxCharacters"))
        XCTAssertNotNil(source.range(of: #"^TITLE\s*:"#))
        XCTAssertNotNil(source.range(of: #"^DESCRIPTION\s*:"#))
    }

    func testGenerateListingFunctionRestrictsPlatformToNativeMarketplaces() throws {
        let source = try read("supabase/functions/generate-listing/index.ts")

        XCTAssertNotNil(source.range(of: "const knownMarketplaceIds = ["))
        XCTAssertNotNil(source.range(of: "const knownMarketplaceIdSet = new Set<string>(knownMarketplaceIds)"))
        XCTAssertNotNil(source.range(of: "const platform = requireMarketplace(body.platform)"))
        XCTAssertNotNil(source.range(of: "function requireMarketplace(value: unknown): MarketplaceId"))
        XCTAssertNotNil(source.range(of: #"throw new HttpError("Unsupported platform", 400)"#))
        XCTAssertNil(source.range(of: #"const platform = asString(body.platform, "platform")"#))

        for marketplace in Marketplace.allCases {
            XCTAssertNotNil(
                source.range(of: #""\#(marketplace.rawValue)""#),
                "\(marketplace.rawValue) should be accepted by the generate-listing backend"
            )
        }
    }

    func testGenerateListingFunctionRestrictsCategoryAndConditionToNativeValues() throws {
        let source = try read("supabase/functions/generate-listing/index.ts")

        XCTAssertNotNil(source.range(of: "const knownCategoryValues = ["))
        XCTAssertNotNil(source.range(of: "const knownConditionValues = ["))
        XCTAssertNotNil(source.range(of: "category: requireCategory(item.category)"))
        XCTAssertNotNil(source.range(of: "condition: requireCondition(item.condition)"))
        XCTAssertNotNil(source.range(of: "function requireCategory(value: unknown): string"))
        XCTAssertNotNil(source.range(of: "function requireCondition(value: unknown): string"))
        XCTAssertNotNil(source.range(of: "function asKnownValue<T extends string>"))
        XCTAssertNotNil(source.range(of: #"throw new HttpError(`Unsupported ${field}`, 400)"#))

        for category in Category.allCases {
            XCTAssertNotNil(
                source.range(of: #""\#(category.apiValue)""#),
                "\(category.apiValue) should be accepted by the generate-listing backend"
            )
        }
        for condition in Condition.allCases {
            XCTAssertNotNil(
                source.range(of: #""\#(condition.apiValue)""#),
                "\(condition.apiValue) should be accepted by the generate-listing backend"
            )
        }
    }

    func testCompareMarketplaceFunctionSavesGroundedResearchForListingStep() throws {
        let source = try read("supabase/functions/compare-marketplaces/index.ts")

        XCTAssertNotNil(source.range(of: "const comparisons = normalizeComparisons(result, item, candidateMarketplaces, checkedAt)"))
        XCTAssertNotNil(source.range(of: "await saveComparisonResearchCache(item, details, result, comparisons)"))
        XCTAssertNotNil(source.range(of: "function createMarketplaceResearchPlan("))
        XCTAssertNotNil(source.range(of: "function comparisonUsefulFindings("))
        XCTAssertNotNil(source.range(of: #"if (comparison.evidenceStatus === "unavailable") continue"#))
        XCTAssertNotNil(source.range(of: "result[geminiGroundingSearchQueriesKey]"))
        XCTAssertNotNil(source.range(of: "result[geminiGroundingSourcesKey]"))
        XCTAssertNotNil(source.range(of: "marketplace_research_cache?on_conflict=cache_key"))
        XCTAssertNotNil(source.range(of: "resolution=merge-duplicates,return=minimal"))
        XCTAssertNotNil(source.range(of: "SUPABASE_SERVICE_ROLE_KEY"))
        XCTAssertNotNil(source.range(of: "SUPABASE_SERVICE_TIMEOUT_MS"))
        XCTAssertNotNil(source.range(of: "gemini-2.5-flash"))
        XCTAssertNotNil(source.range(of: "expires_at: expiresAt.toISOString()"))
        XCTAssertNotNil(source.range(of: "const hasSoldEvidence = evidenceSources.some((source) => source.listingStatus === \"Sold\")"))
        XCTAssertNotNil(source.range(of: "compLowPrice: hasSoldEvidence ? optionalPositiveNumber(row.compLowPrice) : null"))
        XCTAssertNotNil(source.range(of: "function listingStatusFromPriceFields(record: Record<string, unknown>): string | null"))
        XCTAssertNotNil(source.range(of: "optionalPositiveNumber(record.soldPrice) !== null"))
        XCTAssertNotNil(source.range(of: "optionalPositiveNumber(record.activePrice ?? record.askingPrice) !== null"))
    }

    func testSharedHttpHelperReturnsTypedMalformedJsonErrors() throws {
        let source = try read("supabase/functions/_shared/http.ts")

        XCTAssertNotNil(source.range(of: "try {"))
        XCTAssertNotNil(source.range(of: "body = await request.json()"))
        XCTAssertNotNil(source.range(of: #"throw new HttpError("Expected valid JSON", 400)"#))
        XCTAssertNotNil(source.range(of: #"throw new HttpError("Expected JSON object", 400)"#))
        XCTAssertNotNil(source.range(of: "readResponseJson"))
        XCTAssertNotNil(source.range(of: "return await response.json()"))
        XCTAssertNotNil(source.range(of: "requireJsonObject"))
        XCTAssertNotNil(source.range(of: "requireJsonArray"))
        XCTAssertNotNil(source.range(of: "fetchWithTimeout"))
        XCTAssertNotNil(source.range(of: "AbortController"))
        XCTAssertNotNil(source.range(of: #"new HttpError(options.timeoutMessage ?? "Request timed out""#))
        XCTAssertNotNil(source.range(of: #"new HttpError(options.transportMessage ?? "Request failed""#))
        XCTAssertNotNil(source.range(of: "timeoutFromEnv"))
        XCTAssertNotNil(source.range(of: #"throw new HttpError(`Invalid ${name}`, 500)"#))
    }

    func testStoreAppleTokenFunctionKeepsAppleTokenMaterialServerSide() throws {
        let source = try read("supabase/functions/store-apple-token/index.ts")
        let apple = try read("supabase/functions/_shared/apple.ts")

        XCTAssertNotNil(source.range(of: #"requireEnv("SUPABASE_SERVICE_ROLE_KEY")"#))
        XCTAssertNotNil(source.range(of: "fetchWithTimeout"))
        XCTAssertNotNil(source.range(of: #"timeoutFromEnv("SUPABASE_SERVICE_TIMEOUT_MS", 8_000)"#))
        XCTAssertNotNil(source.range(of: "Supabase service request timed out"))
        XCTAssertNotNil(source.range(of: "Supabase service transport failed"))
        XCTAssertNotNil(source.range(of: "readResponseJson"))
        XCTAssertNotNil(source.range(of: "requireJsonObject"))
        XCTAssertNotNil(source.range(of: "Supabase user response was not valid JSON"))
        XCTAssertNotNil(source.range(of: "Supabase user response was not a JSON object"))
        XCTAssertNotNil(source.range(of: "requireBearerToken"))
        XCTAssertNotNil(source.range(of: "/auth/v1/user"))
        XCTAssertNotNil(source.range(of: "authorization_code"))
        XCTAssertNotNil(source.range(of: "apple_user_id"))
        XCTAssertNotNil(source.range(of: "exchangeAppleAuthorizationCode"))
        XCTAssertNotNil(source.range(of: "assertAppleIdentityAvailable"))
        XCTAssertNotNil(source.range(of: "fetchAppleTokenOwner"))
        XCTAssertNotNil(source.range(of: "/rest/v1/apple_auth_tokens?apple_user_id=eq."))
        XCTAssertNotNil(source.range(of: "select=user_id&limit=1"))
        XCTAssertNotNil(source.range(of: "Apple token owner response was not valid JSON"))
        XCTAssertNotNil(source.range(of: "Apple token owner response was not a JSON array"))
        XCTAssertNotNil(source.range(of: "Apple token owner row was not a JSON object"))
        XCTAssertNotNil(source.range(of: #"throw new HttpError("Apple account is already linked", 409)"#))
        XCTAssertNotNil(source.range(of: "if (!appleToken.identitySubject)"))
        XCTAssertNotNil(source.range(of: #"throw new HttpError("Apple token response missing identity subject", 502)"#))
        XCTAssertNotNil(source.range(of: "if (appleToken.identitySubject !== appleUserId)"))
        XCTAssertNotNil(source.range(of: #"throw new HttpError("Apple token subject mismatch", 401)"#))
        XCTAssertNotNil(source.range(of: "/rest/v1/apple_auth_tokens?on_conflict=user_id"))
        XCTAssertNotNil(source.range(of: "response.status === 409"))
        XCTAssertNotNil(apple.range(of: #"requireEnv("APPLE_CLIENT_ID")"#))
        XCTAssertNotNil(apple.range(of: #"requireEnv("APPLE_TEAM_ID")"#))
        XCTAssertNotNil(apple.range(of: #"requireEnv("APPLE_KEY_ID")"#))
        XCTAssertNotNil(apple.range(of: #"requireEnv("APPLE_PRIVATE_KEY")"#))
        XCTAssertNotNil(apple.range(of: "https://appleid.apple.com/auth/token"))
        XCTAssertNotNil(apple.range(of: "fetchWithTimeout"))
        XCTAssertNotNil(apple.range(of: #"timeoutFromEnv("APPLE_TIMEOUT_MS", 8_000)"#))
        XCTAssertNotNil(apple.range(of: "Apple authorization request timed out"))
        XCTAssertNotNil(apple.range(of: "Apple authorization transport failed"))
        XCTAssertNotNil(apple.range(of: "readResponseJson"))
        XCTAssertNotNil(apple.range(of: "requireJsonObject"))
        XCTAssertNotNil(apple.range(of: "Apple token response was not valid JSON"))
        XCTAssertNotNil(apple.range(of: "Apple token response was not a JSON object"))
        XCTAssertNotNil(apple.range(of: "grant_type"))
        XCTAssertNotNil(apple.range(of: "authorization_code"))
    }

    func testDeleteAccountFunctionRequiresServiceRoleRevokesAppleTokenAndDeletesHistoryAndAuthUser() throws {
        let source = try read("supabase/functions/delete-account/index.ts")
        let apple = try read("supabase/functions/_shared/apple.ts")

        XCTAssertNotNil(source.range(of: #"requireEnv("SUPABASE_SERVICE_ROLE_KEY")"#))
        XCTAssertNotNil(source.range(of: "fetchWithTimeout"))
        XCTAssertNotNil(source.range(of: #"timeoutFromEnv("SUPABASE_SERVICE_TIMEOUT_MS", 8_000)"#))
        XCTAssertNotNil(source.range(of: "Supabase service request timed out"))
        XCTAssertNotNil(source.range(of: "Supabase service transport failed"))
        XCTAssertNotNil(source.range(of: "readResponseJson"))
        XCTAssertNotNil(source.range(of: "requireJsonObject"))
        XCTAssertNotNil(source.range(of: "requireJsonArray"))
        XCTAssertNotNil(source.range(of: "Supabase user response was not valid JSON"))
        XCTAssertNotNil(source.range(of: "Apple token rows response was not valid JSON"))
        XCTAssertNotNil(source.range(of: "Apple token rows response was not a JSON array"))
        XCTAssertNotNil(source.range(of: "Apple token row was not a JSON object"))
        XCTAssertNotNil(source.range(of: "requireBearerToken"))
        XCTAssertNotNil(source.range(of: "/auth/v1/user"))
        XCTAssertNotNil(source.range(of: "fetchAppleToken"))
        XCTAssertNotNil(source.range(of: "/rest/v1/apple_auth_tokens?user_id=eq."))
        XCTAssertNotNil(source.range(of: "tryRevokeAppleToken"))
        XCTAssertNotNil(source.range(of: "revokeAppleToken"))
        XCTAssertNotNil(source.range(of: "isAppleSecretConfigurationError"))
        XCTAssertNotNil(source.range(of: #"^Missing APPLE_"#))
        XCTAssertNotNil(source.range(of: "Invalid Apple private key"))
        XCTAssertNotNil(source.range(of: "Account deletion must still complete if Apple token cleanup is stale or unavailable"))
        XCTAssertNotNil(source.range(of: "deleteAppleToken"))
        XCTAssertNotNil(source.range(of: "/rest/v1/history?user_id=eq."))
        XCTAssertNotNil(source.range(of: "/auth/v1/admin/users/"))
        XCTAssertNotNil(source.range(of: "serviceHeaders(serviceRoleKey)"))
        XCTAssertNotNil(apple.range(of: "https://appleid.apple.com/auth/revoke"))
        XCTAssertNotNil(apple.range(of: "token_type_hint"))
        XCTAssertNotNil(apple.range(of: "applePrivateKeyBytes"))
        XCTAssertNotNil(apple.range(of: #"throw new HttpError("Invalid Apple private key", 500)"#))
    }

    func testBackendDocsExplainDeployAndSecretHandling() throws {
        let readme = try read("README.md")
        let backendReadme = try read("supabase/README.md")

        for text in [readme, backendReadme] {
            XCTAssertNotNil(text.range(of: "Scripts/deploy_supabase_backend.sh"))
            XCTAssertNotNil(text.range(of: "CONFIRM_SUPABASE_DEPLOY=<project-ref>"))
            XCTAssertNotNil(text.range(of: "supabase db push --linked --yes"))
            XCTAssertNotNil(text.range(of: "--use-api"))
            XCTAssertNotNil(text.range(of: "supabase db push"))
            XCTAssertNotNil(text.range(of: "supabase functions deploy analyze-image"))
            XCTAssertNotNil(text.range(of: "supabase functions deploy generate-listing"))
            XCTAssertNotNil(text.range(of: "supabase functions deploy store-apple-token"))
            XCTAssertNotNil(text.range(of: "supabase functions deploy delete-account"))
            XCTAssertNotNil(text.range(of: "GEMINI_API_KEY"))
            XCTAssertNotNil(text.range(of: "gemini-2.5-flash"))
            XCTAssertNotNil(text.range(of: "stable"))
            XCTAssertNil(text.range(of: "gemini-flash-latest"))
            XCTAssertNotNil(text.range(of: "marketplace_research_cache"))
            XCTAssertNotNil(text.range(of: "APPLE_CLIENT_ID"))
            XCTAssertNotNil(text.range(of: "server-side"))
        }
    }

    func testSupabaseReadmeUsesSafeSecretSetupHelper() throws {
        let backendReadme = try read("supabase/README.md")
        let helper = try read("Scripts/setup_supabase_secrets.sh")

        XCTAssertNotNil(backendReadme.range(of: "Scripts/setup_supabase_secrets.sh preflight"))
        XCTAssertNotNil(backendReadme.range(of: "Scripts/setup_supabase_secrets.sh full"))
        XCTAssertNotNil(backendReadme.range(of: "before any secret values are requested"))
        XCTAssertNotNil(backendReadme.range(of: "0600 temporary env file outside the repository"))
        XCTAssertNotNil(backendReadme.range(of: "gemini-only"))
        XCTAssertNotNil(helper.range(of: "SUPABASE_SECRETS_FROM_ENV"))
        XCTAssertNotNil(helper.range(of: "SUPABASE_PROJECT_REF"))
        XCTAssertNotNil(helper.range(of: "resolve_project_ref"))
        XCTAssertNotNil(helper.range(of: "require_secret_access"))
        XCTAssertNotNil(helper.range(of: "M10_SUPABASE_SECRET_LIST_TIMEOUT_SECONDS"))
        XCTAssertNotNil(helper.range(of: "run_secret_list_with_timeout"))
        XCTAssertNotNil(helper.range(of: "Supabase secret setup preflight passed"))
        XCTAssertNotNil(helper.range(of: #"read_secret_or_env "Gemini API key: " GEMINI_API_KEY"#))
        XCTAssertNotNil(helper.range(of: #"read_secret_or_env "Supabase service-role key: " SUPABASE_SERVICE_ROLE_KEY"#))
        XCTAssertNotNil(helper.range(of: #"read_required_or_env "Apple Team ID: " APPLE_TEAM_ID"#))
        XCTAssertNotNil(helper.range(of: #"read_required_or_env "Apple private key .p8 path: " APPLE_PRIVATE_KEY_PATH"#))
        XCTAssertNotNil(helper.range(of: "is required in environment when SUPABASE_SECRETS_FROM_ENV=1"))
        XCTAssertNotNil(helper.range(of: "supabase secrets set --project-ref \"$project_ref\" --env-file \"$secret_file\""))
        XCTAssertNotNil(helper.range(of: "rm -f \"$secret_file\""))
        XCTAssertNotNil(helper.range(of: "unset GEMINI_API_KEY SUPABASE_SERVICE_ROLE_KEY APPLE_TEAM_ID APPLE_KEY_ID APPLE_CLIENT_ID APPLE_PRIVATE_KEY APPLE_PRIVATE_KEY_PATH"))
        XCTAssertNil(backendReadme.range(of: "supabase secrets set --env-file .env"))
        XCTAssertNotNil(backendReadme.range(of: "SUPABASE_SECRETS_FROM_ENV"))
        XCTAssertNotNil(backendReadme.range(of: "SUPABASE_PROJECT_REF"))
        XCTAssertNotNil(backendReadme.range(of: "CI secret environment variables"))
        XCTAssertNotNil(backendReadme.range(of: "Rotate any provider or server-side key that was pasted into chat, logs, or git"))
        XCTAssertNotNil(backendReadme.range(of: "The final M10 secret scan reads hidden files"))
    }

    func testBackendReadinessDocsRouteThroughSmokePreflight() throws {
        let readme = try read("README.md")
        let acceptance = try read("M10_ACCEPTANCE.md")
        let backendReadme = try read("supabase/README.md")

        for text in [readme, acceptance] {
            XCTAssertNotNil(text.range(of: "Scripts/deploy_supabase_backend.sh preflight"))
            XCTAssertNotNil(text.range(of: "Scripts/deploy_supabase_backend.sh deploy"))
            XCTAssertNotNil(text.range(of: "Scripts/preflight_m10_backend.sh"))
            XCTAssertNotNil(text.range(of: "M10_ANALYZE_IMAGE_JPEG"))
            XCTAssertNotNil(text.range(of: "schema: history apple_auth_tokens marketplace_research_cache"))
            XCTAssertNotNil(text.range(of: "functions: analyze-image compare-marketplaces generate-listing store-apple-token delete-account"))
            XCTAssertNotNil(text.range(of: "protected functions: store-apple-token delete-account"))
            XCTAssertNotNil(text.range(of: "protected tables: history apple_auth_tokens marketplace_research_cache"))
            XCTAssertNotNil(text.range(of: "analyze rejection contract: missing jpeg base64"))
            XCTAssertNotNil(text.range(of: "listing contract:"))
            XCTAssertNotNil(text.range(of: "listing rejection contract: platform category condition"))
            XCTAssertNotNil(text.range(of: "supabase/functions/"))
            XCTAssertNotNil(text.range(of: "supabase/migrations/"))
            XCTAssertNotNil(text.range(of: "SUPABASE_SERVICE_ROLE_KEY"))
            XCTAssertNotNil(text.range(of: "store-apple-token"))
        }

        XCTAssertNotNil(backendReadme.range(of: "rejects unsupported platform, category, and condition values"))
        XCTAssertNotNil(backendReadme.range(of: "rejects missing image data, non-JPEG data URLs, and malformed base64"))
        XCTAssertNotNil(backendReadme.range(of: "analyze rejection contract: missing jpeg base64"))
        XCTAssertNotNil(backendReadme.range(of: "listing rejection contract: platform category condition"))
        XCTAssertNotNil(readme.range(of: "create index history_user_created_at_idx"))
        XCTAssertNotNil(readme.range(of: "constraints: history category condition marketplace listing apple-token-identity marketplace-research-cache"))
        XCTAssertNotNil(readme.range(of: "alter table public.history force row level security"))
        XCTAssertNotNil(readme.range(of: "using ((select auth.uid()) = user_id)"))
        XCTAssertNotNil(readme.range(of: "with check ((select auth.uid()) = user_id)"))
        XCTAssertNil(readme.range(of: "using (user_id = auth.uid())"))
        XCTAssertNil(readme.range(of: "with check (user_id = auth.uid())"))
    }

    func testSupabaseFunctionSourcesContainNoProviderSecretLiterals() throws {
        let secretPattern = #"AQ\.[0-9A-Za-z_-]{20,}|AIza[0-9A-Za-z_-]{20,}|sk-[0-9A-Za-z_-]{20,}|sb_secret_[0-9A-Za-z_-]{20,}"#
        for file in try textFiles(under: projectURL("supabase")) {
            let text = try String(contentsOf: file, encoding: .utf8)
            XCTAssertNil(
                text.range(of: secretPattern, options: .regularExpression),
                "\(relativePath(file)) contains a provider secret-shaped value"
            )
        }
    }

    private func read(_ path: String) throws -> String {
        try String(contentsOf: projectURL(path), encoding: .utf8)
    }

    private func textFiles(under root: URL) throws -> [URL] {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item -> URL? in
            guard let url = item as? URL else {
                return nil
            }
            let values = try url.resourceValues(forKeys: resourceKeys)
            guard values.isRegularFile == true, ["md", "toml", "ts", "sql"].contains(url.pathExtension) else {
                return nil
            }
            return url
        }
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }

    private func relativePath(_ url: URL) -> String {
        let root = projectURL("")
        return url.path.replacingOccurrences(of: root.path + "/", with: "")
    }
}
