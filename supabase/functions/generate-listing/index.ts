import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { generateJsonWithGemini } from "../_shared/gemini.ts";
import {
  errorResponse,
  handleOptions,
  HttpError,
  jsonResponse,
  readJson,
  requirePost,
} from "../_shared/http.ts";

serve(async (request) => {
  const options = handleOptions(request);
  if (options) return options;

  try {
    requirePost(request);
    const body = await readJson(request);
    const item = requireItem(body.item);
    const platform = requireMarketplace(body.platform);

    const result = await generateJsonWithGemini(
      [
        "You write concise copy-paste resale listings for BuySell AI.",
        "Return one JSON object only with the key listing.",
        "The listing value must preserve plain text newlines.",
        "Use this exact section format: TITLE:\\n<title>\\n\\nDESCRIPTION:\\n<body>.",
        "Do not add markdown, preambles, watermarks, tax language, or follow-up questions.",
        "Keep the tone warm, direct, and useful for a person selling one thing.",
      ].join(" "),
      [{
        text: [
          `Marketplace: ${platform}`,
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
        },
        required: ["listing"],
      },
    );

    const listing = requireCleanListing(result.listing);
    return jsonResponse({ listing });
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status);
    }
    return errorResponse("Listing generation failed", 500);
  }
});

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

function requireMarketplace(value: unknown): string {
  const platform = asString(value, "platform").toLowerCase();
  if (!knownMarketplaceIdSet.has(platform)) {
    throw new HttpError("Unsupported platform", 400);
  }
  return platform;
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

function requireCleanListing(value: unknown): string {
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

  return listing;
}
