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
    const platform = asString(body.platform, "platform");

    const result = await generateJsonWithGemini(
      [
        "You write concise copy-paste resale listings for BuySell AI.",
        "Return one JSON object only with the key listing.",
        "The listing value must preserve plain text newlines.",
        "Use this exact format: TITLE, blank line, DESCRIPTION.",
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

    const listing = asString(result.listing, "listing");
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

function requireItem(value: unknown): ListingItem {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError("item must be an object", 400);
  }
  const item = value as Record<string, unknown>;
  const originalPrice = asPositiveNumber(item.originalPrice, "originalPrice");
  const currentPrice = asPositiveNumber(item.currentPrice, "currentPrice");

  return {
    name: asString(item.name, "name"),
    category: asString(item.category, "category"),
    condition: asString(item.condition, "condition"),
    originalPrice,
    currentPrice,
  };
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
