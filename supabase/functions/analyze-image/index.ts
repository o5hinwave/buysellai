import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { generateJsonWithGemini } from "../_shared/gemini.ts";
import { consumeEarlyAccessUsage } from "../_shared/entitlements.ts";
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

type NativeScanEvidence = {
  recognizedText: string[];
  barcodes: { payload: string; symbology: string }[];
  modelOrSerialCandidates: string[];
  photoQuality: PhotoQualityEvidence | null;
};

type PhotoQualityEvidence = {
  brightness: number;
  contrast: number;
  glareRatio: number;
  width: number;
  height: number;
  issue: string | null;
};

type AnalyzeReferenceImage = {
  title: string;
  url: string;
  source: string | null;
};

type NormalizedAnalyzeFact = {
  label: string;
  value: string;
  confidence: number;
};

type NormalizedLikelyMatch = {
  name: string;
  distinguishingQuestion: string;
  confidence: number;
};

type NormalizedValueQuestion = {
  question: string;
  reason: string;
  answerField: string;
  choices: string[];
  unknownFollowUpQuestion: string;
  unknownFollowUpChoices: string[];
};

type AdaptiveQuestionFallbackContext = {
  name: string;
  category: string;
  itemFacts: NormalizedAnalyzeFact[];
  missingFacts: string[];
  likelyMatches: NormalizedLikelyMatch[];
};

serve(async (request) => {
  const options = handleOptions(request);
  if (options) return options;

  try {
    requirePost(request);
    const body = await readJson(request);
    const imageDataUrl = requireImageDataUrl(body.imageDataUrl);
    const nativeScanEvidence = optionalNativeScanEvidence(body.nativeScanEvidence);
    const entitlement = await consumeEarlyAccessUsage(request, "analysis", {
      estimatedAiCostCents: 1.2,
      groundedSearchCount: 0,
    });
    const visualEvidence = await fetchVisionWebDetectionEvidence(imageDataUrl);

    const systemInstruction = [
        "You identify household resale items for BuySell AI.",
        "Return one JSON object only.",
        "Use a short concrete item name.",
        `category must be one of: ${categories.join(", ")}.`,
        `condition must be one of: ${conditions.join(", ")}.`,
        "currentPrice must be a plausible USD resale price greater than zero.",
        "Act like the item photo already gives you useful resale intelligence. Infer as much as a careful reseller could from the image before asking the user anything.",
        "Also return analysis.itemFacts with short label, visible value, and confidence from 0 to 1 for useful identity, condition, and listing facts.",
        "Return 4 to 8 itemFacts whenever the photo supports them. Include visible category, likely condition, material, color, size/capacity, included accessories, packaging, style, visible flaws, labels, model text, maker marks, age clues, and buyer-trust details when they can be seen.",
        "Do not waste itemFacts on vague filler. Good facts sound like Category: Handheld game console, Condition: Light screen wear visible, Included: Dock not visible, Material: Sterling mark visible, Value clue: First edition mark possible.",
        "Use condition from the photo when possible. If condition is uncertain, pick the closest condition enum and explain the visible clue in analysis.itemFacts instead of asking the user a generic condition question.",
        "For ordinary items, still check for money-moving clues: rare variant, limited edition, exact model, serial or style code, maker mark, hallmark, valuable material, signed/numbered status, sealed packaging, original box, working status, missing accessories, or serious flaws.",
        "Return analysis.missingFacts for facts that would materially affect sale price if the user knows them.",
        "Return analysis.valueQuestions with 1 to 4 item-specific questions that could change identification, price, or marketplace fit. These must be about this exact likely item, not generic category questions.",
        "Only ask valueQuestions after using all visible clues. Rank valueQuestions like an adaptive assistant: ask the next most useful question first, stop once extra answers would not materially improve the result, and avoid asking for facts already visible in itemFacts or native scan evidence.",
        "Prioritize questions that separate ordinary items from valuable variants: exact model or serial, production era, edition, maker mark, material, authenticity mark, SKU/style code, package label, included original box, working status, and the worst visible flaw.",
        "For watches, cameras, lenses, trading cards, media, games, music gear, appliances, and other specification-heavy items, look for money-moving clues such as reference number, movement, case size, lens mount, aperture, shutter count, grading company, card number, pressing, region, cartridge label, serial plate, or included controller, battery, charger, case, box, and manual.",
        "Write each valueQuestion as one plain sentence a non-expert can answer from the item in front of them. Prefer yes/no or 2 to 4 tap-friendly choices over open-ended wording.",
        "For valueQuestions, ask about visible-or-user-knowable facts such as exact model, year, edition, variant, size, capacity, material, maker mark, serial plate, authenticity mark, included box/certificate/accessories, working status, restoration, flaws, or high-value era.",
        "When the item could have valuable variants, ask a distinguishing question with short choices. Examples: Does the label say OLED or HAC-001? Is it first edition or later printing? Is there a 1920s maker mark? Is the box label present? Is it signed or numbered? Does the tag show wool, leather, sterling, or another material?",
        "Do not ask generic catch-all questions like anything else, tell us more, what condition is it in, or do you know more details. If the next answer would not change the item identity, price, marketplace fit, or listing quality, do not ask it.",
        "Each valueQuestion must include question, reason, answerField, and 2 to 4 choices. answerField must be one of brand, spec, condition, included, extra. Always allow uncertainty by making one choice I don't know.",
        "Each valueQuestion may include unknownFollowUpQuestion and unknownFollowUpChoices. Use them when a user who does not know the answer could still answer by looking closer: ask about weight, material, tag, stamp, label, serial number, size mark, box label, authenticity mark, included parts, whether it turns on, or the worst visible flaw.",
        "For brand, spec, included, and extra valueQuestions, include unknownFollowUpQuestion unless the answer is already fully visible. The follow-up should feel like the next spoken assistant turn: where to look, what to scan, or which visible clue to tap.",
        "unknownFollowUpQuestion must be easier and more concrete than the original question, like a guided back-and-forth without chat. It should tell the user exactly where to look or what to show next.",
        "unknownFollowUpChoices must be 2 to 3 short button labels, never a long checklist. They should be visible clues such as Back label, Size tag, Maker mark, No label, Turns on, Box included, or No obvious flaw.",
        "Return analysis.photoPrompt only when one extra photo would help. Choose one short action: Move it into better light. Show the tag. Show the front and back. Show the flaw. Step back so the whole item fits. Otherwise return an empty string.",
        "Return analysis.likelyMatches with up to 3 specific possible matches only when the identity, model, or variant is uncertain; include one plain question that distinguishes each match. Return an empty array when one clear match is enough.",
        "Use visual web evidence only when it clearly matches the pictured item or a close possible match.",
        "Return analysis.referenceImages with up to 3 public image URLs for identification checking only. They are not listing photos and must never be suggested as photos to post.",
        "Leave analysis.referenceImages empty if the visual web result is uncertain, unrelated, or not useful.",
        "Use native scan evidence when present. Treat recognized text, barcodes, QR payloads, model candidates, serial candidates, tags, labels, and visible codes as stronger evidence than a broad visual guess.",
        "Never invent a brand, model, serial number, barcode value, size, or SKU that is not visible in the image or native scan evidence.",
        "When native scan evidence includes useful text or codes, include them in analysis.itemFacts with confidence that reflects whether the value is exact or only a clue.",
        "When native scan evidence includes photoQuality.issue, return the matching plain photoPrompt instead of asking a new question: Move it into better light. Tilt the item to remove glare. Use more light. Step back so the whole item fits.",
        "Ignore tax and deductible concepts.",
      ].join(" ");
    const promptParts = [
        {
          text: [
            "Analyze this item photo for a simple resale listing.",
            `Visual web evidence: ${visualEvidence ? JSON.stringify(visualEvidence) : "none"}`,
            `Native scan evidence: ${nativeScanEvidence ? JSON.stringify(nativeScanEvidence) : "none"}`,
          ].join("\n"),
        },
        { inline_data: { mime_type: "image/jpeg", data: imageDataUrl.base64 } },
      ];
    const responseSchema = {
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
              valueQuestions: {
                type: "ARRAY",
                items: {
                  type: "OBJECT",
                  properties: {
                    question: { type: "STRING" },
                    reason: { type: "STRING" },
                    answerField: { type: "STRING", enum: ["brand", "spec", "condition", "included", "extra"] },
                    choices: {
                      type: "ARRAY",
                      items: { type: "STRING" },
                    },
                    unknownFollowUpQuestion: { type: "STRING" },
                    unknownFollowUpChoices: {
                      type: "ARRAY",
                      items: { type: "STRING" },
                    },
                  },
                  required: ["question", "reason", "answerField", "choices"],
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
            required: ["itemFacts", "missingFacts", "photoPrompt", "likelyMatches", "valueQuestions", "referenceImages"],
          },
        },
        required: ["name", "category", "condition", "currentPrice", "analysis"],
      };

    const result = await resilientAnalyzeJson(
      systemInstruction,
      promptParts,
      responseSchema,
      visualEvidence,
      nativeScanEvidence,
    );

    return jsonResponse({
      ...normalizeAnalyzeResult(result),
      entitlement,
    });
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status);
    }
    return errorResponse("Analyze failed", 500);
  }
});

async function resilientAnalyzeJson(
  systemInstruction: string,
  promptParts: unknown[],
  responseSchema: Record<string, unknown>,
  visualEvidence: VisualWebEvidence | null,
  nativeScanEvidence: NativeScanEvidence | null,
): Promise<Record<string, unknown>> {
  try {
    return await generateJsonWithGemini(
      systemInstruction,
      promptParts,
      responseSchema,
      { maxOutputTokens: 3_200 },
    );
  } catch (error) {
    if (!isRecoverableAnalyzeProviderError(error)) throw error;
    return deterministicAnalyzeFallback(visualEvidence, nativeScanEvidence);
  }
}

function isRecoverableAnalyzeProviderError(error: unknown): boolean {
  return error instanceof HttpError &&
    error.status === 502 &&
    (
      error.message === "Provider response was not valid JSON" ||
      error.message === "Provider returned an empty response" ||
      error.message === "Provider response was not valid model JSON" ||
      error.message === "Provider response was not a JSON object" ||
      error.message === "Provider transport failed"
    );
}

function deterministicAnalyzeFallback(
  visualEvidence: VisualWebEvidence | null,
  nativeScanEvidence: NativeScanEvidence | null,
): Record<string, unknown> {
  const visualGuess = bestVisualGuess(visualEvidence);
  const scanClue = bestNativeScanClue(nativeScanEvidence);
  const name = visualGuess ? possibleItemName(visualGuess) : "Item to identify";
  const category = categoryFromEvidenceText([name, visualGuess, scanClue].filter(Boolean).join(" "));
  const photoPrompt = nativeScanEvidence?.photoQuality?.issue
    ? photoPromptForQualityIssue(nativeScanEvidence.photoQuality.issue)
    : "Show the label.";

  return {
    name,
    category,
    condition: "good",
    currentPrice: 1,
    analysis: {
      itemFacts: [
        {
          label: "AI check",
          value: "Identification needs one more clue",
          confidence: 0.25,
        },
        ...(visualGuess
          ? [{
            label: "Possible visual match",
            value: visualGuess,
            confidence: 0.35,
          }]
          : []),
        ...(scanClue
          ? [{
            label: "Visible text clue",
            value: scanClue,
            confidence: 0.55,
          }]
          : []),
      ],
      missingFacts: [
        "Exact item name",
        "Brand or maker",
        "Model, size, or label",
        "Working condition",
        "Visible flaws",
      ],
      photoPrompt,
      likelyMatches: [],
      valueQuestions: [
        {
          question: "Can you find a label, tag, stamp, or model number?",
          reason: "That clue helps BuySell identify and price the item without guessing.",
          answerField: "spec",
          choices: ["Back label", "Bottom mark", "Tag or sticker", "I don't know"],
          unknownFollowUpQuestion: "Check the bottom, back, inside tag, or package.",
          unknownFollowUpChoices: ["Back label", "Bottom mark", "No label"],
        },
      ],
      referenceImages: [],
    },
  };
}

function bestVisualGuess(visualEvidence: VisualWebEvidence | null): string | null {
  return visualEvidence?.bestGuessLabels[0] ??
    visualEvidence?.matchingPageTitles[0] ??
    null;
}

function bestNativeScanClue(nativeScanEvidence: NativeScanEvidence | null): string | null {
  return nativeScanEvidence?.modelOrSerialCandidates[0] ??
    nativeScanEvidence?.recognizedText[0] ??
    nativeScanEvidence?.barcodes[0]?.payload ??
    null;
}

function possibleItemName(value: string): string {
  const clean = value
    .replace(/\s+/g, " ")
    .replace(/[|•].*$/, "")
    .trim();
  return clean.length > 80 ? clean.slice(0, 80).trim() : clean;
}

function categoryFromEvidenceText(text: string): string {
  const lower = text.toLowerCase();
  if (/\b(phone|laptop|tablet|camera|console|controller|headphones|speaker|keyboard)\b/.test(lower)) return "Electronics";
  if (/\b(chair|table|desk|sofa|couch|dresser|cabinet|nightstand|shelf)\b/.test(lower)) return "Furniture";
  if (/\b(shoe|sneaker|boot|heel|loafer)\b/.test(lower)) return "Shoes";
  if (/\b(shirt|jacket|coat|dress|pants|jeans|sweater|hoodie)\b/.test(lower)) return "Clothing";
  if (/\b(bag|purse|handbag|wallet|backpack)\b/.test(lower)) return "Bags";
  if (/\b(ring|necklace|bracelet|earring|watch|jewelry)\b/.test(lower)) return "Jewelry";
  if (/\b(lamp|vase|rug|mirror|decor|kitchen|mug|plate|glass)\b/.test(lower)) return "Home";
  if (/\b(drill|saw|tool|wrench|battery|charger)\b/.test(lower)) return "Tools";
  if (/\b(book|novel|textbook)\b/.test(lower)) return "Books";
  if (/\b(record|cd|dvd|blu-ray|game)\b/.test(lower)) return "Media";
  if (/\b(guitar|keyboard|amp|microphone|pedal)\b/.test(lower)) return "Music";
  if (/\b(card|comic|figure|collectible|antique|vintage)\b/.test(lower)) return "Collectibles";
  if (/\b(painting|print|sculpture|art)\b/.test(lower)) return "Art";
  return "Other";
}

function photoPromptForQualityIssue(issue: string): string {
  const lower = issue.toLowerCase();
  if (lower.includes("glare")) return "Tilt the item to remove glare.";
  if (lower.includes("dark") || lower.includes("light")) return "Use more light.";
  if (lower.includes("crop") || lower.includes("frame")) return "Step back so the whole item fits.";
  return "Show the label.";
}

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
    analysis: normalizeAnalyzeIntelligence(result.analysis, { name, category }),
  };
}

function asString(value: unknown, field: string): string {
  if (typeof value !== "string" || !value.trim()) {
    throw new HttpError(`Missing ${field}`, 502);
  }
  return value.trim();
}

function normalizeAnalyzeIntelligence(value: unknown, context: { name: string; category: string }) {
  const payload = isJsonObject(value) ? value : {};
  const itemFacts = unknownArray(payload.itemFacts)
    .map(normalizeAnalyzeFact)
    .filter((fact): fact is NormalizedAnalyzeFact => fact !== null)
    .slice(0, 8);
  const missingFacts = stringArray(payload.missingFacts, 5, 80);
  const likelyMatches = unknownArray(payload.likelyMatches)
    .map(normalizeLikelyMatch)
    .filter((match): match is NormalizedLikelyMatch => match !== null)
    .slice(0, 3);
  const valueQuestions = unknownArray(payload.valueQuestions)
    .map(normalizeValueQuestion)
    .filter((question): question is NormalizedValueQuestion => question !== null);
  const adaptiveValueQuestions = valueQuestions.length > 0
    ? valueQuestions
    : fallbackAdaptiveValueQuestions({
      ...context,
      itemFacts,
      missingFacts,
      likelyMatches,
    });

  return {
    itemFacts,
    missingFacts,
    photoPrompt: optionalString(payload.photoPrompt, 120) ?? "",
    likelyMatches,
    valueQuestions: adaptiveValueQuestions.slice(0, 4),
    referenceImages: normalizeReferenceImages(payload.referenceImages),
  };
}

function normalizeAnalyzeFact(value: unknown): NormalizedAnalyzeFact | null {
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

function normalizeLikelyMatch(value: unknown): NormalizedLikelyMatch | null {
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

const adaptiveQuestionSignals = [
  "accessor",
  "age",
  "authentic",
  "authenticity",
  "barcode",
  "battery",
  "box",
  "brand",
  "brass",
  "card",
  "card number",
  "capacity",
  "carrier",
  "case size",
  "certificate",
  "charger",
  "chip",
  "coa",
  "color",
  "crack",
  "dent",
  "dimension",
  "edition",
  "first edition",
  "flaw",
  "glass",
  "gold",
  "grade",
  "graded",
  "hole",
  "label",
  "leather",
  "lens",
  "lens mount",
  "logo",
  "maker",
  "mark",
  "material",
  "measurement",
  "model",
  "mount",
  "movement",
  "numbered",
  "part",
  "porcelain",
  "power",
  "pressing",
  "reference",
  "reference number",
  "repaired",
  "restoration",
  "region",
  "scratch",
  "sealed",
  "serial",
  "shipping",
  "signed",
  "silver",
  "size",
  "sku",
  "stamp",
  "sterling",
  "stain",
  "storage",
  "tag",
  "tested",
  "turn on",
  "variant",
  "vinyl",
  "vintage",
  "watch",
  "weight",
  "wool",
  "working",
  "year",
];

const lowValueGenericQuestionPatterns = [
  /\b(anything else|any other detail|tell us more|more information|more details|describe (it|the item)|what can you tell)\b/i,
  /^\s*(what\s+)?condition\s+(is|would)\s+(it|this|the item)/i,
  /^\s*(do you know|can you add)\s+(the\s+)?(brand|model|size|condition)\s*\??\s*$/i,
];

function normalizeValueQuestion(
  value: unknown,
): NormalizedValueQuestion | null {
  if (!isJsonObject(value)) return null;
  const question = optionalString(value.question, 120);
  const reason = optionalString(value.reason, 120) ?? "This can change the price.";
  const answerField = optionalString(value.answerField, 20);
  const allowedFields = new Set(["brand", "spec", "condition", "included", "extra"]);
  const choices = stringArray(value.choices, 4, 60)
      .filter(isButtonSizedAdaptiveChoice)
      .filter((choice, index, values) => values.findIndex((candidate) => candidate.toLowerCase() === choice.toLowerCase()) === index);
  if (!question || !answerField || !allowedFields.has(answerField) || choices.length === 0) return null;

  const unknownFollowUpQuestion = optionalString(value.unknownFollowUpQuestion, 100) ?? "";
  const unknownFollowUpChoices = stringArray(value.unknownFollowUpChoices, 3, 44)
    .filter(isButtonSizedAdaptiveChoice)
    .filter((choice) => choice.toLowerCase() !== "i don't know")
    .filter((choice, index, values) => values.findIndex((candidate) => candidate.toLowerCase() === choice.toLowerCase()) === index);
  if (!isSpecificAdaptiveQuestion(question, reason, choices, unknownFollowUpQuestion, unknownFollowUpChoices)) return null;

  const hasUnknownChoice = choices.some((choice) => choice.toLowerCase() === "i don't know");
  const displayChoices = hasUnknownChoice ? choices.slice(0, 4) : [...choices.slice(0, 3), "I don't know"];
  return {
    question,
    reason,
    answerField,
    choices: displayChoices,
    unknownFollowUpQuestion,
    unknownFollowUpChoices,
  };
}

function fallbackAdaptiveValueQuestions(
  context: AdaptiveQuestionFallbackContext,
): NormalizedValueQuestion[] {
  const fallback = fallbackAdaptiveValueQuestion(context);
  if (!fallback) return [];
  const normalized = normalizeValueQuestion(fallback);
  return normalized ? [normalized] : [];
}

function fallbackAdaptiveValueQuestion(
  context: AdaptiveQuestionFallbackContext,
): Record<string, unknown> | null {
  const category = context.category;
  const knownText = [
    context.name,
    ...context.itemFacts.map((fact) => `${fact.label} ${fact.value}`),
  ].join(" ").toLowerCase();
  const missingText = context.missingFacts.join(" ").toLowerCase();
  const hasUsefulGap = context.likelyMatches.length > 1 ||
    context.missingFacts.length > 0 ||
    highDetailFallbackCategories.has(category);
  if (!hasUsefulGap) return null;

  if (context.likelyMatches.length > 1 && !knownTextContainsAny(knownText, ["model", "style code", "sku", "edition"])) {
    return {
      question: "Which visible clue matches yours?",
      reason: "This can separate similar items before BuySell searches sold prices.",
      answerField: "spec",
      choices: ["Model label", "Size tag", "Maker mark", "I don't know"],
      unknownFollowUpQuestion: "Check the label, tag, bottom, back, or package.",
      unknownFollowUpChoices: ["Back label", "Size tag", "No label"],
    };
  }

  if (
    missingTextIncludesAny(missingText, ["watch", "movement", "reference", "case size", "strap"]) ||
    knownTextContainsAny(knownText, ["watch", "chronograph", "automatic", "quartz"])
  ) {
    return {
      question: "Any watch reference or movement clue?",
      reason: "Reference numbers, movement type, and case size can separate ordinary watches from valuable versions.",
      answerField: "extra",
      choices: ["Reference number", "Automatic or quartz", "Case size", "I don't know"],
      unknownFollowUpQuestion: "Check the case back, dial edge, clasp, or paperwork.",
      unknownFollowUpChoices: ["Case back", "Dial text", "No number"],
    };
  }

  if (
    missingTextIncludesAny(missingText, ["camera", "lens", "mount", "aperture", "shutter", "serial"]) ||
    knownTextContainsAny(knownText, ["camera", "lens", "dslr", "mirrorless", "35mm"])
  ) {
    return {
      question: "Any lens, mount, or shutter clue?",
      reason: "Camera bodies and lenses can sell very differently by mount, aperture, shutter count, and included kit.",
      answerField: "spec",
      choices: ["Lens mount", "Aperture shown", "Shutter count", "I don't know"],
      unknownFollowUpQuestion: "Check the lens ring, bottom plate, menu, or battery door.",
      unknownFollowUpChoices: ["Lens ring", "Bottom plate", "No clue"],
    };
  }

  if (
    missingTextIncludesAny(missingText, ["card", "grade", "graded", "psa", "bgs", "cgc", "card number"]) ||
    knownTextContainsAny(knownText, ["trading card", "pokemon", "sports card", "graded card"])
  ) {
    return {
      question: "Is there a grade, set, or card number?",
      reason: "Grades, set names, card numbers, and first editions drive sold comps for cards and collectibles.",
      answerField: "extra",
      choices: ["Graded slab", "Card number", "First edition", "I don't know"],
      unknownFollowUpQuestion: "Check the slab label, bottom corner, back, or set symbol.",
      unknownFollowUpChoices: ["Slab label", "Card back", "No grade"],
    };
  }

  if (
    category === "Music" ||
    category === "Media" ||
    missingTextIncludesAny(missingText, ["pressing", "vinyl", "region", "cartridge", "serial", "instrument"])
  ) {
    return {
      question: "Any pressing, region, or serial clue?",
      reason: "Pressing, region, cartridge label, and serial details can change music and media value.",
      answerField: "spec",
      choices: ["Pressing shown", "Region code", "Serial label", "I don't know"],
      unknownFollowUpQuestion: "Check the back cover, label, spine, cartridge, or serial plate.",
      unknownFollowUpChoices: ["Back label", "Spine text", "No code"],
    };
  }

  if (
    category === "Electronics" ||
    category === "Tools" ||
    category === "Music" ||
    missingTextIncludesAny(missingText, ["model", "serial", "storage", "capacity", "battery", "working"])
  ) {
    if (knownTextContainsAny(knownText, ["model", "serial", "storage"]) && !missingTextIncludesAny(missingText, ["working", "battery", "charger"])) {
      return null;
    }
    return {
      question: "Can you find the exact model or serial?",
      reason: "Small model differences can change sold comps, parts value, and buyer trust.",
      answerField: "spec",
      choices: ["Model plate", "Serial number", "Powers on", "I don't know"],
      unknownFollowUpQuestion: "Check the back, bottom, battery area, or settings.",
      unknownFollowUpChoices: ["Back label", "Settings screen", "No label"],
    };
  }

  if (
    category === "Clothing" ||
    category === "Shoes" ||
    category === "Bags" ||
    category === "Kids" ||
    missingTextIncludesAny(missingText, ["size", "tag", "material", "style code"])
  ) {
    if (knownTextContainsAny(knownText, ["size", "style code", "material"]) && !missingTextIncludesAny(missingText, ["box", "flaw"])) {
      return null;
    }
    return {
      question: "Any size, material, or style code?",
      reason: "Tags, style codes, materials, and box labels help find closer sold matches.",
      answerField: "spec",
      choices: ["Size tag", "Style code", "Material tag", "I don't know"],
      unknownFollowUpQuestion: "Check the inside tag, sole, pocket, or box label.",
      unknownFollowUpChoices: ["Inside tag", "Box label", "No tag"],
    };
  }

  if (
    category === "Jewelry" ||
    missingTextIncludesAny(missingText, ["hallmark", "sterling", "gold", "silver", "metal", "authenticity"])
  ) {
    if (knownTextContainsAny(knownText, ["925", "sterling", "14k", "18k", "hallmark"]) && !missingTextIncludesAny(missingText, ["certificate", "flaw"])) {
      return null;
    }
    return {
      question: "Do you see a metal stamp or hallmark?",
      reason: "Metal marks can separate costume jewelry from valuable material.",
      answerField: "extra",
      choices: ["925 or sterling", "Gold mark", "Maker mark", "I don't know"],
      unknownFollowUpQuestion: "Check the clasp, inside band, back, or tiny tag.",
      unknownFollowUpChoices: ["Metal stamp", "Maker mark", "No stamp"],
    };
  }

  if (
    category === "Collectibles" ||
    category === "Toys" ||
    category === "Media" ||
    category === "Books" ||
    missingTextIncludesAny(missingText, ["edition", "numbered", "signed", "sealed", "year", "certificate"])
  ) {
    return {
      question: "Could it be a special version?",
      reason: "Editions, years, sealed boxes, signatures, and numbers can change the sold-price search.",
      answerField: "extra",
      choices: ["Sealed", "Signed or numbered", "Year shown", "I don't know"],
      unknownFollowUpQuestion: "Check the package corners, back, copyright page, or certificate.",
      unknownFollowUpChoices: ["Edition shown", "Certificate", "No special mark"],
    };
  }

  if (
    category === "Art" ||
    category === "Home" ||
    category === "Furniture" ||
    missingTextIncludesAny(missingText, ["maker", "mark", "stamp", "signature", "material", "age", "vintage"])
  ) {
    return {
      question: "Any signature, maker mark, or age clue?",
      reason: "Marks, materials, signatures, and older construction can change where this should sell.",
      answerField: "extra",
      choices: ["Signed", "Maker mark", "Older style", "I don't know"],
      unknownFollowUpQuestion: "Check the back, bottom, underside, frame, or drawer.",
      unknownFollowUpChoices: ["Underneath mark", "Material clue", "No mark"],
    };
  }

  return {
    question: "Any clue that could make it worth more?",
    reason: "A stamp, label, number, material, age clue, or special mark can improve the search.",
    answerField: "extra",
    choices: ["Tag or sticker", "Stamped mark", "Material clue", "I don't know"],
    unknownFollowUpQuestion: "Check the bottom, back, tag, sticker, or package.",
    unknownFollowUpChoices: ["Number shown", "Special mark", "No clue"],
  };
}

const highDetailFallbackCategories = new Set([
  "Electronics",
  "Shoes",
  "Bags",
  "Jewelry",
  "Music",
  "Collectibles",
  "Art",
]);

function knownTextContainsAny(text: string, needles: string[]): boolean {
  return needles.some((needle) => text.includes(needle));
}

function missingTextIncludesAny(text: string, needles: string[]): boolean {
  return needles.some((needle) => text.includes(needle));
}

function isSpecificAdaptiveQuestion(
  question: string,
  reason: string,
  choices: string[],
  unknownFollowUpQuestion: string,
  unknownFollowUpChoices: string[],
): boolean {
  if (lowValueGenericQuestionPatterns.some((pattern) => pattern.test(question))) return false;

  const searchableText = [
    question,
    reason,
    unknownFollowUpQuestion,
    ...choices,
    ...unknownFollowUpChoices,
  ].join(" ").toLowerCase();
  if (!adaptiveQuestionSignals.some((signal) => searchableText.includes(signal))) return false;
  return adaptiveQuestionValueScore(searchableText) >= 2;
}

function adaptiveQuestionValueScore(searchableText: string): number {
  const highValueSignals = [
    "authentic",
    "band",
    "battery",
    "barcode",
    "box",
    "card number",
    "capacity",
    "case size",
    "carrier",
    "certificate",
    "charger",
    "coa",
    "edition",
    "first edition",
    "flaw",
    "grade",
    "graded",
    "hallmark",
    "lens",
    "lens mount",
    "maker",
    "material",
    "model",
    "movement",
    "numbered",
    "pressing",
    "reference number",
    "region",
    "sealed",
    "serial",
    "signed",
    "size",
    "sku",
    "stamp",
    "storage",
    "style code",
    "strap",
    "tested",
    "turn on",
    "upc",
    "variant",
    "vinyl",
    "vintage",
    "watch",
    "working",
    "year",
  ];
  const priceMovingSignals = [
    "accessor",
    "battery",
    "box",
    "card number",
    "capacity",
    "carrier",
    "charger",
    "flaw",
    "grade",
    "graded",
    "lens mount",
    "material",
    "movement",
    "pressing",
    "reference number",
    "region",
    "restoration",
    "sealed",
    "size",
    "storage",
    "tested",
    "turn on",
    "variant",
    "vinyl",
    "vintage",
    "watch",
    "working",
    "year",
  ];
  const visualHelpSignals = [
    "back",
    "bottom",
    "inside",
    "label",
    "lens ring",
    "logo",
    "mark",
    "plate",
    "slab label",
    "tag",
    "underneath",
    "worst",
  ];

  const score = [
    highValueSignals.some((signal) => searchableText.includes(signal)) ? 2 : 0,
    priceMovingSignals.some((signal) => searchableText.includes(signal)) ? 1 : 0,
    visualHelpSignals.some((signal) => searchableText.includes(signal)) ? 1 : 0,
  ].reduce((sum, value) => sum + value, 0);
  return score;
}

function isButtonSizedAdaptiveChoice(choice: string): boolean {
  const words = choice.split(/\s+/).filter(Boolean).length;
  return words <= 5 && /[.;:]/.test(choice) === false;
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

function optionalNativeScanEvidence(value: unknown): NativeScanEvidence | null {
  if (!isJsonObject(value)) return null;
  const recognizedText = stringArray(value.recognizedText, 8, 140);
  const barcodes = unknownArray(value.barcodes)
    .map(normalizeNativeScanBarcode)
    .filter((barcode): barcode is { payload: string; symbology: string } => barcode !== null)
    .slice(0, 4);
  const modelOrSerialCandidates = stringArray(value.modelOrSerialCandidates, 6, 120);
  const photoQuality = normalizePhotoQualityEvidence(value.photoQuality);

  if (recognizedText.length === 0 && barcodes.length === 0 && modelOrSerialCandidates.length === 0 && !photoQuality) {
    return null;
  }

  return {
    recognizedText,
    barcodes,
    modelOrSerialCandidates,
    photoQuality,
  };
}

function normalizeNativeScanBarcode(value: unknown): { payload: string; symbology: string } | null {
  if (!isJsonObject(value)) return null;
  const payload = optionalString(value.payload, 120);
  const symbology = optionalString(value.symbology, 40) ?? "unknown";
  if (!payload) return null;
  return { payload, symbology };
}

function normalizePhotoQualityEvidence(value: unknown): PhotoQualityEvidence | null {
  if (!isJsonObject(value)) return null;
  const width = boundedNumber(value.width, 1, 8_000);
  const height = boundedNumber(value.height, 1, 8_000);
  if (width === null || height === null) return null;
  return {
    brightness: boundedNumber(value.brightness, 0, 1) ?? 0,
    contrast: boundedNumber(value.contrast, 0, 1) ?? 0,
    glareRatio: boundedNumber(value.glareRatio, 0, 1) ?? 0,
    width,
    height,
    issue: optionalString(value.issue, 40),
  };
}

function boundedNumber(value: unknown, minimum: number, maximum: number): number | null {
  const number = Number(value);
  if (!Number.isFinite(number)) return null;
  return Math.min(Math.max(number, minimum), maximum);
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
        timeoutMs: timeoutFromEnv("GOOGLE_VISION_TIMEOUT_MS", 2_000),
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
