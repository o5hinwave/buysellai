import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { generateJsonWithGemini } from "../_shared/gemini.ts";
import {
  errorResponse,
  fetchWithTimeout,
  handleOptions,
  HttpError,
  jsonResponse,
  readJson,
  readResponseJson,
  requireJsonObject,
  requirePost,
  timeoutFromEnv,
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

type ImageDataUrl = {
  base64: string;
};

type VisualWebEvidence = {
  bestGuessLabels: string[];
  matchingPageTitles: string[];
  matchingImageUrls: string[];
  similarImageUrls: string[];
};

type AnalyzeReferenceImage = {
  title: string;
  url: string;
  source: string | null;
};

serve(async (request) => {
  const options = handleOptions(request);
  if (options) return options;

  try {
    requirePost(request);
    const body = await readJson(request);
    const imageDataUrl = requireImageDataUrl(body.imageDataUrl);
    const visualEvidence = await fetchVisionWebDetectionEvidence(imageDataUrl);

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
        "Return analysis.likelyMatches with up to 3 specific possible matches only when the identity, model, or variant is uncertain; include one plain question that distinguishes each match. Return an empty array when one clear match is enough.",
        "Use visual web evidence only when it clearly matches the pictured item or a close possible match.",
        "Return analysis.referenceImages with up to 3 public image URLs for identification checking only. They are not listing photos and must never be suggested as photos to post.",
        "Leave analysis.referenceImages empty if the visual web result is uncertain, unrelated, or not useful.",
        "Ignore tax, deductible, and follow-up-question concepts.",
      ].join(" "),
      [
        {
          text: [
            "Analyze this item photo for a simple resale listing.",
            `Visual web evidence: ${visualEvidence ? JSON.stringify(visualEvidence) : "none"}`,
          ].join("\n"),
        },
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
              likelyMatches: {
                type: "ARRAY",
                items: {
                  type: "OBJECT",
                  properties: {
                    name: { type: "STRING" },
                    distinguishingQuestion: { type: "STRING" },
                    confidence: { type: "NUMBER", minimum: 0, maximum: 1 },
                  },
                  required: ["name", "distinguishingQuestion", "confidence"],
                },
              },
              referenceImages: {
                type: "ARRAY",
                items: {
                  type: "OBJECT",
                  properties: {
                    title: { type: "STRING" },
                    url: { type: "STRING" },
                    source: { type: "STRING" },
                  },
                  required: ["title", "url"],
                },
              },
            },
            required: ["itemFacts", "missingFacts", "photoPrompt", "likelyMatches", "referenceImages"],
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

function requireImageDataUrl(value: unknown): ImageDataUrl {
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
    likelyMatches: unknownArray(payload.likelyMatches)
      .map(normalizeLikelyMatch)
      .filter((match): match is { name: string; distinguishingQuestion: string; confidence: number } => match !== null)
      .slice(0, 3),
    referenceImages: normalizeReferenceImages(payload.referenceImages),
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

function normalizeLikelyMatch(value: unknown): { name: string; distinguishingQuestion: string; confidence: number } | null {
  if (!isJsonObject(value)) return null;
  const name = optionalString(value.name, 80);
  const distinguishingQuestion = optionalString(value.distinguishingQuestion, 120) ?? "";
  const confidence = Number(value.confidence);
  if (!name || !Number.isFinite(confidence)) return null;

  return {
    name,
    distinguishingQuestion,
    confidence: Math.round(Math.min(Math.max(confidence, 0), 1) * 100) / 100,
  };
}

function normalizeReferenceImages(value: unknown): AnalyzeReferenceImage[] {
  return unknownArray(value)
    .map(normalizeReferenceImage)
    .filter((image): image is AnalyzeReferenceImage => image !== null)
    .filter((image, index, images) => images.findIndex((candidate) => candidate.url === image.url) === index)
    .slice(0, 3);
}

function normalizeReferenceImage(value: unknown): AnalyzeReferenceImage | null {
  if (!isJsonObject(value)) return null;
  const title = optionalString(value.title, 80) ?? "Reference image";
  const url = optionalHttpUrl(value.url, 500);
  const source = optionalString(value.source, 80);
  if (!url) return null;

  return { title, url, source };
}

async function fetchVisionWebDetectionEvidence(
  imageDataUrl: ImageDataUrl,
): Promise<VisualWebEvidence | null> {
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

function optionalHttpUrl(value: unknown, maxLength: number): string | null {
  const text = optionalString(value, maxLength);
  if (!text) return null;
  try {
    const url = new URL(text);
    return url.protocol === "https:" || url.protocol === "http:" ? url.toString() : null;
  } catch {
    return null;
  }
}

function unknownArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function isJsonObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function recordOrNull(value: unknown): Record<string, unknown> | null {
  return isJsonObject(value) ? value : null;
}
