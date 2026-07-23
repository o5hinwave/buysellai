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

const categories = [
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
];

const conditions = ["new", "likeNew", "good", "fair", "forParts"];
const maxImageBytes = 6_000_000;

serve(async (request) => {
  const options = handleOptions(request);
  if (options) return options;

  try {
    requirePost(request);
    const body = await readJson(request);
    const imageDataUrl = requireImageDataUrl(body.imageDataUrl);

    const result = await generateJsonWithGemini(
      [
        "You identify household resale items for BuySell AI.",
        "Return one JSON object only.",
        "Use a short concrete item name.",
        `category must be one of: ${categories.join(", ")}.`,
        `condition must be one of: ${conditions.join(", ")}.`,
        "currentPrice must be a plausible USD resale price greater than zero.",
        "Also return analysis.itemFacts with short label, visible value, and confidence from 0 to 1 for useful identity facts.",
        "Return analysis.missingFacts for facts that would materially affect sale price if the user knows them.",
        "Return analysis.photoPrompt as one plain sentence only when one extra photo would help; otherwise return an empty string.",
        "Ignore tax, deductible, and follow-up-question concepts.",
      ].join(" "),
      [
        { text: "Analyze this item photo for a simple resale listing." },
        { inline_data: { mime_type: "image/jpeg", data: imageDataUrl.base64 } },
      ],
      {
        type: "OBJECT",
        properties: {
          name: { type: "STRING" },
          category: { type: "STRING", enum: categories },
          condition: { type: "STRING", enum: conditions },
          currentPrice: { type: "NUMBER", minimum: 1 },
          analysis: {
            type: "OBJECT",
            properties: {
              itemFacts: {
                type: "ARRAY",
                items: {
                  type: "OBJECT",
                  properties: {
                    label: { type: "STRING" },
                    value: { type: "STRING" },
                    confidence: { type: "NUMBER", minimum: 0, maximum: 1 },
                  },
                  required: ["label", "value", "confidence"],
                },
              },
              missingFacts: {
                type: "ARRAY",
                items: { type: "STRING" },
              },
              photoPrompt: { type: "STRING" },
            },
            required: ["itemFacts", "missingFacts", "photoPrompt"],
          },
        },
        required: ["name", "category", "condition", "currentPrice", "analysis"],
      },
    );

    return jsonResponse(normalizeAnalyzeResult(result));
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status);
    }
    return errorResponse("Analyze failed", 500);
  }
});

function requireImageDataUrl(value: unknown): { base64: string } {
  if (typeof value !== "string" || !value.startsWith("data:image/jpeg;base64,")) {
    throw new HttpError("imageDataUrl must be a JPEG data URL", 400);
  }

  const base64 = value.slice("data:image/jpeg;base64,".length).trim();
  if (!base64 || !/^[A-Za-z0-9+/=]+$/.test(base64)) {
    throw new HttpError("imageDataUrl is not valid base64", 400);
  }

  const bytes = decodeImageBase64(base64);
  if (bytes.byteLength > maxImageBytes) {
    throw new HttpError("imageDataUrl is too large", 413);
  }
  if (!isJpegBytes(bytes)) {
    throw new HttpError("imageDataUrl must contain JPEG bytes", 400);
  }

  return { base64 };
}

function decodeImageBase64(base64: string): Uint8Array {
  try {
    const binary = atob(base64);
    return Uint8Array.from(binary, (character) => character.charCodeAt(0));
  } catch {
    throw new HttpError("imageDataUrl is not valid base64", 400);
  }
}

function isJpegBytes(bytes: Uint8Array): boolean {
  return bytes.byteLength >= 4 &&
    bytes[0] === 0xff &&
    bytes[1] === 0xd8 &&
    bytes[bytes.byteLength - 2] === 0xff &&
    bytes[bytes.byteLength - 1] === 0xd9;
}

function normalizeAnalyzeResult(result: Record<string, unknown>) {
  const name = asString(result.name, "name");
  const category = asString(result.category, "category");
  const condition = asString(result.condition, "condition");
  const price = Number(result.currentPrice);

  if (!categories.includes(category)) {
    throw new HttpError("Unsupported category", 502);
  }
  if (!conditions.includes(condition)) {
    throw new HttpError("Unsupported condition", 502);
  }
  if (!Number.isFinite(price) || price <= 0) {
    throw new HttpError("Invalid currentPrice", 502);
  }

  return {
    name,
    category,
    condition,
    currentPrice: Math.round(price * 100) / 100,
    analysis: normalizeAnalyzeIntelligence(result.analysis),
  };
}

function asString(value: unknown, field: string): string {
  if (typeof value !== "string" || !value.trim()) {
    throw new HttpError(`Missing ${field}`, 502);
  }
  return value.trim();
}

function normalizeAnalyzeIntelligence(value: unknown) {
  const payload = isJsonObject(value) ? value : {};
  return {
    itemFacts: unknownArray(payload.itemFacts)
      .map(normalizeAnalyzeFact)
      .filter((fact): fact is { label: string; value: string; confidence: number } => fact !== null)
      .slice(0, 8),
    missingFacts: stringArray(payload.missingFacts, 5, 80),
    photoPrompt: optionalString(payload.photoPrompt, 120) ?? "",
  };
}

function normalizeAnalyzeFact(value: unknown): { label: string; value: string; confidence: number } | null {
  if (!isJsonObject(value)) return null;
  const label = optionalString(value.label, 40);
  const factValue = optionalString(value.value, 80);
  const confidence = Number(value.confidence);
  if (!label || !factValue || !Number.isFinite(confidence)) return null;

  return {
    label,
    value: factValue,
    confidence: Math.round(Math.min(Math.max(confidence, 0), 1) * 100) / 100,
  };
}

function stringArray(value: unknown, maxItems: number, maxLength: number): string[] {
  return unknownArray(value)
    .map((entry) => optionalString(entry, maxLength))
    .filter((entry): entry is string => entry !== null)
    .slice(0, maxItems);
}

function optionalString(value: unknown, maxLength: number): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.slice(0, maxLength);
}

function unknownArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function isJsonObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
