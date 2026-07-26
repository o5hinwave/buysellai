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

const selectedComparisonFreshnessWindowMs = 72 * 60 * 60 * 1_000;
const finalListingResearchFreshnessWindowMs = 24 * 60 * 60 * 1_000;

serve(async (request) => {
  const options = handleOptions(request);
  if (options) return options;

  try {
    requirePost(request);
    const body = await readJson(request);
    const item = requireItem(body.item);
    const platform = requireMarketplace(body.platform);
    const details = optionalItemDetails(body.details);
    const identificationProfile = optionalIdentificationProfile(body.identificationProfile);
    const imageDataUrl = optionalImageDataUrl(body.imageDataUrl);
    const clientPlaybook = optionalMarketplacePlaybook(body.marketplacePlaybook);
    const priorComparison = optionalMarketplaceComparison(body.marketplaceComparison, platform);
    const profile = profileWithClientPlaybook(marketplaceProfiles[platform], clientPlaybook);
    let imageEvidence: ListingImageEvidence | null = null;
    let researchPlan = createMarketplaceResearchPlan(item, platform, profile, details, null, identificationProfile);
    let cachedResearch = marketplaceComparisonAsResearch(priorComparison, researchPlan);
    if (!cachedResearch) {
      cachedResearch = await fetchMarketplaceResearchCache(researchPlan);
    }

    if (!isFreshMarketplaceResearchCache(cachedResearch, new Date()) && imageDataUrl) {
      imageEvidence = await fetchVisionWebDetectionEvidence(imageDataUrl);
      researchPlan = createMarketplaceResearchPlan(item, platform, profile, details, imageEvidence, identificationProfile);
      const imageResearch = marketplaceComparisonAsResearch(priorComparison, researchPlan);
      if (imageResearch) {
        cachedResearch = imageResearch;
      } else {
        const imageCachedResearch = await fetchMarketplaceResearchCache(researchPlan);
        if (imageCachedResearch) {
          cachedResearch = imageCachedResearch;
        }
      }
    }

    const now = new Date();
    const finalResearchRefreshReason = finalListingResearchRefreshReason(
      cachedResearch,
      priorComparison,
      now,
    );
    const usesCachedResearch = isFreshMarketplaceResearchCache(cachedResearch, now) &&
      finalResearchRefreshReason === null;
    const entitlement = await consumeEarlyAccessUsage(request, "listing_generation", {
      estimatedAiCostCents: usesCachedResearch ? 1.4 : 2.8,
      groundedSearchCount: usesCachedResearch ? 0 : researchPlan.searchQuestions.length,
    });

    const promptParts = [{
        text: [
          `Marketplace: ${platform}`,
          `Marketplace playbook version: ${profile.playbookVersionIdentifier ?? "server default"}`,
          `Marketplace playbook schema: ${profile.playbookSchemaVersion ?? "server default"}`,
          `Marketplace playbook source dates: fees ${profile.playbookFeeSourcesLastChecked ?? "server default"}, rules ${profile.playbookRuleSourcesLastVerified ?? "server default"}`,
          `Marketplace title formula: ${profile.titleFormula}`,
          `Marketplace search focus: ${profile.searchFocus}`,
          `Photo guidance to mention if helpful: ${profile.photoGuidance}`,
          `Featured guidance to respect: ${profile.featuredGuidance}`,
          `Marketplace required fields: ${profile.requiredFields?.join(", ") ?? "server default"}`,
          `High-impact optional fields: ${profile.highImpactOptionalFields?.join(", ") ?? "server default"}`,
          `Recommended photo sequence: ${profile.recommendedPhotoSequence?.join(", ") ?? "server default"}`,
          `Pricing format: ${profile.pricingFormat ?? "server default"}`,
          `Shipping or pickup guidance: ${profile.shippingOrPickupGuidance ?? "server default"}`,
          `Official post URL: ${profile.officialPostURLString ?? "server default"}`,
          `Official how-to URL: ${profile.officialHowToURLString ?? "server default"}`,
          `Marketplace rule sources: ${profile.ruleSourceURLs?.join(", ") ?? "server default"}`,
          `Rule source last verified: ${profile.ruleSourceLastVerified ?? "server default"}`,
          `Minimal marketplace research plan: ${JSON.stringify(researchPlan)}`,
          `Selected marketplace comparison: ${priorComparison ? JSON.stringify(priorComparison) : "none"}`,
          `Saved marketplace research: ${cachedResearch ? JSON.stringify(cachedResearch) : "none"}`,
          `Saved marketplace research freshness: ${cachedResearch ? (usesCachedResearch ? "fresh" : "stale - refresh current price, fee, and rule facts before final listing") : "none"}`,
          `Focused final research refresh: ${finalResearchRefreshReason ?? "not needed"}`,
          `Visual web evidence: ${imageEvidence ? JSON.stringify(imageEvidence) : "none"}`,
          `Item identification profile: ${identificationProfileForPrompt(identificationProfile)}`,
          `Item: ${item.name}`,
          `Category: ${item.category}`,
          `Condition: ${item.condition}`,
          `Original price: ${item.originalPrice}`,
          `Current price: ${item.currentPrice}`,
          `Seller details: ${detailsForPrompt(details, platform)}`,
        ].join("\n"),
      }];
    const result = await generateListingDraftJson({
      profile,
      usesCachedResearch,
      promptParts,
      item,
      platform,
      details,
      identificationProfile,
    });

    const draft = requireStructuredListingDraft(
      result,
      item,
      platform,
      profile,
      priorComparison,
      details,
      identificationProfile,
    );
    const listing = formatListingDraft(draft);
    requireCleanListing(listing, profile.titleMaxCharacters);
    await saveMarketplaceResearchCache(researchPlan, result);
    return jsonResponse({ listing, draft, entitlement });
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status);
    }
    return errorResponse("Listing generation failed", 500);
  }
});

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

type PriorMarketplaceComparison = {
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
  reason: string | null;
  evidenceSummary: string | null;
  evidenceStatus: string | null;
  evidenceSources: StructuredEvidenceSource[];
};

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

type ImageDataUrl = {
  base64: string;
};

type ListingImageEvidence = {
  bestGuessLabels: string[];
  matchingPageTitles: string[];
  matchingImageUrls: string[];
  similarImageUrls: string[];
};

type StructuredListingDraft = {
  title: string;
  description: string;
  listPrice: number;
  likelySalePrice: number;
  takeHomeEstimate: number;
  firstPhoto: string;
  missingPhotoPrompt: string | null;
  missingInfoWarnings: string[];
  fitReason: string;
  postingNotes: string[];
  itemSpecifics: string[];
  tags: string[];
  compLowPrice: number | null;
  compHighPrice: number | null;
  compMedianPrice: number | null;
  feeSummary: string | null;
  pricingStrategy: string | null;
  evidenceSummary: string | null;
  referenceImageURL: string | null;
  publicImageQuery: string | null;
  evidenceSources: StructuredEvidenceSource[];
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

type GenerateListingDraftJsonInput = {
  profile: MarketplaceListingProfile;
  usesCachedResearch: boolean;
  promptParts: Array<{ text: string }>;
  item: ListingItem;
  platform: MarketplaceId;
  details: ListingItemDetails | null;
  identificationProfile: IdentificationProfile | null;
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

type MarketplaceListingProfile = {
  playbookVersionIdentifier?: string;
  playbookSchemaVersion?: number;
  playbookFeeSourcesLastChecked?: string;
  playbookRuleSourcesLastVerified?: string;
  titleMaxCharacters: number;
  titleFormula: string;
  searchFocus: string;
  photoGuidance: string;
  featuredGuidance: string;
  requiredFields?: string[];
  highImpactOptionalFields?: string[];
  recommendedPhotoSequence?: string[];
  pricingFormat?: string;
  shippingOrPickupGuidance?: string;
  officialPostURLString?: string;
  officialHowToURLString?: string;
  ruleSourceURLs?: string[];
  ruleSourceLastVerified?: string;
  postingSurface?: string;
};

type MarketplaceListingPlaybookInput = {
  playbookVersionIdentifier?: string;
  playbookSchemaVersion?: number;
  playbookFeeSourcesLastChecked?: string;
  playbookRuleSourcesLastVerified?: string;
  titleCharacterLimit?: number;
  titleFormula?: string;
  descriptionGuidance?: string;
  requiredFields: string[];
  highImpactOptionalFields: string[];
  recommendedPhotoSequence: string[];
  pricingFormat?: string;
  shippingOrPickupGuidance?: string;
  officialPostURLString?: string;
  officialHowToURLString?: string;
  ruleSourceURLs: string[];
  ruleSourceLastVerified?: string;
  postingSurface?: string;
};

function profileWithClientPlaybook(
  base: MarketplaceListingProfile,
  playbook: MarketplaceListingPlaybookInput | null,
): MarketplaceListingProfile {
  if (!playbook) return base;

  return {
    ...base,
    playbookVersionIdentifier: playbook.playbookVersionIdentifier ?? base.playbookVersionIdentifier,
    playbookSchemaVersion: playbook.playbookSchemaVersion ?? base.playbookSchemaVersion,
    playbookFeeSourcesLastChecked: playbook.playbookFeeSourcesLastChecked ?? base.playbookFeeSourcesLastChecked,
    playbookRuleSourcesLastVerified: playbook.playbookRuleSourcesLastVerified ?? base.playbookRuleSourcesLastVerified,
    titleMaxCharacters: playbook.titleCharacterLimit ?? base.titleMaxCharacters,
    titleFormula: playbook.titleFormula ?? base.titleFormula,
    featuredGuidance: playbook.descriptionGuidance ?? base.featuredGuidance,
    requiredFields: playbook.requiredFields.length > 0 ? playbook.requiredFields : base.requiredFields,
    highImpactOptionalFields: playbook.highImpactOptionalFields.length > 0
      ? playbook.highImpactOptionalFields
      : base.highImpactOptionalFields,
    recommendedPhotoSequence: playbook.recommendedPhotoSequence.length > 0
      ? playbook.recommendedPhotoSequence
      : base.recommendedPhotoSequence,
    pricingFormat: playbook.pricingFormat ?? base.pricingFormat,
    shippingOrPickupGuidance: playbook.shippingOrPickupGuidance ?? base.shippingOrPickupGuidance,
    officialPostURLString: playbook.officialPostURLString ?? base.officialPostURLString,
    officialHowToURLString: playbook.officialHowToURLString ?? base.officialHowToURLString,
    ruleSourceURLs: playbook.ruleSourceURLs.length > 0 ? playbook.ruleSourceURLs : base.ruleSourceURLs,
    ruleSourceLastVerified: playbook.ruleSourceLastVerified ?? base.ruleSourceLastVerified,
    postingSurface: playbook.postingSurface ?? base.postingSurface,
  };
}

function listingSystemInstruction(
  profile: MarketplaceListingProfile,
  usesCachedResearch: boolean,
): string {
  return [
    "You write concise copy-paste resale listings for BuySell AI.",
    "Return one valid JSON object only, with no markdown fences.",
    "Return structured draft fields only; BuySell formats the final listing text.",
    "Do not return a listing field, markdown, preambles, watermarks, or section headings.",
    "Required fields: title, description, listPrice, likelySalePrice, takeHomeEstimate, firstPhoto, fitReason.",
    "Optional fields: missingPhotoPrompt, missingInfoWarnings, postingNotes, itemSpecifics, tags, researchSummary, usefulFindings, officialSources, searchedFor.",
    "Optional evidence fields: compLowPrice, compHighPrice, compMedianPrice, feeSummary, pricingStrategy, evidenceSummary, referenceImageURL, publicImageQuery, evidenceSources.",
    "title must be body text only and description must be body text only.",
    "Tailor the title and description for the marketplace provided, but never keyword-stuff.",
    "Use the provided marketplace playbook required fields and recommended photo sequence when they are present.",
    "Set missingInfoWarnings for required playbook fields that remain unverified or unknown.",
    "Do not contradict the official post URL, official how-to URL, or marketplace source verification notes.",
    "Use the item identification profile as the working memory from the scan conversation.",
    "Treat confirmed profile facts as search anchors, likely facts as hypotheses, and possible matches or valuable variants as checks to resolve before pricing.",
    "If profile details are unknown or conflicting, add missingInfoWarnings and avoid claims about rarity, authenticity, edition, model, size, material, or value unless provided or grounded.",
    usesCachedResearch
      ? "Use the saved marketplace research provided. Do not broaden beyond it."
      : "Use Google Search and URL Context only for the minimal research plan provided.",
    "When a selected marketplace comparison is provided, reuse its sold-price range, fee summary, expected speed, shipping expectation, and evidenceSources instead of running a broader search unless the data is unavailable or contradicted by verified item facts.",
    "Prefer official marketplace guidance over stale assumptions.",
    "If saved marketplace research is marked stale, treat it as memory only and refresh current price, fee, sold-comp, and rule facts before final listing.",
    "After the item identity is known, use grounded search for real marketplace fees, sold/completed comps, comparable price history, and marketplace rules.",
    "Distinguish sold/completed comps from active asking prices. Use compLowPrice, compHighPrice, and compMedianPrice only when grounded sold/completed evidence supports them.",
    "Active listings and asking prices may appear in evidenceSources, but they must never populate sold comp price fields.",
    "If only active listings or weak matches are available, explain the limitation in evidenceSummary and leave unsupported comp price fields empty.",
    "For every factual market result you rely on, add one evidenceSources object with sourceMarketplace, title, url when available, dateChecked, listingStatus sold/active/official/reference, conditionAndVariant, comparability, and price when grounded.",
    "Do not add evidenceSources entries for guessed prices, unsupported comps, or unverified marketplace claims.",
    "Use seller details and visual web evidence when present. Never invent brand, model, size, defects, sold prices, fees, or public image URLs.",
    "Set missingInfoWarnings to short plain warnings for any unverified fact that could affect trust, price, marketplace fit, shipping, or posting. Leave it empty when nothing important is missing.",
    "referenceImageURL must be a public image URL from visual web evidence or grounded search that is clearly the same or a close comparable item. Leave it empty if uncertain.",
    "pricingStrategy should be a plain instruction for a non-expert seller: where to list, what offer range to accept, and why.",
    "feeSummary should be short and grounded in official marketplace fee guidance when available.",
    "Do not use technical search-marketing acronyms in the listing or any returned field.",
    "Return usefulFindings, officialSources, and searchedFor only when the finding can help future listings.",
    `Keep TITLE at or below ${profile.titleMaxCharacters} characters.`,
    "Only use facts provided by the item name, category, condition, price, seller details, visual evidence, and grounded research.",
    "Do not add tax language or follow-up questions.",
    "Keep the tone warm, direct, and useful for a person selling one thing.",
  ].join(" ");
}

async function generateListingDraftJson(
  input: GenerateListingDraftJsonInput,
): Promise<Record<string, unknown>> {
  const responseSchema = listingDraftResponseSchema();
  const tools: GeminiTool[] = input.usesCachedResearch ? [] : [
    { url_context: {} },
    { google_search: {} },
  ];

  try {
    return await generateJsonWithGemini(
      listingSystemInstruction(input.profile, input.usesCachedResearch),
      input.promptParts,
      responseSchema,
      {
        tools,
        maxOutputTokens: 4_096,
      },
    );
  } catch (error) {
    if (!isRecoverableDraftProviderError(error)) throw error;
    if (isRateLimitedProviderError(error)) throw error;
  }

  if (tools.length > 0) {
    try {
      return await generateJsonWithGemini(
        listingSystemInstruction(input.profile, true),
        [
          ...input.promptParts,
          {
            text: [
              "Grounded research returned no final draft text.",
              "Create the listing from only the item facts, marketplace profile guidance, and saved research shown above.",
              "Do not claim current fees, sold prices, public image URLs, rarity, brand, model, size, or defects unless those facts are already provided.",
              "Leave unsupported comp, fee, evidence, evidenceSources, referenceImageURL, and publicImageQuery fields empty.",
            ].join(" "),
          },
        ],
        responseSchema,
        {
          tools: [],
          maxOutputTokens: 2_048,
          temperature: 0.1,
        },
      );
    } catch (error) {
      if (!isRecoverableDraftProviderError(error)) throw error;
      if (isRateLimitedProviderError(error)) throw error;
    }
  }

  return deterministicListingDraft(
    input.item,
    input.platform,
    input.profile,
    input.details,
    input.identificationProfile,
  );
}

function listingDraftResponseSchema(): Record<string, unknown> {
  return {
    type: "OBJECT",
    properties: {
      title: { type: "STRING" },
      description: { type: "STRING" },
      listPrice: { type: "NUMBER", minimum: 1 },
      likelySalePrice: { type: "NUMBER", minimum: 1 },
      takeHomeEstimate: { type: "NUMBER", minimum: 1 },
      firstPhoto: { type: "STRING" },
      missingPhotoPrompt: { type: "STRING" },
      missingInfoWarnings: {
        type: "ARRAY",
        items: { type: "STRING" },
      },
      fitReason: { type: "STRING" },
      postingNotes: {
        type: "ARRAY",
        items: { type: "STRING" },
      },
      itemSpecifics: {
        type: "ARRAY",
        items: { type: "STRING" },
      },
      tags: {
        type: "ARRAY",
        items: { type: "STRING" },
      },
      compLowPrice: { type: "NUMBER", minimum: 1 },
      compHighPrice: { type: "NUMBER", minimum: 1 },
      compMedianPrice: { type: "NUMBER", minimum: 1 },
      feeSummary: { type: "STRING" },
      pricingStrategy: { type: "STRING" },
      evidenceSummary: { type: "STRING" },
      referenceImageURL: { type: "STRING" },
      publicImageQuery: { type: "STRING" },
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
      researchSummary: { type: "STRING" },
      usefulFindings: {
        type: "ARRAY",
        items: { type: "STRING" },
      },
      officialSources: {
        type: "ARRAY",
        items: { type: "STRING" },
      },
      searchedFor: {
        type: "ARRAY",
        items: { type: "STRING" },
      },
    },
    required: [
      "title",
      "description",
      "listPrice",
      "likelySalePrice",
      "takeHomeEstimate",
      "firstPhoto",
      "fitReason",
    ],
  };
}

function deterministicListingDraft(
  item: ListingItem,
  platform: MarketplaceId,
  profile: MarketplaceListingProfile,
  details: ListingItemDetails | null,
  identificationProfile: IdentificationProfile | null,
): Record<string, unknown> {
  const displayName = marketplaceDisplayNames[platform] ?? platform;
  const condition = displayCondition(item.condition);
  const listPrice = positiveNumberOrFallback(item.currentPrice, item.originalPrice);
  const likelySalePrice = positiveNumberOrFallback(listPrice * 0.9, listPrice);
  const takeHomeEstimate = positiveNumberOrFallback(likelySalePrice * 0.85, likelySalePrice);
  const title = `${item.name} - ${condition}`.slice(0, profile.titleMaxCharacters).trim();

  return {
    title,
    description: [
      `${item.name} in ${condition.toLowerCase()} condition.`,
      `Asking $${formatPlainPrice(listPrice)}.`,
      "Please check the photos for condition, scale, and any visible wear.",
    ].join(" "),
    listPrice,
    likelySalePrice,
    takeHomeEstimate,
    firstPhoto: profile.photoGuidance,
    missingPhotoPrompt: null,
    missingInfoWarnings: requiredFieldWarnings(profile, item, details, identificationProfile),
    fitReason: `${displayName} can work for this item when the photos and details are clear.`,
    postingNotes: [
      "Use the generated copy with your actual photos.",
      "Mention any flaws you can see before posting.",
      ...playbookPostingNotes(profile),
    ].slice(0, 3),
    itemSpecifics: [],
    tags: [],
    evidenceSummary: "Current marketplace research returned no final draft, so this uses only the item facts provided.",
    evidenceSources: [],
  };
}

function isRecoverableDraftProviderError(error: unknown): boolean {
  if (!(error instanceof HttpError)) return false;
  return [
    "Provider returned an empty response",
    "Provider request timed out",
    "Provider transport failed",
    "Provider response was not valid model JSON",
  ].includes(error.message);
}

function isRateLimitedProviderError(error: unknown): boolean {
  return error instanceof HttpError && error.status === 429;
}

function createMarketplaceResearchPlan(
  item: ListingItem,
  platform: MarketplaceId,
  profile: MarketplaceListingProfile,
  details: ListingItemDetails | null,
  imageEvidence: ListingImageEvidence | null,
  identificationProfile: IdentificationProfile | null,
): MarketplaceResearchPlan {
  const displayName = marketplaceDisplayNames[platform] ?? platform;
  const currentYear = new Date().getUTCFullYear();
  const category = normalizedIdentifier(item.category);
  const condition = normalizedIdentifier(item.condition);
  const identity = researchIdentity(item, details, imageEvidence, identificationProfile);
  const identityKey = normalizedIdentifier(identity).slice(0, 90) || "unknownitem";
  const profileKey = normalizedIdentifier(profileSearchTerms(identificationProfile).join(" ")).slice(0, 90) || "noprofile";
  const noImageIdentity = researchIdentity(item, details, null, identificationProfile);
  const noImageIdentityKey = normalizedIdentifier(noImageIdentity).slice(0, 90) || "unknownitem";
  const cacheKey = `${platform}:${category}:${condition}:${identityKey}:${profileKey}`;
  const cacheLookupKeys = uniqueStrings([
    cacheKey,
    `${platform}:${category}:${condition}:${noImageIdentityKey}:${profileKey}`,
  ], 2);
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
    reason: `Need current rules, fee context, sold-price evidence, and posting guidance before drafting a ${profile.titleMaxCharacters}-character marketplace title for ${identity}.`,
  };
}

function researchIdentity(
  item: ListingItem,
  details: ListingItemDetails | null,
  imageEvidence: ListingImageEvidence | null,
  identificationProfile: IdentificationProfile | null,
): string {
  const parts = uniqueStrings([
    ...(identificationProfile?.confirmedFacts ?? []),
    ...(identificationProfile?.likelyFacts ?? []),
    ...(identificationProfile?.possibleMatches ?? []),
    details?.labelOrBrand ?? "",
    details?.sizeOrModel ?? "",
    item.name,
    imageEvidence?.bestGuessLabels[0] ?? "",
  ].filter((value) => value.trim().length > 0), 7);
  return parts.join(" ").slice(0, 160) || item.name;
}

function detailsForPrompt(details: ListingItemDetails | null, platform: MarketplaceId): string {
  if (!details) return "none";
  const lines = [
    details.labelOrBrand ? `Brand or maker: ${details.labelOrBrand}` : "",
    details.sizeOrModel ? `Size, model, or measurement: ${details.sizeOrModel}` : "",
    details.flaws ? `Flaws or damage: ${details.flaws}` : "",
    details.included ? `Included items: ${details.included}` : "",
    details.extraDetails ? `Extra seller note: ${details.extraDetails}` : "",
    details.marketplaceNotes[platform]
      ? `${marketplaceDisplayNames[platform] ?? platform} seller note: ${details.marketplaceNotes[platform]}`
      : "",
    marketplaceNoteSummary(details.marketplaceNotes, platform),
    details.isLargeOrFragile ? "Shipping note: big, heavy, or fragile" : "",
  ].filter((value) => value.length > 0);
  return lines.length ? lines.join("; ") : "none";
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

function marketplaceNoteSummary(notes: Record<string, string>, currentPlatform: MarketplaceId): string {
  const values = Object.entries(notes)
    .filter(([marketplace, value]) => marketplace !== currentPlatform && value.trim().length > 0)
    .slice(0, 3)
    .map(([marketplace, value]) => {
      const displayName = marketplaceDisplayNames[marketplace as MarketplaceId] ?? marketplace;
      return `${displayName}: ${value}`;
    });
  return values.length > 0 ? `Other marketplace notes: ${values.join(" | ")}` : "";
}

async function fetchVisionWebDetectionEvidence(
  imageDataUrl: ImageDataUrl,
): Promise<ListingImageEvidence | null> {
  const apiKey = Deno.env.get("GOOGLE_CLOUD_VISION_API_KEY")?.trim() ||
    Deno.env.get("GOOGLE_VISION_API_KEY")?.trim();
  if (!apiKey) return null;

  try {
    const response = await fetchWithTimeout(
      `https://vision.googleapis.com/v1/images:annotate?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          requests: [{
            image: { content: imageDataUrl.base64 },
            features: [{ type: "WEB_DETECTION", maxResults: 8 }],
          }],
        }),
      },
      {
        timeoutMs: timeoutFromEnv("GOOGLE_VISION_TIMEOUT_MS", 8_000),
        timeoutMessage: "Vision web detection timed out",
        transportMessage: "Vision web detection transport failed",
      },
    );
    if (!response.ok) return null;

    const body = requireJsonObject(
      await readResponseJson(response, "Vision web detection response was not valid JSON"),
      "Vision web detection response was not a JSON object",
    );
    const responses = Array.isArray(body.responses) ? body.responses : [];
    const firstResponse = recordOrNull(responses[0]);
    const webDetection = recordOrNull(firstResponse?.webDetection);
    if (!webDetection) return null;

    const bestGuessLabels = stringArray(
      (Array.isArray(webDetection.bestGuessLabels) ? webDetection.bestGuessLabels : [])
        .map((entry) => recordOrNull(entry)?.label),
      4,
      80,
    );
    const matchingPageTitles = stringArray(
      (Array.isArray(webDetection.pagesWithMatchingImages) ? webDetection.pagesWithMatchingImages : [])
        .map((entry) => recordOrNull(entry)?.pageTitle),
      5,
      120,
    );
    const matchingImageUrls = stringArray([
      ...(Array.isArray(webDetection.fullMatchingImages) ? webDetection.fullMatchingImages : [])
        .map((entry) => recordOrNull(entry)?.url),
      ...(Array.isArray(webDetection.partialMatchingImages) ? webDetection.partialMatchingImages : [])
        .map((entry) => recordOrNull(entry)?.url),
    ], 5, 500);
    const similarImageUrls = stringArray(
      (Array.isArray(webDetection.visuallySimilarImages) ? webDetection.visuallySimilarImages : [])
        .map((entry) => recordOrNull(entry)?.url),
      5,
      500,
    );

    if (
      bestGuessLabels.length === 0 &&
      matchingPageTitles.length === 0 &&
      matchingImageUrls.length === 0 &&
      similarImageUrls.length === 0
    ) {
      return null;
    }

    return {
      bestGuessLabels,
      matchingPageTitles,
      matchingImageUrls,
      similarImageUrls,
    };
  } catch {
    return null;
  }
}

async function fetchMarketplaceResearchCache(
  plan: MarketplaceResearchPlan,
): Promise<MarketplaceResearchCache | null> {
  const service = supabaseServiceConfig();
  if (!service) return null;

  try {
    const now = encodeURIComponent(new Date().toISOString());
    const select = "research_summary,useful_findings,official_sources,search_queries,updated_at";
    for (const lookupKey of plan.cacheLookupKeys) {
      const cacheKey = encodeURIComponent(lookupKey);
      const response = await fetchWithTimeout(
        `${service.supabaseUrl}/rest/v1/marketplace_research_cache?cache_key=eq.${cacheKey}&expires_at=gt.${now}&select=${select}&limit=1`,
        { headers: serviceHeaders(service.serviceRoleKey) },
        supabaseServiceFetchOptions(),
      );
      if (!response.ok) continue;

      const rows = requireJsonArray(
        await readResponseJson(response, "Marketplace research cache response was not valid JSON"),
        "Marketplace research cache response was not a JSON array",
      );
      const row = rows[0];
      if (row === undefined) continue;

      const cachedResearch = marketplaceResearchCacheFromRow(row);
      if (cachedResearch) return cachedResearch;
    }
    return null;
  } catch {
    return null;
  }
}

function marketplaceResearchCacheFromRow(row: unknown): MarketplaceResearchCache | null {
  const payload = requireJsonObject(row, "Marketplace research cache row was not a JSON object");
  const researchSummary = optionalString(payload.research_summary);
  if (!researchSummary) return null;

  return {
    researchSummary,
    usefulFindings: stringArray(payload.useful_findings),
    officialSources: stringArray(payload.official_sources),
    searchQuestions: stringArray(payload.search_queries),
    updatedAt: optionalString(payload.updated_at) ?? "",
  };
}

function isFreshMarketplaceResearchCache(
  cachedResearch: MarketplaceResearchCache | null,
  now: Date,
): cachedResearch is MarketplaceResearchCache {
  if (!cachedResearch) return false;
  const updatedAt = evidenceCheckedAt(cachedResearch.updatedAt);
  if (!updatedAt) return false;
  const ageMs = now.getTime() - updatedAt.getTime();
  return ageMs >= 0 && ageMs <= selectedComparisonFreshnessWindowMs;
}

function isFreshFinalListingResearch(
  cachedResearch: MarketplaceResearchCache | null,
  now: Date,
): cachedResearch is MarketplaceResearchCache {
  if (!cachedResearch) return false;
  const updatedAt = evidenceCheckedAt(cachedResearch.updatedAt);
  if (!updatedAt) return false;
  const ageMs = now.getTime() - updatedAt.getTime();
  return ageMs >= 0 && ageMs <= finalListingResearchFreshnessWindowMs;
}

function finalListingResearchRefreshReason(
  cachedResearch: MarketplaceResearchCache | null,
  comparison: PriorMarketplaceComparison | null,
  now: Date,
): string | null {
  if (!cachedResearch) {
    return "No saved marketplace research is available for this final listing.";
  }
  if (!isFreshFinalListingResearch(cachedResearch, now)) {
    return "Saved marketplace research is older than 24 hours; refresh current price, fee, and rule facts before final listing.";
  }
  if (comparison && hasPriorSoldCompEvidence(comparison) === false) {
    return "Selected marketplace comparison has no grounded sold/completed comp range; refresh comparable sale evidence before final listing.";
  }
  if (hasOfficialFeeOrRuleSource(cachedResearch, comparison) === false) {
    return "Saved marketplace research has no official fee or rule source; refresh marketplace requirements before final listing.";
  }
  return null;
}

function hasPriorSoldCompEvidence(comparison: PriorMarketplaceComparison): boolean {
  return soldEvidencePrices(comparison.evidenceSources).length > 0;
}

function hasOfficialFeeOrRuleSource(
  cachedResearch: MarketplaceResearchCache,
  comparison: PriorMarketplaceComparison | null,
): boolean {
  const searchableText = [
    cachedResearch.researchSummary,
    ...cachedResearch.usefulFindings,
    ...cachedResearch.officialSources,
    comparison?.feeSummary ?? "",
    comparison?.evidenceSummary ?? "",
    ...(comparison?.evidenceSources ?? []).map((source) =>
      [
        source.sourceMarketplace ?? "",
        source.title ?? "",
        source.url ?? "",
        source.listingStatus ?? "",
      ].join(" ")
    ),
  ].join(" ").toLowerCase();
  return [
    "official",
    "fee",
    "fees",
    "seller help",
    "help center",
    "policy",
    "requirements",
    "rules",
  ].some((signal) => searchableText.includes(signal));
}

function isSoldOrCompletedStatus(value: string | null): boolean {
  const text = value?.toLowerCase() ?? "";
  return text.includes("sold") || text.includes("completed");
}

async function saveMarketplaceResearchCache(
  plan: MarketplaceResearchPlan,
  result: Record<string, unknown>,
): Promise<void> {
  const service = supabaseServiceConfig();
  if (!service) return;

  const researchSummary = optionalString(result.researchSummary);
  const usefulFindings = stringArray(result.usefulFindings, 8);
  const officialSources = uniqueStrings([
    ...stringArray(result.officialSources, 8),
    ...stringArray(result[geminiGroundingSourcesKey], 8),
  ], 8);
  const searchedFor = uniqueStrings([
    ...stringArray(result.searchedFor, 3),
    ...stringArray(result[geminiGroundingSearchQueriesKey], 3),
  ], 3);
  const researchSummaryForCache = researchSummary ?? (usefulFindings.join(" ") || officialSources.join(" "));
  if (officialSources.length === 0) return;
  if (!researchSummaryForCache) return;

  const now = new Date();
  const expiresAt = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1_000);
  const row = {
    cache_key: plan.cacheKey,
    marketplace: plan.marketplace,
    category: plan.category,
    condition: plan.condition,
    search_queries: searchedFor.length > 0 ? searchedFor : plan.searchQuestions,
    useful_findings: usefulFindings,
    official_sources: officialSources,
    research_summary: researchSummaryForCache,
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
    if (!response.ok) return;
  } catch {
    return;
  }
}

function marketplaceComparisonAsResearch(
  comparison: PriorMarketplaceComparison | null,
  plan: MarketplaceResearchPlan,
): MarketplaceResearchCache | null {
  if (!comparison || comparison.evidenceSources.length === 0) return null;

  const priceFacts = [
    comparison.listPrice ? `Recommended list price: $${formatPlainPrice(comparison.listPrice)}` : "",
    comparison.likelyRangeLow && comparison.likelyRangeHigh
      ? `Likely sale range: $${formatPlainPrice(comparison.likelyRangeLow)} to $${formatPlainPrice(comparison.likelyRangeHigh)}`
      : "",
    comparison.compLowPrice && comparison.compHighPrice
      ? `Grounded sold comps ranged from $${formatPlainPrice(comparison.compLowPrice)} to $${formatPlainPrice(comparison.compHighPrice)}`
      : "",
    comparison.compMedianPrice ? `Typical sold comp: $${formatPlainPrice(comparison.compMedianPrice)}` : "",
    comparison.takeHomeEstimate ? `Estimated take-home: $${formatPlainPrice(comparison.takeHomeEstimate)}` : "",
  ].filter((value) => value.length > 0);

  const usefulFindings = uniqueStrings([
    ...priceFacts,
    comparison.feeSummary ? `Fee note: ${comparison.feeSummary}` : "",
    comparison.expectedSpeed ? `Expected speed: ${comparison.expectedSpeed}` : "",
    comparison.shippingExpectation ? `Shipping or pickup: ${comparison.shippingExpectation}` : "",
    comparison.reason ? `Marketplace fit: ${comparison.reason}` : "",
  ].filter((value) => value.length > 0), 8);

  const sourceSummaries = comparison.evidenceSources.map((source) =>
    [
      source.sourceMarketplace ?? marketplaceDisplayNames[comparison.marketplace] ?? comparison.marketplace,
      source.listingStatus,
      source.title,
      source.price ? `$${formatPlainPrice(source.price)}` : "",
      source.conditionAndVariant,
      source.comparability,
      source.url,
    ].filter((value) => value && value.length > 0).join(" - ")
  );

  const researchSummary = uniqueStrings([
    comparison.evidenceSummary ?? "",
    comparison.reason ?? "",
    ...priceFacts,
    ...sourceSummaries,
  ].filter((value) => value.length > 0), 8).join(" ");

  if (!researchSummary) return null;

  return {
    researchSummary,
    usefulFindings,
    officialSources: uniqueStrings(
      comparison.evidenceSources
        .map((source) => source.url)
        .filter((value): value is string => Boolean(value)),
      8,
    ),
    searchQuestions: plan.searchQuestions,
    updatedAt: comparison.evidenceSources.find((source) => source.dateChecked)?.dateChecked ?? new Date().toISOString(),
  };
}


const marketplaceProfiles: Record<MarketplaceId, MarketplaceListingProfile> = {
  ebay: {
    titleMaxCharacters: 80,
    titleFormula: "brand or maker + model + item type + key attribute + condition",
    searchFocus: "Clear title keywords, item specifics, accurate category, and honest condition.",
    photoGuidance: "Use high-quality photos from every angle and show flaws or scratches.",
    featuredGuidance: "Promoted Listings can help only after the organic listing is complete and fairly priced.",
  },
  craigslist: {
    titleMaxCharacters: 70,
    titleFormula: "plain item type + brand or size + condition",
    searchFocus: "Local pickup buyers scan for plain item words, neighborhood relevance, price, and condition.",
    photoGuidance: "Show the full item, scale, close-ups, and flaws in a clean pickup-friendly space.",
    featuredGuidance: "Renew or repost when allowed instead of pushing paid promotion into the listing copy.",
  },
  facebook: {
    titleMaxCharacters: 80,
    titleFormula: "brand + item type + size or color + condition",
    searchFocus: "Local feed visibility depends on clear title, category, price, location fit, and honest condition.",
    photoGuidance: "Make the first photo obvious in the feed and add close-ups for flaws, tags, and scale.",
    featuredGuidance: "Boost only if the item is desirable locally and the first photo is strong.",
  },
  poshmark: {
    titleMaxCharacters: 80,
    titleFormula: "brand + style name + item type + color + size",
    searchFocus: "Fashion buyers search brand, style, size, color, material, trend, and condition terms.",
    photoGuidance: "Show a crisp cover shot, tags, fabric, size, measurements, and visible wear.",
    featuredGuidance: "Share the listing and use Offer to Likers after it gets interest.",
  },
  mercari: {
    titleMaxCharacters: 80,
    titleFormula: "brand + item type + key attribute + condition",
    searchFocus: "Accurate title, detailed description, complete photos, and truthful brand/category details.",
    photoGuidance: "Use natural light, a plain background, every side, and clear flaw photos.",
    featuredGuidance: "Promote works through a real price drop, so suggest it only after organic interest slows.",
  },
  offerup: {
    titleMaxCharacters: 80,
    titleFormula: "clear item type + brand + key local detail",
    searchFocus: "Mobile local buyers need a specific title and a description that answers common pickup questions.",
    photoGuidance: "Show exactly what is included, the full item, close-ups, and any damage.",
    featuredGuidance: "Promote locally only when the price is competitive and the first photo is strong.",
  },
  depop: {
    titleMaxCharacters: 80,
    titleFormula: "brand + item type + style + color + size",
    searchFocus: "Relevant style words, accurate category, brand, color, measurements, and non-spam hashtags.",
    photoGuidance: "Use original photos, fit/detail shots, measurements, and visible wear.",
    featuredGuidance: "Boost relevant fashion listings once eligible and only after the description is complete.",
  },
  whatnot: {
    titleMaxCharacters: 80,
    titleFormula: "brand or set + item type + rarity + condition",
    searchFocus: "Collectible buyers need exact names, edition or set details, rarity signals, and condition.",
    photoGuidance: "Show front, back, edition marks, flaws, and proof of the exact item.",
    featuredGuidance: "Feature in a live show or promoted drop only when demand is category-specific.",
  },
  grailed: {
    titleMaxCharacters: 80,
    titleFormula: "designer or brand + item name + size + color",
    searchFocus: "Menswear buyers search brand, garment type, size, color, condition, and material.",
    photoGuidance: "Show front/back, tags, fabric labels, measurements, and wear.",
    featuredGuidance: "Bump or price-drop after watchers appear; keep keywords precise.",
  },
  reverb: {
    titleMaxCharacters: 80,
    titleFormula: "brand + model + year or series + instrument type + condition",
    searchFocus: "Music buyers search exact brand, model, year, function, and cosmetic condition.",
    photoGuidance: "Show serial/model labels, electronics, hardware, finish wear, and working details.",
    featuredGuidance: "Use bump or promoted tools only after specs, condition, and photos are complete.",
  },
  etsy: {
    titleMaxCharacters: 140,
    titleFormula: "clear item name + material or era + color or size",
    searchFocus: "Clear buyer-friendly title, tags, attributes, description, first photo, and unique details.",
    photoGuidance: "Use a clean product photo, detail, scale, material, and alt-text-ready shots.",
    featuredGuidance: "Use Etsy Ads only after tags, attributes, photos, and description are complete.",
  },
  stockx: {
    titleMaxCharacters: 80,
    titleFormula: "exact product name + colorway + size + condition",
    searchFocus: "Exact product identity, size, colorway, box condition, and authenticated-category fit.",
    photoGuidance: "Show box, labels, size tag, soles, and any defects before choosing this marketplace.",
    featuredGuidance: "Use the marketplace ask price mechanics rather than extra listing copy.",
  },
  goat: {
    titleMaxCharacters: 80,
    titleFormula: "exact sneaker name + colorway + size + condition",
    searchFocus: "Exact sneaker identity, size, condition, defects, and account approval readiness.",
    photoGuidance: "Photograph box, labels, soles, uppers, and every defect clearly.",
    featuredGuidance: "Use GOAT pricing and offer mechanics after approval; avoid vague item names.",
  },
  kidizen: {
    titleMaxCharacters: 80,
    titleFormula: "brand + kid size + item type + color + condition",
    searchFocus: "Kids buyers need size, brand, condition, season, and stain/wear disclosure.",
    photoGuidance: "Show front/back, size tags, fabric, stains, and wear.",
    featuredGuidance: "Refresh or promote seasonally when the size and photos are complete.",
  },
  vinted: {
    titleMaxCharacters: 80,
    titleFormula: "brand + item type + size + color + condition",
    searchFocus: "Simple fashion resale needs brand, size, color, category, and accurate condition.",
    photoGuidance: "Show the whole item, size label, material tag, and flaws.",
    featuredGuidance: "Use bumps or wardrobe spotlight only for clean, complete fashion listings.",
  },
  vestiaire: {
    titleMaxCharacters: 80,
    titleFormula: "designer + official item name + size + condition",
    searchFocus: "Luxury buyers need brand accuracy, authenticity signals, condition, size, and material.",
    photoGuidance: "Show labels, serial or authenticity marks, material, hardware, corners, and wear.",
    featuredGuidance: "Use price drops or platform promotion after authenticity details are complete.",
  },
  therealreal: {
    titleMaxCharacters: 80,
    titleFormula: "designer + item type + material + size",
    searchFocus: "Consignment-style luxury depends on brand, material, authenticity, and condition.",
    photoGuidance: "Capture brand marks, serial labels, hardware, fabric, wear, and authenticity details.",
    featuredGuidance: "Use the platform's consignment flow; documentation matters more than boosting.",
  },
  swappa: {
    titleMaxCharacters: 80,
    titleFormula: "brand + model + storage or carrier + condition",
    searchFocus: "Used tech buyers search model, storage, carrier, battery, unlock status, and condition.",
    photoGuidance: "Show the screen on, ports, model/settings, battery health if available, and scratches.",
    featuredGuidance: "Use price competitiveness first; feature only after verification details are complete.",
  },
  tradesy: {
    titleMaxCharacters: 80,
    titleFormula: "designer + item type + size + color + condition",
    searchFocus: "Designer buyers search brand, size, color, material, and condition.",
    photoGuidance: "Show labels, hardware, soles, fabric, corners, and signs of wear.",
    featuredGuidance: "Use price drops after watchers appear; do not stuff unrelated designer keywords.",
  },
  chairish: {
    titleMaxCharacters: 65,
    titleFormula: "era or maker + material + specific furniture or decor type",
    searchFocus: "Vintage home buyers need specific era, maker, material, dimensions, and style.",
    photoGuidance: "Lead with the full piece, then scale, texture, maker marks, dimensions, and damage.",
    featuredGuidance: "Curated primary images and complete details matter more than paid promotion.",
  },
  bonanza: {
    titleMaxCharacters: 80,
    titleFormula: "brand + item type + key attribute + condition",
    searchFocus: "Straightforward title keywords, complete details, accurate category, and competitive price.",
    photoGuidance: "Use clear photos with a simple background, detail shots, and flaw photos.",
    featuredGuidance: "Use advertising only for listings with strong search terms and competitive pricing.",
  },
  curtsy: {
    titleMaxCharacters: 80,
    titleFormula: "brand + item type + size + color + style",
    searchFocus: "Mobile fashion buyers search brand, size, style, occasion, and condition.",
    photoGuidance: "Show cover, fit, size tag, material, and any wear.",
    featuredGuidance: "Use offers or price moves after likes; keep trend terms relevant.",
  },
  nextdoor: {
    titleMaxCharacters: 80,
    titleFormula: "plain item type + size or brand + condition",
    searchFocus: "Neighborhood buyers want pickup-friendly goods, clear title words, condition, and price.",
    photoGuidance: "Show the whole item, scale, pickup condition, and flaws.",
    featuredGuidance: "Refresh local visibility with fair price and clear pickup terms.",
  },
  amazon: {
    titleMaxCharacters: 80,
    titleFormula: "brand + product line + item type + variant",
    searchFocus: "Catalog-like products need precise identifiers, customer-friendly search terms, and clear details.",
    photoGuidance: "Use sharp, simple product photos and exact identifiers; avoid used one-off ambiguity.",
    featuredGuidance: "Use Amazon promotions only for catalog-ready items, not casual one-off resale.",
  },
  shopify: {
    titleMaxCharacters: 70,
    titleFormula: "brand + product name + key attribute",
    searchFocus: "Storefront success depends on a complete product page, collection fit, and trust signals.",
    photoGuidance: "Use a clean product photo set with alt-text-ready detail shots.",
    featuredGuidance: "Use storefront ads only when the shop, product page, and checkout are already trusted.",
  },
  rubylane: {
    titleMaxCharacters: 80,
    titleFormula: "era + maker + material + item type + condition",
    searchFocus: "Antique and fine-art buyers search era, maker, material, provenance, and condition.",
    photoGuidance: "Show maker marks, signatures, materials, scale, condition, and any restoration.",
    featuredGuidance: "Use shop promotion only after provenance and condition are complete.",
  },
  tcgplayer: {
    titleMaxCharacters: 80,
    titleFormula: "card name + set + number + condition + variant",
    searchFocus: "Trading-card search needs exact card, set, number, variant, and condition.",
    photoGuidance: "Show front/back, corners, surface, centering, and any grading slab.",
    featuredGuidance: "Use price competitiveness and exact catalog matching before promotion.",
  },
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

function requireItem(value: unknown): ListingItem {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError("item must be an object", 400);
  }
  const item = value as Record<string, unknown>;
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
  if (typeof value !== "object" || Array.isArray(value)) return null;

  const details = value as Record<string, unknown>;
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

function optionalMarketplacePlaybook(value: unknown): MarketplaceListingPlaybookInput | null {
  const record = recordOrNull(value);
  if (!record) return null;

  const playbook: MarketplaceListingPlaybookInput = {
    playbookVersionIdentifier: optionalString(record.playbookVersionIdentifier, 80) ?? undefined,
    playbookSchemaVersion: optionalPositiveInteger(record.playbookSchemaVersion, 10) ?? undefined,
    playbookFeeSourcesLastChecked: optionalString(record.playbookFeeSourcesLastChecked, 32) ?? undefined,
    playbookRuleSourcesLastVerified: optionalString(record.playbookRuleSourcesLastVerified, 32) ?? undefined,
    titleCharacterLimit: optionalTitleCharacterLimit(record.titleCharacterLimit),
    titleFormula: optionalString(record.titleFormula, 180) ?? undefined,
    descriptionGuidance: optionalString(record.descriptionGuidance, 260) ?? undefined,
    requiredFields: stringArray(record.requiredFields, 10, 96),
    highImpactOptionalFields: stringArray(record.highImpactOptionalFields, 10, 96),
    recommendedPhotoSequence: stringArray(record.recommendedPhotoSequence, 8, 48),
    pricingFormat: optionalString(record.pricingFormat, 180) ?? undefined,
    shippingOrPickupGuidance: optionalString(record.shippingOrPickupGuidance, 220) ?? undefined,
    officialPostURLString: optionalHttpsURLString(record.officialPostURLString, 220) ?? undefined,
    officialHowToURLString: optionalHttpsURLString(record.officialHowToURLString, 220) ?? undefined,
    ruleSourceURLs: stringArray(record.ruleSourceURLs, 8, 220).filter(isHttpURLString),
    ruleSourceLastVerified: optionalString(record.ruleSourceLastVerified, 32) ?? undefined,
    postingSurface: optionalString(record.postingSurface, 40) ?? undefined,
  };

  const hasGuidance = [
    playbook.playbookVersionIdentifier,
    playbook.playbookSchemaVersion,
    playbook.playbookFeeSourcesLastChecked,
    playbook.playbookRuleSourcesLastVerified,
    playbook.titleCharacterLimit,
    playbook.titleFormula,
    playbook.descriptionGuidance,
    playbook.pricingFormat,
    playbook.shippingOrPickupGuidance,
    playbook.officialPostURLString,
    playbook.officialHowToURLString,
    playbook.ruleSourceLastVerified,
  ].some((entry) => entry !== undefined) ||
    playbook.requiredFields.length > 0 ||
    playbook.highImpactOptionalFields.length > 0 ||
    playbook.recommendedPhotoSequence.length > 0 ||
    playbook.ruleSourceURLs.length > 0;

  return hasGuidance ? playbook : null;
}

function optionalMarketplaceComparison(
  value: unknown,
  selectedMarketplace: MarketplaceId,
): PriorMarketplaceComparison | null {
  const record = recordOrNull(value);
  if (!record) return null;

  const marketplaceText = optionalString(record.marketplace, 48)?.toLowerCase();
  const marketplace = marketplaceText && knownMarketplaceIdSet.has(marketplaceText)
    ? marketplaceText as MarketplaceId
    : selectedMarketplace;
  if (marketplace !== selectedMarketplace) return null;

  const evidenceStatus = optionalComparisonEvidenceStatus(record.evidenceStatus);
  const evidenceSources = cleanEvidenceSources(record.evidenceSources, selectedMarketplace);
  const freshEvidenceSources = evidenceSources.filter((source) =>
    hasEvidenceSourceReference(source) && isFreshSelectedComparisonEvidence(source, new Date())
  );
  const hasReusableEvidence = evidenceStatus !== "unavailable" && freshEvidenceSources.length > 0;
  if (!hasReusableEvidence) return null;

  return {
    marketplace,
    recommendationLabel: optionalString(record.recommendationLabel, 32),
    marketplaceFitScore: optionalFitScore(record.marketplaceFitScore),
    listPrice: optionalPositiveNumber(record.listPrice),
    likelyRangeLow: optionalPositiveNumber(record.likelyRangeLow),
    likelyRangeHigh: optionalPositiveNumber(record.likelyRangeHigh),
    takeHomeEstimate: optionalPositiveNumber(record.takeHomeEstimate),
    compLowPrice: optionalPositiveNumber(record.compLowPrice),
    compMedianPrice: optionalPositiveNumber(record.compMedianPrice),
    compHighPrice: optionalPositiveNumber(record.compHighPrice),
    expectedSpeed: optionalString(record.expectedSpeed, 80),
    shippingExpectation: optionalString(record.shippingExpectation, 100),
    feeSummary: optionalString(record.feeSummary, 180),
    reason: optionalString(record.reason, 180),
    evidenceSummary: optionalString(record.evidenceSummary, 220),
    evidenceStatus,
    evidenceSources: freshEvidenceSources,
  };
}

function isFreshSelectedComparisonEvidence(
  source: StructuredEvidenceSource,
  now: Date,
): boolean {
  const checkedAt = evidenceCheckedAt(source.dateChecked);
  if (!checkedAt) return false;
  const ageMs = now.getTime() - checkedAt.getTime();
  return ageMs >= 0 && ageMs <= selectedComparisonFreshnessWindowMs;
}

function evidenceCheckedAt(value: string | null): Date | null {
  const text = optionalString(value, 32);
  if (!text) return null;
  const normalized = /^\d{4}-\d{2}-\d{2}$/.test(text) ? `${text}T12:00:00Z` : text;
  const checkedAt = new Date(normalized);
  return Number.isFinite(checkedAt.getTime()) ? checkedAt : null;
}

function optionalComparisonEvidenceStatus(value: unknown): string | null {
  const text = optionalString(value, 32)?.toLowerCase();
  switch (text) {
    case "grounded":
    case "verified":
      return "grounded";
    case "limited":
    case "partial":
      return "limited";
    default:
      return "unavailable";
  }
}

function optionalFitScore(value: unknown): number | null {
  const number = Number(value);
  if (!Number.isInteger(number) || number < 1 || number > 100) return null;
  return number;
}

function optionalTitleCharacterLimit(value: unknown): number | undefined {
  const number = Number(value);
  if (!Number.isInteger(number) || number < 20 || number > 160) return undefined;
  return number;
}

function optionalPositiveInteger(value: unknown, maxValue: number): number | undefined {
  const number = Number(value);
  if (!Number.isInteger(number) || number < 1 || number > maxValue) return undefined;
  return number;
}

function optionalHttpsURLString(value: unknown, maxLength: number): string | null {
  const text = optionalString(value, maxLength);
  if (!text || !isHttpURLString(text)) return null;
  return text;
}

function isHttpURLString(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" || url.protocol === "http:";
  } catch {
    return false;
  }
}

function optionalImageDataUrl(value: unknown): ImageDataUrl | null {
  if (typeof value !== "string" || !value.startsWith("data:image/jpeg;base64,")) {
    return null;
  }
  const base64 = value.slice("data:image/jpeg;base64,".length).trim();
  if (!base64 || base64.length > 3_800_000 || /^[A-Za-z0-9+/=]+$/.test(base64) === false) {
    return null;
  }
  return { base64 };
}

function requireMarketplace(value: unknown): MarketplaceId {
  const platform = asString(value, "platform").toLowerCase();
  if (!knownMarketplaceIdSet.has(platform)) {
    throw new HttpError("Unsupported platform", 400);
  }
  return platform as MarketplaceId;
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
  if (!knownValue) {
    throw new HttpError(`Unsupported ${field}`, 400);
  }
  return knownValue;
}

function normalizedIdentifier(value: string): string {
  return value
    .toLowerCase()
    .replace(/[\s_-]+/g, "");
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

function optionalString(value: unknown, maxLength = 1_200): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.slice(0, maxLength);
}

function recordOrNull(value: unknown): Record<string, unknown> | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
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

function uniqueStrings(values: string[], maxItems: number): string[] {
  const unique: string[] = [];
  for (const value of values) {
    if (unique.includes(value)) continue;
    unique.push(value);
    if (unique.length >= maxItems) break;
  }
  return unique;
}

function requireStructuredListingDraft(
  result: Record<string, unknown>,
  item: ListingItem,
  platform: MarketplaceId,
  profile: MarketplaceListingProfile,
  priorComparison: PriorMarketplaceComparison | null,
  details: ListingItemDetails | null,
  identificationProfile: IdentificationProfile | null,
): StructuredListingDraft {
  const title = cleanDraftText(result.title, "title", profile.titleMaxCharacters);
  const description = cleanDraftText(result.description, "description", 1_500);
  const listPrice = positiveNumberOrFallback(result.listPrice, priorComparison?.listPrice ?? item.currentPrice);
  const likelySalePrice = positiveNumberOrFallback(
    result.likelySalePrice,
    priorComparisonLikelySalePrice(priorComparison) ?? Math.max(item.currentPrice * 0.9, 1),
  );
  const takeHomeEstimate = positiveNumberOrFallback(
    result.takeHomeEstimate,
    priorComparison?.takeHomeEstimate ?? Math.max(likelySalePrice * 0.85, 1),
  );
  const firstPhoto = optionalCleanDraftText(result.firstPhoto, 180) ?? profile.photoGuidance;
  const missingPhotoPrompt = optionalCleanDraftText(result.missingPhotoPrompt, 140);
  const fitReason = optionalCleanDraftText(result.fitReason, 220) ??
    priorComparison?.reason ??
    `${marketplaceDisplayNames[platform]} fits this item when the details and photos are clear.`;
  const evidenceSources = mergedEvidenceSources(
    cleanEvidenceSources(result.evidenceSources, platform),
    priorComparison?.evidenceSources ?? [],
  );
  const soldPrices = soldEvidencePrices(evidenceSources);
  const hasPricedSoldCompEvidence = soldPrices.length > 0;
  const compLowPrice = hasPricedSoldCompEvidence ? lowEvidencePrice(soldPrices) : null;
  const compHighPrice = hasPricedSoldCompEvidence ? highEvidencePrice(soldPrices) : null;
  const compMedianPrice = hasPricedSoldCompEvidence ? medianEvidencePrice(soldPrices) : null;
  const missingInfoWarnings = uniqueStrings([
    ...cleanStringList(result.missingInfoWarnings, 4, 120),
    ...requiredFieldWarnings(profile, item, details, identificationProfile),
  ], 4);
  const postingNotes = uniqueStrings([
    ...cleanStringList(result.postingNotes, 3, 160),
    ...playbookPostingNotes(profile),
  ], 3);

  return {
    title,
    description,
    listPrice,
    likelySalePrice,
    takeHomeEstimate,
    firstPhoto,
    missingPhotoPrompt,
    missingInfoWarnings,
    fitReason,
    postingNotes,
    itemSpecifics: cleanStringList(result.itemSpecifics, 6, 80),
    tags: cleanStringList(result.tags, 8, 40),
    compLowPrice,
    compHighPrice,
    compMedianPrice,
    feeSummary: optionalCleanDraftText(result.feeSummary, 180) ?? priorComparison?.feeSummary ?? null,
    pricingStrategy: optionalCleanDraftText(result.pricingStrategy, 220),
    evidenceSummary: listingEvidenceSummaryForDisplay(
      result.evidenceSummary,
      platform,
      evidenceSources,
      soldPrices.length,
      priorComparison,
    ),
    referenceImageURL: optionalReferenceImageURL(result.referenceImageURL),
    publicImageQuery: optionalCleanDraftText(result.publicImageQuery, 140),
    evidenceSources,
  };
}

function priorComparisonLikelySalePrice(comparison: PriorMarketplaceComparison | null): number | null {
  if (!comparison) return null;
  if (comparison.compMedianPrice) return comparison.compMedianPrice;
  if (comparison.likelyRangeLow && comparison.likelyRangeHigh) {
    return Math.round(((comparison.likelyRangeLow + comparison.likelyRangeHigh) / 2) * 100) / 100;
  }
  if (comparison.listPrice) return comparison.listPrice;
  return null;
}

function formatListingDraft(draft: StructuredListingDraft): string {
  return [
    "TITLE:",
    draft.title,
    "",
    "DESCRIPTION:",
    draft.description,
  ].join("\n");
}

function cleanDraftText(value: unknown, field: string, maxLength: number): string {
  const text = asString(value, field).trim();
  const cleaned = rejectUnsafeDraftText(text, field).slice(0, maxLength).trim();
  if (!cleaned) {
    throw new HttpError(`Missing ${field}`, 502);
  }
  return cleaned;
}

function optionalCleanDraftText(value: unknown, maxLength: number): string | null {
  const text = optionalString(value, maxLength);
  if (!text) return null;
  return rejectUnsafeDraftText(text, "draft field").slice(0, maxLength).trim() || null;
}

function cleanStringList(value: unknown, maxItems: number, maxLength: number): string[] {
  return stringArray(value, maxItems, maxLength)
    .map((entry) => rejectUnsafeDraftText(entry, "draft list item").slice(0, maxLength).trim())
    .filter((entry) => entry.length > 0);
}

function requiredFieldWarnings(
  profile: MarketplaceListingProfile,
  item: ListingItem,
  details: ListingItemDetails | null,
  identificationProfile: IdentificationProfile | null,
): string[] {
  const requiredFields = profile.requiredFields ?? [];
  return requiredFields
    .filter((field) => hasVerifiedRequiredField(field, item, details, identificationProfile) === false)
    .slice(0, 4)
    .map((field) => `Confirm ${field.toLowerCase()} before posting.`);
}

function hasVerifiedRequiredField(
  field: string,
  item: ListingItem,
  details: ListingItemDetails | null,
  identificationProfile: IdentificationProfile | null,
): boolean {
  if (systemProvidesRequiredField(field, item)) return true;
  const signals = requiredFieldSignals(field);
  if (signals.length === 0) return false;
  if (sellerDetailsCoverRequiredSignals(signals, details)) return true;
  if (confirmedProfileFactsCoverRequiredSignals(signals, identificationProfile)) return true;
  if (profileStillNeedsRequiredSignals(signals, identificationProfile)) return false;
  return false;
}

function systemProvidesRequiredField(field: string, item: ListingItem): boolean {
  const normalized = field
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
  if (!normalized) return false;
  if ([
    "title",
    "product title",
    "description",
    "category",
    "condition",
    "price",
    "starting price",
  ].includes(normalized)) {
    return true;
  }
  if (normalized.includes("photo") || normalized.includes("image") || normalized.includes("picture")) {
    return true;
  }
  if (
    normalized.includes("item identity") ||
    normalized.includes("exact device")
  ) {
    return item.name.trim().length > 0 && normalizedIdentifier(item.name) !== "unknownitem";
  }
  return false;
}

function sellerDetailsCoverRequiredSignals(
  signals: string[],
  details: ListingItemDetails | null,
): boolean {
  if (!details) return false;

  const fields: Array<[string[], string | boolean | null | undefined]> = [
    [["brand", "maker", "manufacturer", "artist", "logo", "label", "mark", "signature", "hallmark"], details.labelOrBrand],
    [["model", "serial", "sku", "style", "code", "size", "measurement", "dimension", "capacity", "storage", "carrier"], details.sizeOrModel],
    [["condition", "flaw", "damage", "scratch", "wear", "working", "tested", "broken"], details.flaws],
    [["included", "accessory", "accessories", "box", "case", "charger", "paperwork", "certificate", "receipt", "parts"], details.included],
    [["material", "year", "age", "vintage", "antique", "edition", "limited", "numbered", "signed", "authentic", "authenticity"], details.extraDetails],
    [["shipping", "pickup", "delivery", "location", "zip", "postal", "weight", "fragile", "large"], details.isLargeOrFragile],
    [["shipping", "pickup", "delivery", "location", "zip", "postal", "offer", "auction", "price"], marketplaceNotesText(details)],
  ];

  return fields.some(([fieldSignals, value]) => {
    if (value === true) return signalsOverlap(signals, fieldSignals);
    if (typeof value !== "string" || value.trim().length === 0) return false;
    return signalsOverlap(signals, fieldSignals) || containsAnySignal(value, signals);
  });
}

function confirmedProfileFactsCoverRequiredSignals(
  signals: string[],
  profile: IdentificationProfile | null,
): boolean {
  if (!profile) return false;
  return containsAnySignal(
    [
      ...profile.confirmedFacts,
      ...profile.previousCorrections,
    ].join(" "),
    signals,
  );
}

function profileStillNeedsRequiredSignals(
  signals: string[],
  profile: IdentificationProfile | null,
): boolean {
  if (!profile) return false;
  return containsAnySignal(
    [
      ...profile.unknownDetails,
      ...profile.conflictingClues,
      ...profile.evidenceNeeded,
    ].join(" "),
    signals,
  );
}

function requiredFieldSignals(field: string): string[] {
  const normalized = field
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
  if (!normalized) return [];

  const signalGroups: Record<string, string[]> = {
    category: ["category", "item type"],
    brand: ["brand", "maker", "manufacturer", "artist", "logo", "label", "mark"],
    model: ["model", "serial", "sku", "style", "code", "barcode", "upc", "number"],
    size: ["size", "measurement", "dimension", "fit"],
    material: ["material", "fabric", "metal", "wood", "leather", "sterling", "gold", "silver"],
    condition: ["condition", "flaw", "damage", "scratch", "wear", "working", "tested", "broken"],
    included: ["included", "accessory", "accessories", "box", "case", "charger", "paperwork", "certificate", "receipt", "parts"],
    shipping: ["shipping", "pickup", "delivery", "location", "zip", "postal", "weight", "fragile", "large"],
    authenticity: ["authentic", "authenticity", "certificate", "hallmark", "signature", "signed"],
    age: ["year", "age", "vintage", "antique", "edition", "limited", "numbered"],
    price: ["price", "offer", "auction", "fixed"],
    photo: ["photo", "image", "picture"],
    title: ["title"],
    description: ["description"],
  };

  const signals = Object.values(signalGroups)
    .filter((group) => group.some((signal) => normalized.includes(signal)))
    .flat();
  return uniqueStrings([normalized, ...signals], 24);
}

function marketplaceNotesText(details: ListingItemDetails): string {
  return Object.values(details.marketplaceNotes).join(" ");
}

function signalsOverlap(lhs: string[], rhs: string[]): boolean {
  return lhs.some((signal) => rhs.includes(signal));
}

function containsAnySignal(value: string, signals: string[]): boolean {
  const normalized = value.toLowerCase();
  return signals.some((signal) => normalized.includes(signal));
}

function playbookPostingNotes(profile: MarketplaceListingProfile): string[] {
  return [
    profile.shippingOrPickupGuidance,
    profile.officialHowToURLString ? `Use the official posting guide if you get stuck: ${profile.officialHowToURLString}` : null,
  ].filter((value): value is string => Boolean(value)).slice(0, 2);
}

function rejectUnsafeDraftText(text: string, field: string): string {
  if (/```/i.test(text)) {
    throw new HttpError(`${field} included markdown fences`, 502);
  }
  if (/^(title|description)\s*:/im.test(text)) {
    throw new HttpError(`${field} included listing section headings`, 502);
  }
  if (/^(here(?:'|’)?s|here is)\s+(?:your\s+)?listing\s*[:\-]/i.test(text)) {
    throw new HttpError(`${field} included a preamble`, 502);
  }
  return text.replace(/\s+\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim();
}

function positiveNumberOrFallback(value: unknown, fallback: number): number {
  const number = Number(value);
  if (Number.isFinite(number) && number > 0) {
    return Math.round(number * 100) / 100;
  }
  return Math.round(Math.max(fallback, 1) * 100) / 100;
}

function displayCondition(value: string): string {
  switch (normalizedIdentifier(value)) {
    case "likenew":
      return "Like New";
    case "forparts":
      return "For Parts";
    default:
      return value
        .replace(/([a-z])([A-Z])/g, "$1 $2")
        .replace(/\b\w/g, (letter) => letter.toUpperCase());
  }
}

function formatPlainPrice(value: number): string {
  return Number.isInteger(value) ? String(value) : value.toFixed(2);
}

function optionalPositiveNumber(value: unknown): number | null {
  const number = Number(value);
  if (Number.isFinite(number) && number > 0) {
    return Math.round(number * 100) / 100;
  }
  return null;
}

function optionalReferenceImageURL(value: unknown): string | null {
  const text = optionalCleanDraftText(value, 500);
  if (!text) return null;
  try {
    const url = new URL(text);
    if (url.protocol !== "https:" && url.protocol !== "http:") return null;
    return url.toString();
  } catch {
    return null;
  }
}

function cleanEvidenceSources(value: unknown, platform: MarketplaceId): StructuredEvidenceSource[] {
  if (!Array.isArray(value)) return [];
  const sources: StructuredEvidenceSource[] = [];
  const seen = new Set<string>();

  for (const entry of value) {
    const record = recordOrNull(entry);
    if (!record) continue;

    const url = optionalReferenceImageURL(record.url ?? record.sourceUrl ?? record.sourceURL);
    const rawSourceMarketplace = optionalCleanDraftText(
      record.sourceMarketplace ?? record.marketplace,
      48,
    );
    const title = optionalCleanDraftText(record.title ?? record.sourceTitle, 120);
    const dateChecked = optionalCleanDraftText(record.dateChecked ?? record.checkedDate, 32);
    const listingStatus = cleanListingStatus(
      record.listingStatus ?? record.status ?? record.sourceType ?? listingStatusFromPriceFields(record),
    );
    const conditionAndVariant = optionalCleanDraftText(
      record.conditionAndVariant ?? record.conditionVariant ?? record.variant,
      100,
    );
    const comparability = optionalCleanDraftText(record.comparability ?? record.confidence, 72);
    const price = optionalPositiveNumber(record.price ?? record.soldPrice ?? record.activePrice);

    if (
      !rawSourceMarketplace &&
      !title &&
      !url &&
      !dateChecked &&
      !listingStatus &&
      !conditionAndVariant &&
      !comparability &&
      price === null
    ) {
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

function mergedEvidenceSources(
  primarySources: StructuredEvidenceSource[],
  fallbackSources: StructuredEvidenceSource[],
): StructuredEvidenceSource[] {
  const sources: StructuredEvidenceSource[] = [];
  const seen = new Set<string>();

  for (const source of [...primarySources, ...fallbackSources]) {
    if (!hasEvidenceSourceReference(source)) continue;
    const key = [
      source.sourceMarketplace,
      source.title,
      source.url,
      source.dateChecked,
      source.listingStatus,
      source.conditionAndVariant,
      source.comparability,
      source.price?.toString() ?? "",
    ].join("|");
    if (seen.has(key)) continue;
    seen.add(key);
    sources.push(source);
    if (sources.length >= 4) break;
  }

  return sources;
}

function cleanListingStatus(value: unknown): string | null {
  const text = optionalCleanDraftText(value, 32);
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

function isSoldEvidenceSource(source: StructuredEvidenceSource): boolean {
  return source.listingStatus === "Sold" &&
    source.price !== null &&
    Boolean(source.dateChecked) &&
    hasEvidenceSourceReference(source);
}

function soldEvidencePrices(sources: StructuredEvidenceSource[]): number[] {
  return sources
    .filter(isSoldEvidenceSource)
    .map((source) => source.price)
    .filter((price): price is number => typeof price === "number" && Number.isFinite(price) && price > 0)
    .sort((lhs, rhs) => lhs - rhs);
}

function lowEvidencePrice(prices: number[]): number | null {
  return prices.length > 0 ? roundMoney(prices[0]) : null;
}

function highEvidencePrice(prices: number[]): number | null {
  return prices.length > 0 ? roundMoney(prices[prices.length - 1]) : null;
}

function medianEvidencePrice(prices: number[]): number | null {
  if (prices.length === 0) return null;
  const middle = Math.floor(prices.length / 2);
  if (prices.length % 2 === 1) return roundMoney(prices[middle]);
  return roundMoney((prices[middle - 1] + prices[middle]) / 2);
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

function listingEvidenceSummaryForDisplay(
  value: unknown,
  platform: MarketplaceId,
  evidenceSources: StructuredEvidenceSource[],
  soldEvidenceCount: number,
  priorComparison: PriorMarketplaceComparison | null,
): string | null {
  const summary = optionalCleanDraftText(value, 260);
  if (soldEvidenceCount > 0) {
    return summary ?? priorComparison?.evidenceSummary ?? null;
  }
  if (evidenceSources.length === 0) {
    return summary ?? priorComparison?.evidenceSummary ?? null;
  }

  const displayName = marketplaceDisplayNames[platform] ?? platform;
  const hasActiveEvidence = evidenceSources.some((source) => source.listingStatus === "Active");
  const hasOfficialEvidence = evidenceSources.some((source) => source.listingStatus === "Official");
  if (hasActiveEvidence && hasOfficialEvidence) {
    return `${displayName} has active or official evidence, but no verified sold comps for this final listing.`;
  }
  if (hasActiveEvidence) {
    return `${displayName} has active listing evidence, but no verified sold comps for this final listing.`;
  }
  if (hasOfficialEvidence) {
    return `${displayName} has official guidance, but no verified sold comps for this final listing.`;
  }
  return summary ?? `${displayName} evidence is limited because sold comps were not verified.`;
}

function hasEvidenceSourceReference(source: StructuredEvidenceSource): boolean {
  return Boolean(source.url || source.title);
}

type SupabaseServiceConfig = {
  supabaseUrl: string;
  serviceRoleKey: string;
};

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

function requireCleanListing(value: unknown, titleMaxCharacters: number): string {
  const listing = asString(value, "listing").trim();

  if (/```/i.test(listing)) {
    throw new HttpError("Listing response was not plain text", 502);
  }
  if (/^(here(?:'|’)?s|here is)\s+(?:your\s+)?listing\s*[:\-]/i.test(listing)) {
    throw new HttpError("Listing response included a preamble", 502);
  }

  const titleMatch = /^TITLE\s*:/im.exec(listing);
  if (!titleMatch) {
    throw new HttpError("Listing response missing required sections", 502);
  }
  const afterTitle = listing.slice(titleMatch.index + titleMatch[0].length);
  const descriptionMatch = /^DESCRIPTION\s*:/im.exec(afterTitle);
  if (!descriptionMatch) {
    throw new HttpError("Listing response missing required sections", 502);
  }

  const titleBody = afterTitle.slice(0, descriptionMatch.index).trim();
  const descriptionBody = afterTitle.slice(descriptionMatch.index + descriptionMatch[0].length).trim();
  if (!titleBody || !descriptionBody) {
    throw new HttpError("Listing response missing section text", 502);
  }
  if (titleBody.length > titleMaxCharacters) {
    throw new HttpError("Listing response title too long", 502);
  }

  return listing;
}
