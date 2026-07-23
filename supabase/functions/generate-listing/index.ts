import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  geminiGroundingSearchQueriesKey,
  geminiGroundingSourcesKey,
  generateJsonWithGemini,
} from "../_shared/gemini.ts";
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

serve(async (request) => {
  const options = handleOptions(request);
  if (options) return options;

  try {
    requirePost(request);
    const body = await readJson(request);
    const item = requireItem(body.item);
    const platform = requireMarketplace(body.platform);
    const profile = marketplaceProfiles[platform];
    const researchPlan = createMarketplaceResearchPlan(item, platform, profile);
    const cachedResearch = await fetchMarketplaceResearchCache(researchPlan);
    const usesCachedResearch = cachedResearch !== null;

    const result = await generateJsonWithGemini(
      listingSystemInstruction(profile, usesCachedResearch),
      [{
        text: [
          `Marketplace: ${platform}`,
          `Marketplace title formula: ${profile.titleFormula}`,
          `Marketplace search focus: ${profile.searchFocus}`,
          `Photo guidance to mention if helpful: ${profile.photoGuidance}`,
          `Featured guidance to respect: ${profile.featuredGuidance}`,
          `Minimal marketplace research plan: ${JSON.stringify(researchPlan)}`,
          `Saved marketplace research: ${cachedResearch ? JSON.stringify(cachedResearch) : "none"}`,
          `Item: ${item.name}`,
          `Category: ${item.category}`,
          `Condition: ${item.condition}`,
          `Original price: ${item.originalPrice}`,
          `Current price: ${item.currentPrice}`,
        ].join("\n"),
      }],
      {
        type: "OBJECT",
        properties: {
          listing: { type: "STRING" },
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
        required: ["listing"],
      },
      {
        tools: usesCachedResearch ? [] : [
          { google_search: {} },
        ],
        maxOutputTokens: 4_096,
      },
    );

    const listing = requireCleanListing(result.listing, profile.titleMaxCharacters);
    await saveMarketplaceResearchCache(researchPlan, result);
    return jsonResponse({ listing });
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status);
    }
    return errorResponse("Listing generation failed", 500);
  }
});

type MarketplaceResearchPlan = {
  cacheKey: string;
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

type ListingItem = {
  name: string;
  category: string;
  condition: string;
  originalPrice: number;
  currentPrice: number;
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
  titleMaxCharacters: number;
  titleFormula: string;
  searchFocus: string;
  photoGuidance: string;
  featuredGuidance: string;
};

function listingSystemInstruction(
  profile: MarketplaceListingProfile,
  usesCachedResearch: boolean,
): string {
  return [
    "You write concise copy-paste resale listings for BuySell AI.",
    "Return one valid JSON object only, with no markdown fences.",
    "The JSON object must include a string field named listing.",
    "Do not return TITLE or DESCRIPTION as top-level JSON keys.",
    "The listing value must preserve plain text newlines.",
    "Use this exact section format: TITLE:\\n<title>\\n\\nDESCRIPTION:\\n<body>.",
    "Tailor the title and description for the marketplace provided, but never keyword-stuff.",
    usesCachedResearch
      ? "Use the saved marketplace research provided. Do not broaden beyond it."
      : "Use Google Search only for the minimal research plan provided.",
    "Prefer official marketplace guidance over stale assumptions.",
    "Do not use technical search-marketing acronyms in the listing or any returned field.",
    "Return usefulFindings, officialSources, and searchedFor only when the finding can help future listings.",
    `Keep TITLE at or below ${profile.titleMaxCharacters} characters.`,
    "Only use facts provided by the item name, category, condition, and price.",
    "Do not add markdown, preambles, watermarks, tax language, or follow-up questions.",
    "Keep the tone warm, direct, and useful for a person selling one thing.",
  ].join(" ");
}

function createMarketplaceResearchPlan(
  item: ListingItem,
  platform: MarketplaceId,
  profile: MarketplaceListingProfile,
): MarketplaceResearchPlan {
  const displayName = marketplaceDisplayNames[platform] ?? platform;
  const currentYear = new Date().getUTCFullYear();
  const category = normalizedIdentifier(item.category);
  const condition = normalizedIdentifier(item.condition);
  const searchQuestions = [
    `${displayName} official selling fees ${currentYear}`,
    `${displayName} official ${item.category} listing category condition guidance`,
    `${displayName} official photo title description guidance`,
  ];

  return {
    cacheKey: `${platform}:${category}:${condition}`,
    marketplace: platform,
    category: item.category,
    condition: item.condition,
    searchQuestions: searchQuestions.slice(0, 3),
    sourceTargets: [
      "official marketplace help pages",
      "official fee pages",
      "official prohibited or restricted item guidance when relevant",
    ],
    reason: `Need current rules, fee context, and posting guidance before drafting a ${profile.titleMaxCharacters}-character marketplace title.`,
  };
}

async function fetchMarketplaceResearchCache(
  plan: MarketplaceResearchPlan,
): Promise<MarketplaceResearchCache | null> {
  const service = supabaseServiceConfig();
  if (!service) return null;

  try {
    const now = encodeURIComponent(new Date().toISOString());
    const cacheKey = encodeURIComponent(plan.cacheKey);
    const select = "research_summary,useful_findings,official_sources,search_queries,updated_at";
    const response = await fetchWithTimeout(
      `${service.supabaseUrl}/rest/v1/marketplace_research_cache?cache_key=eq.${cacheKey}&expires_at=gt.${now}&select=${select}&limit=1`,
      { headers: serviceHeaders(service.serviceRoleKey) },
      supabaseServiceFetchOptions(),
    );
    if (!response.ok) return null;

    const rows = requireJsonArray(
      await readResponseJson(response, "Marketplace research cache response was not valid JSON"),
      "Marketplace research cache response was not a JSON array",
    );
    const row = rows[0];
    if (row === undefined) return null;

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
  } catch {
    return null;
  }
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
    searchFocus: "Exact sneaker identity, size, condition, defects, and seller approval readiness.",
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
