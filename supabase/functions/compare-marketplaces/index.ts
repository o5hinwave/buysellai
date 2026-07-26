import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  type GeminiTool,
  geminiGroundingSearchQueriesKey,
  geminiGroundingSourcesKey,
  generateJsonWithGemini,
} from "../_shared/gemini.ts";
import { consumeEarlyAccessUsage } from "../_shared/entitlements.ts";
import {
  errorResponse,
  fetchWithTimeout,
  handleOptions,
  HttpError,
  jsonResponse,
  readJson,
  readResponseJson,
  requireJsonArray,
  requireJsonObject,
  requirePost,
  timeoutFromEnv,
} from "../_shared/http.ts";

const comparisonResearchFreshnessWindowMs = 72 * 60 * 60 * 1_000;

serve(async (request) => {
  const options = handleOptions(request);
  if (options) return options;

  try {
    requirePost(request);
    const body = await readJson(request);
    const item = requireItem(body.item);
    const details = optionalItemDetails(body.details);
    const identificationProfile = optionalIdentificationProfile(body.identificationProfile);
    const candidateMarketplaces = requireCandidateMarketplaces(body.candidateMarketplaces);
    const cachedResearch = await fetchComparisonResearchCaches(
      item,
      details,
      identificationProfile,
      candidateMarketplaces,
    );
    const entitlement = await consumeEarlyAccessUsage(request, "marketplace_research", {
      estimatedAiCostCents: 4.8,
      groundedSearchCount: Math.min(candidateMarketplaces.length, 10),
    });
    const result = await generateMarketplaceComparisonJson(
      item,
      details,
      identificationProfile,
      candidateMarketplaces,
      cachedResearch,
    );
    const checkedAt = new Date().toISOString();
    const comparisons = normalizeComparisons(result, item, candidateMarketplaces, checkedAt);
    await saveComparisonResearchCache(item, details, identificationProfile, result, comparisons);

    return jsonResponse({
      checkedAt,
      comparisons,
      entitlement,
    });
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status);
    }
    return errorResponse("Marketplace comparison failed", 500);
  }
});

type ListingItem = {
  name: string;
  category: string;
  condition: string;
  originalPrice: number;
  currentPrice: number;
};

type ListingItemDetails = {
  labelOrBrand: string | null;
  sizeOrModel: string | null;
  flaws: string | null;
  included: string | null;
  extraDetails: string | null;
  marketplaceNotes: Record<string, string>;
  isLargeOrFragile: boolean;
};

type IdentificationProfile = {
  confirmedFacts: string[];
  likelyFacts: string[];
  conflictingClues: string[];
  unknownDetails: string[];
  possibleMatches: string[];
  potentiallyValuableVariants: string[];
  evidenceNeeded: string[];
  previousCorrections: string[];
  confidenceState: string | null;
};

type StructuredEvidenceSource = {
  sourceMarketplace: string | null;
  title: string | null;
  url: string | null;
  dateChecked: string | null;
  listingStatus: string | null;
  conditionAndVariant: string | null;
  comparability: string | null;
  price: number | null;
};

type NormalizedMarketplaceComparison = {
  marketplace: MarketplaceId;
  recommendationLabel: string | null;
  marketplaceFitScore: number | null;
  listPrice: number | null;
  likelyRangeLow: number | null;
  likelyRangeHigh: number | null;
  takeHomeEstimate: number | null;
  compLowPrice: number | null;
  compMedianPrice: number | null;
  compHighPrice: number | null;
  expectedSpeed: string | null;
  shippingExpectation: string | null;
  feeSummary: string | null;
  reason: string;
  evidenceSummary: string | null;
  evidenceStatus: string;
  evidenceSources: StructuredEvidenceSource[];
};

type MarketplaceResearchPlan = {
  cacheKey: string;
  cacheLookupKeys: string[];
  marketplace: MarketplaceId;
  category: string;
  condition: string;
  searchQuestions: string[];
  sourceTargets: string[];
  reason: string;
};

type MarketplaceResearchCache = {
  researchSummary: string;
  usefulFindings: string[];
  officialSources: string[];
  searchQuestions: string[];
  updatedAt: string;
};

type SupabaseServiceConfig = {
  supabaseUrl: string;
  serviceRoleKey: string;
};

const knownMarketplaceIds = [
  "ebay",
  "craigslist",
  "facebook",
  "poshmark",
  "mercari",
  "offerup",
  "depop",
  "whatnot",
  "grailed",
  "reverb",
  "etsy",
  "stockx",
  "goat",
  "kidizen",
  "vinted",
  "vestiaire",
  "therealreal",
  "swappa",
  "tradesy",
  "chairish",
  "bonanza",
  "curtsy",
  "nextdoor",
  "amazon",
  "shopify",
  "rubylane",
  "tcgplayer",
] as const;

const knownMarketplaceIdSet = new Set<string>(knownMarketplaceIds);
type MarketplaceId = typeof knownMarketplaceIds[number];

const marketplaceDisplayNames: Record<MarketplaceId, string> = {
  ebay: "eBay",
  craigslist: "Craigslist",
  facebook: "Facebook Marketplace",
  poshmark: "Poshmark",
  mercari: "Mercari",
  offerup: "OfferUp",
  depop: "Depop",
  whatnot: "Whatnot",
  grailed: "Grailed",
  reverb: "Reverb",
  etsy: "Etsy",
  stockx: "StockX",
  goat: "GOAT",
  kidizen: "Kidizen",
  vinted: "Vinted",
  vestiaire: "Vestiaire",
  therealreal: "The RealReal",
  swappa: "Swappa",
  tradesy: "Tradesy",
  chairish: "Chairish",
  bonanza: "Bonanza",
  curtsy: "Curtsy",
  nextdoor: "Nextdoor",
  amazon: "Amazon",
  shopify: "Shopify",
  rubylane: "Ruby Lane",
  tcgplayer: "TCGplayer",
};

const knownCategoryValues = [
  "Electronics",
  "Furniture",
  "Clothing",
  "Shoes",
  "Bags",
  "Jewelry",
  "Toys",
  "Kids",
  "Home",
  "Tools",
  "Sports",
  "Books",
  "Media",
  "Music",
  "Collectibles",
  "Art",
  "Other",
] as const;

const knownConditionValues = [
  "new",
  "likeNew",
  "good",
  "fair",
  "forParts",
] as const;

async function generateMarketplaceComparisonJson(
  item: ListingItem,
  details: ListingItemDetails | null,
  identificationProfile: IdentificationProfile | null,
  candidates: MarketplaceId[],
  cachedResearch: Partial<Record<MarketplaceId, MarketplaceResearchCache>>,
): Promise<Record<string, unknown>> {
  const tools: GeminiTool[] = [
    { google_search: {} },
    { url_context: {} },
  ];
  const prompt = [
    `Item: ${item.name}`,
    `Category: ${item.category}`,
    `Condition: ${item.condition}`,
    `Base observed price: ${item.currentPrice}`,
    `Seller details: ${detailsForPrompt(details)}`,
    `Item identification profile: ${identificationProfileForPrompt(identificationProfile)}`,
    `Candidate marketplaces: ${candidates.map((id) => marketplaceDisplayNames[id]).join(", ")}`,
    `Saved marketplace research: ${comparisonResearchCacheForPrompt(cachedResearch, candidates)}`,
    "Use the minimum searches needed to compare these candidates.",
    "Use saved marketplace research as memory for recent official fee, rule, source, and useful finding context; refresh only time-sensitive sold-price, active-competition, fee, rule, and demand facts that could have changed.",
    "Use confirmed profile facts as search anchors, likely facts as hypotheses, and unknown or conflicting profile clues as reasons to search narrower variants before pricing.",
    "Prioritize sold/completed listing evidence over active asking prices.",
    "Use official marketplace fee or help pages for fees and rules when available.",
    "If reliable sold evidence is unavailable for a marketplace, leave comp prices empty and say the evidence is limited.",
  ].join("\n");

  try {
    return await generateJsonWithGemini(
      compareSystemInstruction(candidates),
      [{ text: prompt }],
      comparisonResponseSchema(),
      {
        tools,
        maxOutputTokens: 4_096,
        temperature: 0.1,
      },
    );
  } catch (error) {
    if (error instanceof HttpError && error.status === 429) throw error;
    return {
      comparisons: deterministicLimitedComparisons(item, candidates),
      researchSummary: "Current marketplace research was unavailable, so BuySell should show quick estimates only.",
    };
  }
}

function compareSystemInstruction(candidates: MarketplaceId[]): string {
  return [
    "You compare resale marketplaces for BuySell AI.",
    "Return one valid JSON object only, with no markdown fences.",
    "Return a comparisons array for the candidate marketplaces only.",
    `Allowed marketplace ids: ${candidates.join(", ")}.`,
    "Each comparison should help a non-expert decide where to sell one item.",
    "Do not invent sold listings, prices, fees, dates, demand, restrictions, or source URLs.",
    "Use Google Search and URL Context for current marketplace fees, rules, sold/completed comps, active competition, and shipping or pickup expectations.",
    "Use the item identification profile to choose exact search terms; check possible matches and potentially valuable variants before assuming a generic item.",
    "If the profile says details are unknown or conflicting, mention the uncertainty and do not price or rank as a rare variant unless grounded evidence supports it.",
    "For compLowPrice, compMedianPrice, and compHighPrice, use sold/completed comparable evidence only. Do not use active asking prices for sold-price fields.",
    "Active listings and asking prices may appear in evidenceSources, but they must never populate sold comp price fields.",
    "If only active or weak evidence is available, leave sold comp price fields empty and set evidenceStatus to limited or unavailable.",
    "For every factual market result you rely on, add evidenceSources with sourceMarketplace, title, url, dateChecked, listingStatus sold/active/official/reference, conditionAndVariant, comparability, and price when grounded.",
    "Use recommendationLabel only when it truly fits: Best overall, Fastest sale, Most money, or Easiest option.",
    "Keep reason, expectedSpeed, shippingExpectation, feeSummary, and evidenceSummary short and plain.",
    "Do not use technical search-marketing acronyms.",
    "Return searchedFor and officialSources when useful for future cache or debugging.",
  ].join(" ");
}

function comparisonResponseSchema(): Record<string, unknown> {
  return {
    type: "OBJECT",
    properties: {
      researchSummary: { type: "STRING" },
      searchedFor: {
        type: "ARRAY",
        items: { type: "STRING" },
      },
      officialSources: {
        type: "ARRAY",
        items: { type: "STRING" },
      },
      comparisons: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          properties: {
            marketplace: { type: "STRING" },
            recommendationLabel: { type: "STRING" },
            marketplaceFitScore: { type: "NUMBER", minimum: 1, maximum: 100 },
            listPrice: { type: "NUMBER", minimum: 1 },
            likelyRangeLow: { type: "NUMBER", minimum: 1 },
            likelyRangeHigh: { type: "NUMBER", minimum: 1 },
            takeHomeEstimate: { type: "NUMBER", minimum: 1 },
            compLowPrice: { type: "NUMBER", minimum: 1 },
            compMedianPrice: { type: "NUMBER", minimum: 1 },
            compHighPrice: { type: "NUMBER", minimum: 1 },
            expectedSpeed: { type: "STRING" },
            shippingExpectation: { type: "STRING" },
            feeSummary: { type: "STRING" },
            reason: { type: "STRING" },
            evidenceSummary: { type: "STRING" },
            evidenceStatus: { type: "STRING" },
            evidenceSources: {
              type: "ARRAY",
              items: {
                type: "OBJECT",
                properties: {
                  sourceMarketplace: { type: "STRING" },
                  title: { type: "STRING" },
                  url: { type: "STRING" },
                  dateChecked: { type: "STRING" },
                  listingStatus: { type: "STRING" },
                  conditionAndVariant: { type: "STRING" },
                  comparability: { type: "STRING" },
                  price: { type: "NUMBER", minimum: 1 },
                },
              },
            },
          },
          required: ["marketplace", "reason", "evidenceStatus"],
        },
      },
    },
    required: ["comparisons"],
  };
}

function normalizeComparisons(
  result: Record<string, unknown>,
  item: ListingItem,
  candidates: MarketplaceId[],
  checkedAt: string,
): NormalizedMarketplaceComparison[] {
  const rows = Array.isArray(result.comparisons) ? result.comparisons : [];
  const allowed = new Set(candidates);
  const seen = new Set<string>();
  const normalized: NormalizedMarketplaceComparison[] = [];

  for (const row of rows) {
    const comparison = normalizeComparison(row, allowed, checkedAt);
    if (!comparison) continue;
    const marketplace = comparison.marketplace;
    if (seen.has(marketplace)) continue;
    seen.add(marketplace);
    normalized.push(comparison);
  }

  if (normalized.length > 0) {
    return normalized;
  }

  return deterministicLimitedComparisons(item, candidates);
}

function normalizeComparison(
  value: unknown,
  allowed: Set<MarketplaceId>,
  checkedAt: string,
): NormalizedMarketplaceComparison | null {
  const row = recordOrNull(value);
  if (!row) return null;
  const marketplace = optionalString(row.marketplace, 40)?.toLowerCase() ?? "";
  if (!knownMarketplaceIdSet.has(marketplace) || !allowed.has(marketplace as MarketplaceId)) {
    return null;
  }

  const platform = marketplace as MarketplaceId;
  const evidenceSources = cleanEvidenceSources(row.evidenceSources, platform, checkedAt);
  const soldEvidencePrices = soldComparableEvidencePrices(evidenceSources);
  const hasPricedSoldEvidence = soldEvidencePrices.length > 0;
  const evidenceStatus = normalizeEvidenceStatus(row.evidenceStatus, evidenceSources.length, soldEvidencePrices.length);

  return {
    marketplace: platform,
    recommendationLabel: normalizeRecommendationLabel(row.recommendationLabel),
    marketplaceFitScore: optionalScore(row.marketplaceFitScore),
    listPrice: optionalPositiveNumber(row.listPrice),
    likelyRangeLow: optionalPositiveNumber(row.likelyRangeLow),
    likelyRangeHigh: optionalPositiveNumber(row.likelyRangeHigh),
    takeHomeEstimate: optionalPositiveNumber(row.takeHomeEstimate),
    compLowPrice: hasPricedSoldEvidence ? lowPrice(soldEvidencePrices) : null,
    compMedianPrice: hasPricedSoldEvidence ? medianPrice(soldEvidencePrices) : null,
    compHighPrice: hasPricedSoldEvidence ? highPrice(soldEvidencePrices) : null,
    expectedSpeed: optionalCleanText(row.expectedSpeed, 80),
    shippingExpectation: optionalCleanText(row.shippingExpectation, 100),
    feeSummary: optionalCleanText(row.feeSummary, 180),
    reason: optionalCleanText(row.reason, 180) ??
      `${marketplaceDisplayNames[platform]} may fit when price and photos are clear.`,
    evidenceSummary: evidenceSummaryForDisplay(row.evidenceSummary, platform, evidenceSources, soldEvidencePrices.length),
    evidenceStatus,
    evidenceSources,
  };
}

function deterministicLimitedComparisons(
  item: ListingItem,
  candidates: MarketplaceId[],
): NormalizedMarketplaceComparison[] {
  return candidates.map((marketplace, index) => {
    const displayName = marketplaceDisplayNames[marketplace] ?? marketplace;
    return {
      marketplace,
      recommendationLabel: index === 0 ? "Best overall" : null,
      marketplaceFitScore: index === 0 ? 62 : 50,
      listPrice: Math.round(Math.max(item.currentPrice, 1)),
      likelyRangeLow: null,
      likelyRangeHigh: null,
      takeHomeEstimate: null,
      compLowPrice: null,
      compMedianPrice: null,
      compHighPrice: null,
      expectedSpeed: null,
      shippingExpectation: null,
      feeSummary: null,
      reason: `${displayName} is shown as a quick estimate until current market evidence is available.`,
      evidenceSummary: "Current sold-price evidence was unavailable for this check.",
      evidenceStatus: "unavailable",
      evidenceSources: [],
    };
  });
}

function createMarketplaceResearchPlan(
  item: ListingItem,
  platform: MarketplaceId,
  details: ListingItemDetails | null,
  identificationProfile: IdentificationProfile | null,
): MarketplaceResearchPlan {
  const displayName = marketplaceDisplayNames[platform] ?? platform;
  const currentYear = new Date().getUTCFullYear();
  const category = normalizedIdentifier(item.category);
  const condition = normalizedIdentifier(item.condition);
  const identity = researchIdentity(item, details, identificationProfile);
  const identityKey = normalizedIdentifier(identity).slice(0, 90) || "unknownitem";
  const profileKey = normalizedIdentifier(profileSearchTerms(identificationProfile).join(" ")).slice(0, 90) || "noprofile";
  const cacheKey = `${platform}:${category}:${condition}:${identityKey}:${profileKey}`;
  const cacheLookupKeys = uniqueStrings([cacheKey], 1);
  const searchQuestions = [
    `${displayName} official selling fees ${currentYear}`,
    `${displayName} sold listings ${identity} used ${item.condition}`,
    `${identity} ${profileSearchTerms(identificationProfile).join(" ")} resale sold price comparable`,
  ];

  return {
    cacheKey,
    cacheLookupKeys,
    marketplace: platform,
    category: item.category,
    condition: item.condition,
    searchQuestions: searchQuestions.slice(0, 3),
    sourceTargets: [
      "sold or completed listing pages when available",
      "reputable resale price guides or marketplace sold-result pages",
      "official marketplace help pages",
      "official fee pages",
      "public reference images only when the source and item match are clear",
    ],
    reason: `Reuse current rules, fee context, sold-price evidence, and marketplace fit notes before drafting the ${displayName} listing for ${identity}.`,
  };
}

function researchIdentity(
  item: ListingItem,
  details: ListingItemDetails | null,
  identificationProfile: IdentificationProfile | null,
): string {
  const parts = uniqueStrings([
    ...(identificationProfile?.confirmedFacts ?? []),
    ...(identificationProfile?.likelyFacts ?? []),
    ...(identificationProfile?.possibleMatches ?? []),
    details?.labelOrBrand ?? "",
    details?.sizeOrModel ?? "",
    item.name,
  ], 7);
  return parts.join(" ").slice(0, 160) || item.name;
}

async function fetchComparisonResearchCaches(
  item: ListingItem,
  details: ListingItemDetails | null,
  identificationProfile: IdentificationProfile | null,
  candidates: MarketplaceId[],
): Promise<Partial<Record<MarketplaceId, MarketplaceResearchCache>>> {
  const service = supabaseServiceConfig();
  if (!service) return {};

  const now = new Date();
  const lookupResults: Partial<Record<MarketplaceId, MarketplaceResearchCache>> = {};
  for (const marketplace of candidates) {
    const plan = createMarketplaceResearchPlan(item, marketplace, details, identificationProfile);
    const cachedResearch = await fetchComparisonResearchCache(plan, service, now);
    if (cachedResearch) {
      lookupResults[marketplace] = cachedResearch;
    }
  }
  return lookupResults;
}

async function fetchComparisonResearchCache(
  plan: MarketplaceResearchPlan,
  service: SupabaseServiceConfig,
  now: Date,
): Promise<MarketplaceResearchCache | null> {
  try {
    const nowValue = encodeURIComponent(now.toISOString());
    const select = "research_summary,useful_findings,official_sources,search_queries,updated_at";
    for (const lookupKey of plan.cacheLookupKeys) {
      const cacheKey = encodeURIComponent(lookupKey);
      const response = await fetchWithTimeout(
        `${service.supabaseUrl}/rest/v1/marketplace_research_cache?cache_key=eq.${cacheKey}&expires_at=gt.${nowValue}&select=${select}&limit=1`,
        { headers: serviceHeaders(service.serviceRoleKey) },
        supabaseServiceFetchOptions(),
      );
      if (!response.ok) continue;

      const rows = requireJsonArray(
        await readResponseJson(response, "Marketplace comparison cache response was not valid JSON"),
        "Marketplace comparison cache response was not a JSON array",
      );
      const row = rows[0];
      if (row === undefined) continue;

      const cachedResearch = marketplaceResearchCacheFromRow(row);
      if (isFreshComparisonResearchCache(cachedResearch, now)) {
        return cachedResearch;
      }
    }
    return null;
  } catch {
    return null;
  }
}

function marketplaceResearchCacheFromRow(row: unknown): MarketplaceResearchCache | null {
  const payload = requireJsonObject(row, "Marketplace comparison cache row was not a JSON object");
  const researchSummary = optionalString(payload.research_summary, 360);
  if (!researchSummary) return null;

  return {
    researchSummary,
    usefulFindings: stringArray(payload.useful_findings, 8),
    officialSources: stringArray(payload.official_sources, 8),
    searchQuestions: stringArray(payload.search_queries, 3),
    updatedAt: optionalString(payload.updated_at, 40) ?? "",
  };
}

function isFreshComparisonResearchCache(
  cachedResearch: MarketplaceResearchCache | null,
  now: Date,
): cachedResearch is MarketplaceResearchCache {
  if (!cachedResearch) return false;
  const updatedAt = Date.parse(cachedResearch.updatedAt);
  if (!Number.isFinite(updatedAt)) return false;
  const ageMs = now.getTime() - updatedAt;
  return ageMs >= 0 && ageMs <= comparisonResearchFreshnessWindowMs;
}

function comparisonResearchCacheForPrompt(
  cachedResearch: Partial<Record<MarketplaceId, MarketplaceResearchCache>>,
  candidates: MarketplaceId[],
): string {
  const summaries = candidates.flatMap((marketplace) => {
    const research = cachedResearch[marketplace];
    if (!research) return [];
    const displayName = marketplaceDisplayNames[marketplace] ?? marketplace;
    return [
      [
        `${displayName} saved research checked ${research.updatedAt || "recently"}`,
        `summary: ${research.researchSummary}`,
        research.usefulFindings.length ? `useful findings: ${research.usefulFindings.join(" | ")}` : "",
        research.officialSources.length ? `official/source references: ${research.officialSources.join(" | ")}` : "",
        research.searchQuestions.length ? `previous searches: ${research.searchQuestions.join(" | ")}` : "",
      ].filter((line) => line.length > 0).join("; "),
    ];
  });
  if (summaries.length === 0) return "none";
  return summaries.join("\n").slice(0, 2_400);
}

async function saveComparisonResearchCache(
  item: ListingItem,
  details: ListingItemDetails | null,
  identificationProfile: IdentificationProfile | null,
  result: Record<string, unknown>,
  comparisons: NormalizedMarketplaceComparison[],
): Promise<void> {
  const service = supabaseServiceConfig();
  if (!service) return;

  const searchedFor = uniqueStrings([
    ...stringArray(result.searchedFor, 3),
    ...stringArray(result[geminiGroundingSearchQueriesKey], 3),
  ], 3);
  const groundingSources = uniqueStrings([
    ...stringArray(result.officialSources, 8),
    ...stringArray(result[geminiGroundingSourcesKey], 8),
  ], 8);
  const globalResearchSummary = optionalCleanText(result.researchSummary, 360);
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1_000);

  for (const comparison of comparisons) {
    if (comparison.evidenceStatus === "unavailable") continue;

    const plan = createMarketplaceResearchPlan(item, comparison.marketplace, details, identificationProfile);
    const usefulFindings = comparisonUsefulFindings(comparison);
    const officialSources = uniqueStrings([
      ...groundingSources,
      ...evidenceSourceReferenceStrings(comparison.evidenceSources),
    ], 8);
    const hasVerifiableSources = officialSources.length > 0;
    const researchSummary = globalResearchSummary ?? comparison.evidenceSummary ?? comparison.reason;

    if (!hasVerifiableSources) continue;
    if (!researchSummary && usefulFindings.length === 0 && officialSources.length === 0) continue;

    const row = {
      cache_key: plan.cacheKey,
      marketplace: plan.marketplace,
      category: plan.category,
      condition: plan.condition,
      search_queries: searchedFor.length > 0 ? searchedFor : plan.searchQuestions,
      useful_findings: usefulFindings,
      official_sources: officialSources,
      research_summary: researchSummary || usefulFindings.join(" ") || officialSources.join(" "),
      model: Deno.env.get("GEMINI_MODEL")?.trim() || "gemini-2.5-flash",
      updated_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
    };

    try {
      const response = await fetchWithTimeout(
        `${service.supabaseUrl}/rest/v1/marketplace_research_cache?on_conflict=cache_key`,
        {
          method: "POST",
          headers: {
            ...serviceHeaders(service.serviceRoleKey),
            prefer: "resolution=merge-duplicates,return=minimal",
          },
          body: JSON.stringify(row),
        },
        supabaseServiceFetchOptions(),
      );
      if (!response.ok) continue;
    } catch {
      continue;
    }
  }
}

function comparisonUsefulFindings(comparison: NormalizedMarketplaceComparison): string[] {
  const displayName = marketplaceDisplayNames[comparison.marketplace] ?? comparison.marketplace;
  const findings = [
    comparison.evidenceSummary,
    comparison.reason,
    comparison.feeSummary ? `${displayName} fee note: ${comparison.feeSummary}` : null,
    comparison.expectedSpeed ? `${displayName} expected speed: ${comparison.expectedSpeed}` : null,
    comparison.shippingExpectation ? `${displayName} fulfillment: ${comparison.shippingExpectation}` : null,
    comparison.listPrice ? `${displayName} recommended list price: ${comparison.listPrice}` : null,
    comparison.takeHomeEstimate ? `${displayName} estimated take-home: ${comparison.takeHomeEstimate}` : null,
    comparison.likelyRangeLow && comparison.likelyRangeHigh
      ? `${displayName} likely sale range: ${comparison.likelyRangeLow}-${comparison.likelyRangeHigh}`
      : null,
    comparison.compLowPrice && comparison.compMedianPrice && comparison.compHighPrice
      ? `${displayName} sold comp range low/median/high: ${comparison.compLowPrice}/${comparison.compMedianPrice}/${comparison.compHighPrice}`
      : null,
    ...comparison.evidenceSources.map(evidenceSourceFinding),
  ];
  return uniqueStrings(findings, 8);
}

function evidenceSourceFinding(source: StructuredEvidenceSource): string | null {
  const parts = [
    source.sourceMarketplace,
    source.listingStatus,
    source.title,
    source.conditionAndVariant,
    source.comparability,
    source.price ? `price ${source.price}` : "",
  ].filter((part) => part && part.trim().length > 0);
  return parts.length > 0 ? parts.join(" · ").slice(0, 260) : null;
}

function evidenceSourceReferenceStrings(sources: StructuredEvidenceSource[]): string[] {
  return uniqueStrings(sources.map((source) => {
    if (source.title && source.url) return `${source.title}: ${source.url}`;
    return source.url ?? source.title;
  }), 8);
}

function isSoldComparableEvidenceSource(source: StructuredEvidenceSource): boolean {
  return source.listingStatus === "Sold" &&
    source.price !== null &&
    hasEvidenceSourceReference(source);
}

function soldComparableEvidencePrices(sources: StructuredEvidenceSource[]): number[] {
  return sources
    .filter(isSoldComparableEvidenceSource)
    .map((source) => source.price)
    .filter((price): price is number => typeof price === "number" && Number.isFinite(price) && price > 0)
    .sort((lhs, rhs) => lhs - rhs);
}

function lowPrice(prices: number[]): number | null {
  return prices.length > 0 ? roundMoney(prices[0]) : null;
}

function highPrice(prices: number[]): number | null {
  return prices.length > 0 ? roundMoney(prices[prices.length - 1]) : null;
}

function medianPrice(prices: number[]): number | null {
  if (prices.length === 0) return null;
  const middle = Math.floor(prices.length / 2);
  if (prices.length % 2 === 1) return roundMoney(prices[middle]);
  return roundMoney((prices[middle - 1] + prices[middle]) / 2);
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

function evidenceSummaryForDisplay(
  value: unknown,
  platform: MarketplaceId,
  evidenceSources: StructuredEvidenceSource[],
  soldEvidenceCount: number,
): string | null {
  const summary = optionalCleanText(value, 220);
  if (soldEvidenceCount > 0) return summary;
  if (evidenceSources.length === 0) return summary;

  const displayName = marketplaceDisplayNames[platform] ?? platform;
  const hasActiveEvidence = evidenceSources.some((source) => source.listingStatus === "Active");
  const hasOfficialEvidence = evidenceSources.some((source) => source.listingStatus === "Official");
  if (hasActiveEvidence && hasOfficialEvidence) {
    return `${displayName} has active or official evidence, but no verified sold comps for this check.`;
  }
  if (hasActiveEvidence) {
    return `${displayName} has active listing evidence, but no verified sold comps for this check.`;
  }
  if (hasOfficialEvidence) {
    return `${displayName} has official guidance, but no verified sold comps for this check.`;
  }
  return summary ?? `${displayName} evidence is limited because sold comps were not verified.`;
}

function hasEvidenceSourceReference(source: StructuredEvidenceSource): boolean {
  return Boolean(source.url || source.title);
}

function cleanEvidenceSources(
  value: unknown,
  platform: MarketplaceId,
  checkedAt: string,
): StructuredEvidenceSource[] {
  if (!Array.isArray(value)) return [];
  const sources: StructuredEvidenceSource[] = [];
  const seen = new Set<string>();

  for (const entry of value) {
    const record = recordOrNull(entry);
    if (!record) continue;

    const url = optionalReferenceURL(record.url ?? record.sourceUrl ?? record.sourceURL);
    const title = optionalCleanText(record.title ?? record.sourceTitle, 120);
    const rawSourceMarketplace = optionalCleanText(record.sourceMarketplace ?? record.marketplace, 48);
    const listingStatus = cleanListingStatus(
      record.listingStatus ?? record.status ?? record.sourceType ?? listingStatusFromPriceFields(record),
    );
    const conditionAndVariant = optionalCleanText(
      record.conditionAndVariant ?? record.conditionVariant ?? record.variant,
      100,
    );
    const comparability = optionalCleanText(record.comparability ?? record.confidence, 72);
    const price = optionalPositiveNumber(record.price ?? record.soldPrice ?? record.activePrice);
    const dateChecked = optionalCleanText(record.dateChecked ?? record.checkedDate, 32) ??
      checkedAt.slice(0, 10);

    if (!rawSourceMarketplace && !title && !url && !listingStatus && !conditionAndVariant && !comparability && price === null) {
      continue;
    }

    const sourceMarketplace = rawSourceMarketplace ?? marketplaceDisplayNames[platform] ?? platform;
    const key = [
      sourceMarketplace,
      title,
      url,
      dateChecked,
      listingStatus,
      conditionAndVariant,
      comparability,
      price?.toString() ?? "",
    ].join("|");
    if (seen.has(key)) continue;
    seen.add(key);

    sources.push({
      sourceMarketplace,
      title,
      url,
      dateChecked,
      listingStatus,
      conditionAndVariant,
      comparability,
      price,
    });
    if (sources.length >= 4) break;
  }

  return sources;
}

function requireItem(value: unknown): ListingItem {
  const item = requireRecord(value, "item must be an object");
  const originalPrice = asPositiveNumber(item.originalPrice, "originalPrice");
  const currentPrice = asPositiveNumber(item.currentPrice, "currentPrice");

  return {
    name: asString(item.name, "name"),
    category: requireCategory(item.category),
    condition: requireCondition(item.condition),
    originalPrice,
    currentPrice,
  };
}

function optionalItemDetails(value: unknown): ListingItemDetails | null {
  if (value === undefined || value === null) return null;
  const details = recordOrNull(value);
  if (!details) return null;

  const cleanDetails: ListingItemDetails = {
    labelOrBrand: optionalString(details.labelOrBrand, 80),
    sizeOrModel: optionalString(details.sizeOrModel, 96),
    flaws: optionalString(details.flaws, 140),
    included: optionalString(details.included, 120),
    extraDetails: optionalString(details.extraDetails, 180),
    marketplaceNotes: optionalMarketplaceNotes(details.marketplaceNotes),
    isLargeOrFragile: details.isLargeOrFragile === true,
  };

  if (
    cleanDetails.labelOrBrand === null &&
    cleanDetails.sizeOrModel === null &&
    cleanDetails.flaws === null &&
    cleanDetails.included === null &&
    cleanDetails.extraDetails === null &&
    Object.keys(cleanDetails.marketplaceNotes).length === 0 &&
    cleanDetails.isLargeOrFragile === false
  ) {
    return null;
  }

  return cleanDetails;
}

function optionalIdentificationProfile(value: unknown): IdentificationProfile | null {
  const record = recordOrNull(value);
  if (!record) return null;

  const profile: IdentificationProfile = {
    confirmedFacts: stringArray(record.confirmedFacts, 6, 100),
    likelyFacts: stringArray(record.likelyFacts, 6, 100),
    conflictingClues: stringArray(record.conflictingClues, 4, 100),
    unknownDetails: stringArray(record.unknownDetails, 6, 100),
    possibleMatches: stringArray(record.possibleMatches, 3, 100),
    potentiallyValuableVariants: stringArray(record.potentiallyValuableVariants, 4, 120),
    evidenceNeeded: stringArray(record.evidenceNeeded, 5, 120),
    previousCorrections: stringArray(record.previousCorrections, 4, 100),
    confidenceState: optionalConfidenceState(record.confidenceState),
  };

  if (identificationProfileValues(profile).length === 0) {
    return null;
  }

  return profile;
}

function optionalConfidenceState(value: unknown): string | null {
  const normalized = normalizedIdentifier(optionalString(value, 40) ?? "");
  switch (normalized) {
    case "confirmed":
      return "confirmed";
    case "likely":
      return "likely";
    case "stillchecking":
      return "stillChecking";
    case "notenoughevidence":
      return "notEnoughEvidence";
    default:
      return null;
  }
}

function optionalMarketplaceNotes(value: unknown): Record<string, string> {
  const record = recordOrNull(value);
  if (!record) return {};

  const notes: Record<string, string> = {};
  for (const [key, entry] of Object.entries(record)) {
    const marketplace = key.toLowerCase();
    if (!knownMarketplaceIdSet.has(marketplace)) continue;
    const text = optionalString(entry, 220);
    if (!text) continue;
    notes[marketplace] = text;
  }
  return notes;
}

function requireCandidateMarketplaces(value: unknown): MarketplaceId[] {
  if (!Array.isArray(value)) {
    throw new HttpError("candidateMarketplaces must be an array", 400);
  }
  const candidates: MarketplaceId[] = [];
  for (const entry of value) {
    const id = optionalString(entry, 40)?.toLowerCase();
    if (!id || !knownMarketplaceIdSet.has(id) || candidates.includes(id as MarketplaceId)) {
      continue;
    }
    candidates.push(id as MarketplaceId);
    if (candidates.length >= 10) break;
  }
  if (candidates.length === 0) {
    throw new HttpError("candidateMarketplaces must include a supported marketplace", 400);
  }
  return candidates;
}

function detailsForPrompt(details: ListingItemDetails | null): string {
  if (!details) return "none";
  return [
    details.labelOrBrand ? `Brand or maker: ${details.labelOrBrand}` : "",
    details.sizeOrModel ? `Size, model, or measurement: ${details.sizeOrModel}` : "",
    details.flaws ? `Flaws or damage: ${details.flaws}` : "",
    details.included ? `Included items: ${details.included}` : "",
    details.extraDetails ? `Extra seller note: ${details.extraDetails}` : "",
    marketplaceNoteSummary(details.marketplaceNotes),
    details.isLargeOrFragile ? "Shipping note: big, heavy, or fragile" : "",
  ].filter((line) => line.length > 0).join("; ") || "none";
}

function identificationProfileForPrompt(profile: IdentificationProfile | null): string {
  if (!profile) return "none";
  const lines = [
    profile.confidenceState ? `Confidence: ${profile.confidenceState}` : "",
    profile.confirmedFacts.length ? `Confirmed facts: ${profile.confirmedFacts.join("; ")}` : "",
    profile.likelyFacts.length ? `Likely facts: ${profile.likelyFacts.join("; ")}` : "",
    profile.possibleMatches.length ? `Possible matches: ${profile.possibleMatches.join("; ")}` : "",
    profile.potentiallyValuableVariants.length
      ? `Potentially valuable variants to verify: ${profile.potentiallyValuableVariants.join("; ")}`
      : "",
    profile.unknownDetails.length ? `Unknown details: ${profile.unknownDetails.join("; ")}` : "",
    profile.conflictingClues.length ? `Conflicting clues: ${profile.conflictingClues.join("; ")}` : "",
    profile.evidenceNeeded.length ? `Evidence still needed: ${profile.evidenceNeeded.join("; ")}` : "",
    profile.previousCorrections.length ? `User corrections: ${profile.previousCorrections.join("; ")}` : "",
  ].filter((line) => line.length > 0);
  return lines.join(" | ") || "none";
}

function profileSearchTerms(profile: IdentificationProfile | null): string[] {
  if (!profile) return [];
  return uniqueStrings([
    ...profile.confirmedFacts,
    ...profile.likelyFacts,
    ...profile.possibleMatches,
    ...profile.potentiallyValuableVariants,
    ...profile.evidenceNeeded,
  ], 6);
}

function identificationProfileValues(profile: IdentificationProfile): string[] {
  return [
    ...profile.confirmedFacts,
    ...profile.likelyFacts,
    ...profile.conflictingClues,
    ...profile.unknownDetails,
    ...profile.possibleMatches,
    ...profile.potentiallyValuableVariants,
    ...profile.evidenceNeeded,
    ...profile.previousCorrections,
    profile.confidenceState ?? "",
  ].filter((value) => value.length > 0);
}

function marketplaceNoteSummary(notes: Record<string, string>): string {
  const values = Object.entries(notes)
    .slice(0, 4)
    .map(([marketplace, value]) => {
      const displayName = marketplaceDisplayNames[marketplace as MarketplaceId] ?? marketplace;
      return `${displayName}: ${value}`;
    });
  return values.length > 0 ? `Marketplace notes: ${values.join(" | ")}` : "";
}

function requireCategory(value: unknown): string {
  return asKnownValue(value, "category", knownCategoryValues);
}

function requireCondition(value: unknown): string {
  return asKnownValue(value, "condition", knownConditionValues);
}

function asKnownValue<T extends string>(value: unknown, field: string, knownValues: readonly T[]): T {
  const normalized = normalizedIdentifier(asString(value, field));
  const knownValue = knownValues.find((candidate) => normalizedIdentifier(candidate) === normalized);
  if (!knownValue) throw new HttpError(`Unsupported ${field}`, 400);
  return knownValue;
}

function asString(value: unknown, field: string): string {
  if (typeof value !== "string" || !value.trim()) {
    throw new HttpError(`Missing ${field}`, 400);
  }
  return value.trim();
}

function asPositiveNumber(value: unknown, field: string): number {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) {
    throw new HttpError(`${field} must be greater than zero`, 400);
  }
  return number;
}

function requireRecord(value: unknown, message: string): Record<string, unknown> {
  const record = recordOrNull(value);
  if (!record) throw new HttpError(message, 400);
  return record;
}

function recordOrNull(value: unknown): Record<string, unknown> | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function optionalString(value: unknown, maxLength = 1_200): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.slice(0, maxLength);
}

function stringArray(value: unknown, maxItems = 6, maxLength = 260): string[] {
  if (!Array.isArray(value)) return [];
  const values: string[] = [];
  for (const entry of value) {
    const text = optionalString(entry, maxLength);
    if (text && values.includes(text) === false) {
      values.push(text);
    }
    if (values.length >= maxItems) break;
  }
  return values;
}

function uniqueStrings(values: Array<string | null | undefined>, maxItems: number): string[] {
  const unique: string[] = [];
  for (const value of values) {
    const text = value?.trim();
    if (!text || unique.includes(text)) continue;
    unique.push(text);
    if (unique.length >= maxItems) break;
  }
  return unique;
}

function optionalCleanText(value: unknown, maxLength: number): string | null {
  const text = optionalString(value, maxLength);
  if (!text || text.includes("```")) return null;
  return text.replace(/\s+/g, " ").trim().slice(0, maxLength) || null;
}

function optionalPositiveNumber(value: unknown): number | null {
  const number = Number(value);
  if (Number.isFinite(number) && number > 0) return Math.round(number * 100) / 100;
  return null;
}

function optionalScore(value: unknown): number | null {
  const number = Number(value);
  if (!Number.isFinite(number)) return null;
  return Math.min(Math.max(Math.round(number), 1), 100);
}

function optionalReferenceURL(value: unknown): string | null {
  const text = optionalCleanText(value, 500);
  if (!text) return null;
  try {
    const url = new URL(text);
    if (url.protocol !== "https:" && url.protocol !== "http:") return null;
    return url.toString();
  } catch {
    return null;
  }
}

function normalizeRecommendationLabel(value: unknown): string | null {
  const text = optionalCleanText(value, 32);
  if (!text) return null;
  const normalized = normalizedIdentifier(text);
  switch (normalized) {
    case "bestoverall":
      return "Best overall";
    case "fastestsale":
      return "Fastest sale";
    case "mostmoney":
      return "Most money";
    case "easiestoption":
      return "Easiest option";
    default:
      return null;
  }
}

function normalizeEvidenceStatus(value: unknown, evidenceSourceCount: number, soldEvidenceCount: number): string {
  const normalized = normalizedIdentifier(optionalString(value, 32) ?? "");
  switch (normalized) {
    case "grounded":
    case "verified":
      return soldEvidenceCount > 0 ? "grounded" : "limited";
    case "limited":
    case "partial":
      return "limited";
    default:
      if (evidenceSourceCount === 0) return "unavailable";
      return soldEvidenceCount > 0 ? "grounded" : "limited";
  }
}

function cleanListingStatus(value: unknown): string | null {
  const text = optionalCleanText(value, 32);
  if (!text) return null;
  switch (normalizedIdentifier(text)) {
    case "sold":
    case "soldlisting":
    case "soldsale":
    case "completed":
    case "completeditem":
    case "completedlisting":
    case "completedsale":
    case "ended":
    case "endeditem":
    case "endedlisting":
    case "soldcompleted":
    case "completedsold":
    case "solditem":
      return "Sold";
    case "active":
    case "activelisting":
    case "asking":
    case "askingprice":
    case "currentasking":
      return "Active";
    case "official":
    case "officialmarketplace":
      return "Official";
    case "reference":
    case "image":
    case "referenceimage":
      return "Reference";
    default:
      return text;
  }
}

function listingStatusFromPriceFields(record: Record<string, unknown>): string | null {
  if (optionalPositiveNumber(record.soldPrice) !== null) return "Sold";
  if (optionalPositiveNumber(record.activePrice ?? record.askingPrice) !== null) return "Active";
  return null;
}

function normalizedIdentifier(value: string): string {
  return value.toLowerCase().replace(/[\s_-]+/g, "");
}

function supabaseServiceConfig(): SupabaseServiceConfig | null {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim().replace(/\/+$/, "");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (!supabaseUrl || !serviceRoleKey) {
    return null;
  }
  return { supabaseUrl, serviceRoleKey };
}

function serviceHeaders(serviceRoleKey: string): HeadersInit {
  return {
    authorization: `Bearer ${serviceRoleKey}`,
    apikey: serviceRoleKey,
    "content-type": "application/json",
  };
}

function supabaseServiceFetchOptions() {
  return {
    timeoutMs: timeoutFromEnv("SUPABASE_SERVICE_TIMEOUT_MS", 8_000),
    timeoutMessage: "Supabase service request timed out",
    transportMessage: "Supabase service transport failed",
  };
}
