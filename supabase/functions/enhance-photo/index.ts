import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { consumeEarlyAccessUsage } from "../_shared/entitlements.ts";
import { generateEditedImageWithGemini } from "../_shared/gemini.ts";
import {
  errorResponse,
  handleOptions,
  HttpError,
  jsonResponse,
  readJson,
  requirePost,
} from "../_shared/http.ts";

const maxImageBytes = 7_000_000;
const allowedMimeTypes = new Set(["image/jpeg", "image/png", "image/webp"]);
const allowedSources = new Set(["camera", "photoLibrary", "unknownUserPhoto"]);
const allowedRoles = new Set([
  "cover",
  "fullItem",
  "label",
  "condition",
  "included",
  "enhancedCover",
]);
const allowedAspectRatios = new Set(["1:1", "4:3", "3:4", "16:9", "9:16"]);

serve(async (request) => {
  const options = handleOptions(request);
  if (options) return options;

  try {
    requirePost(request);
    const body = await readJson(request);
    const image = requireImageDataUrl(body.imageDataUrl);
    const prompt = requirePrompt(body.prompt);
    const source = requireSource(body.source);
    const role = requireRole(body.photoRole);
    const itemName = requireCleanText(body.itemName, "itemName", 100);
    const marketplace = requireCleanText(body.marketplace, "marketplace", 80);
    const sourcePhotoID = requireCleanText(body.sourcePhotoID, "sourcePhotoID", 80);
    const aspectRatio = optionalAspectRatio(body.aspectRatio);

    requireUserOwned(body.isUserOwned, source);
    requireNotAlreadyEdited(body.isAIEdited);
    requireSafePrompt(prompt);

    const entitlement = await consumeEarlyAccessUsage(request, "listing_generation", {
      estimatedAiCostCents: 4.8,
      groundedSearchCount: 0,
    });
    const edited = await generateEditedImageWithGemini({
      prompt: serverSafetyWrappedPrompt({
        prompt,
        itemName,
        marketplace,
        role,
      }),
      imageBase64: image.base64,
      mimeType: image.mimeType,
      aspectRatio,
    });

    return jsonResponse({
      imageDataUrl: `data:${edited.mimeType};base64,${edited.imageBase64}`,
      mimeType: edited.mimeType,
      model: edited.model,
      sourcePhotoID,
      relatedOriginalID: sourcePhotoID,
      outputSource: "aiEdited",
      outputPhotoRole: "enhancedCover",
      isAIEdited: true,
      isListingSafe: true,
      safetySummary:
        "Edited from the user's own photo. Original item, labels, serial marks, wear, damage, and included parts must be preserved.",
      entitlement,
    });
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status);
    }
    return errorResponse("Photo improvement failed", 500);
  }
});

type ParsedImage = {
  base64: string;
  mimeType: string;
};

function requireImageDataUrl(value: unknown): ParsedImage {
  if (typeof value !== "string") {
    throw new HttpError("Missing image", 400);
  }
  const match = value.match(/^data:(image\/(?:jpeg|png|webp));base64,([A-Za-z0-9+/=]+)$/);
  if (!match) {
    throw new HttpError("Image must be a JPEG, PNG, or WebP data URL", 400);
  }

  const mimeType = match[1];
  const base64 = match[2];
  if (!allowedMimeTypes.has(mimeType)) {
    throw new HttpError("Unsupported image type", 415);
  }
  const estimatedBytes = Math.floor(base64.length * 3 / 4);
  if (estimatedBytes <= 0 || estimatedBytes > maxImageBytes) {
    throw new HttpError("Image is too large", 413);
  }
  return { base64, mimeType };
}

function requirePrompt(value: unknown): string {
  const prompt = requireCleanText(value, "prompt", 3_200);
  if (prompt.length < 120) {
    throw new HttpError("Photo prompt is missing safety detail", 400);
  }
  return prompt;
}

function requireSource(value: unknown): string {
  const source = requireCleanText(value, "source", 40);
  if (!allowedSources.has(source)) {
    throw new HttpError("Only user-owned photos can be improved", 400);
  }
  return source;
}

function requireRole(value: unknown): string {
  const role = requireCleanText(value, "photoRole", 40);
  if (!allowedRoles.has(role)) {
    throw new HttpError("Photo role is not supported", 400);
  }
  return role;
}

function requireUserOwned(value: unknown, source: string): void {
  if (value !== true || !allowedSources.has(source)) {
    throw new HttpError("Only user-owned photos can be improved", 400);
  }
}

function requireNotAlreadyEdited(value: unknown): void {
  if (value === true) {
    throw new HttpError("Use the original photo for AI improvement", 400);
  }
}

function requireSafePrompt(prompt: string): void {
  const lower = prompt.toLowerCase();
  const requiredFragments = [
    "preserve",
    "labels",
    "serial",
    "wear",
    "damage",
    "condition",
      "do not generate a different item",
  ];
  if (requiredFragments.some((fragment) => lower.includes(fragment) === false)) {
    throw new HttpError("Photo prompt is missing safety detail", 400);
  }

  const unsafeInstructionText = prompt
    .split(/\n+/)
    .map((line) => line.trim())
    .filter((line) =>
      /^(do not|don't|never|must not|forbid|forbids)/i.test(line) === false
    )
    .join("\n");
  const forbiddenPatterns = [
    /\bremove\s+(all\s+)?(defects?|scratches?|damage|wear)\b/i,
    /\bmake\s+(it|this|item)\s+(look\s+)?new\b/i,
    /\bchange\s+(the\s+)?(logo|label|serial|color|material)\b/i,
    /\badd\s+(accessories|box|packaging|certificate)\b/i,
  ];
  if (forbiddenPatterns.some((pattern) => pattern.test(unsafeInstructionText))) {
    throw new HttpError("Photo prompt could misrepresent the item", 400);
  }
}

function serverSafetyWrappedPrompt(input: {
  prompt: string;
  itemName: string;
  marketplace: string;
  role: string;
}): string {
  return [
    "Improve one user-owned resale listing photo. This is an image edit of the provided photo, not a new product image.",
    `Item: ${input.itemName}. Marketplace: ${input.marketplace}. Requested photo role: ${input.role}.`,
    input.prompt,
    "Mandatory server safety rules:",
    "Preserve the exact photographed product, shape, color, materials, proportions, labels, serial marks, logos, text, included parts, visible wear, visible damage, and condition.",
    "Preserve visible defects, scratches, wear, damage, stains, missing parts, altered labels, serial marks, authenticity marks, and condition evidence.",
    "Do not invent accessories, packaging, certificates, features, authenticity, rarity, new condition, or a different item.",
    "Allowed edits are limited to exposure, white balance, careful sharpening, straightening, cropping, neutral background cleanup, realistic contact shadow, and marketplace-appropriate framing.",
    "Return one realistic edited listing photo derived from the supplied image.",
  ].join("\n");
}

function optionalAspectRatio(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const clean = value.trim();
  return allowedAspectRatios.has(clean) ? clean : undefined;
}

function requireCleanText(value: unknown, field: string, maxLength: number): string {
  if (typeof value !== "string") {
    throw new HttpError(`Missing ${field}`, 400);
  }
  const clean = value.trim();
  if (!clean) {
    throw new HttpError(`Missing ${field}`, 400);
  }
  return clean.slice(0, maxLength);
}
