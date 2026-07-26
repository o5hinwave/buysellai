import { fetchWithTimeout, HttpError, requireEnv, timeoutFromEnv } from "./http.ts";

type GeminiPart = { text?: string };
type GeminiResponse = {
  candidates?: Array<{
    content?: {
      parts?: GeminiPart[];
    };
    groundingMetadata?: {
      webSearchQueries?: unknown;
      groundingChunks?: unknown;
    };
    url_context_metadata?: {
      url_metadata?: unknown;
    };
    urlContextMetadata?: {
      urlMetadata?: unknown;
    };
  }>;
};
type GeminiInteractionImage = {
  data: string;
  mime_type?: string;
  mimeType?: string;
};
type GeminiInteractionResponse = {
  output_image?: GeminiInteractionImage;
  outputImage?: GeminiInteractionImage;
};

export type JsonSchema = Record<string, unknown>;
export type GeminiTool = Record<string, Record<string, unknown>>;
export const geminiGroundingSearchQueriesKey = "__geminiGroundingSearchQueries";
export const geminiGroundingSourcesKey = "__geminiGroundingSources";
export const geminiDefaultTextModel = "gemini-2.5-flash";

export const nanoBananaImageModels = {
  lite: "gemini-3.1-flash-lite-image",
  balanced: "gemini-3.1-flash-image",
  pro: "gemini-3-pro-image",
  legacy: "gemini-2.5-flash-image",
} as const;

export const nanoBananaDefaultImageModel = nanoBananaImageModels.balanced;

export type GeminiEditedImage = {
  imageBase64: string;
  mimeType: string;
  model: string;
};

type GeminiRequestOptions = {
  tools?: GeminiTool[];
  model?: string;
  temperature?: number;
  maxOutputTokens?: number;
};

type GeminiImageEditInput = {
  prompt: string;
  imageBase64: string;
  mimeType: string;
  aspectRatio?: string;
  model?: string;
};

export async function generateJsonWithGemini(
  systemInstruction: string,
  parts: unknown[],
  responseSchema: JsonSchema,
  options: GeminiRequestOptions = {},
): Promise<Record<string, unknown>> {
  const maxAttempts = 2;
  let lastError: unknown = null;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      return await generateJsonWithGeminiAttempt(
        systemInstruction,
        parts,
        responseSchema,
        options,
        attempt,
      );
    } catch (error) {
      lastError = error;
      if (!shouldRetryGeminiJson(error) || attempt >= maxAttempts) {
        throw error;
      }
    }
  }

  throw lastError;
}

export async function generateEditedImageWithGemini(
  input: GeminiImageEditInput,
): Promise<GeminiEditedImage> {
  const apiKey = requireEnv("GEMINI_API_KEY");
  const model = input.model?.trim() || Deno.env.get("GEMINI_IMAGE_MODEL")?.trim() ||
    nanoBananaDefaultImageModel;
  const timeoutMs = timeoutFromEnv("GEMINI_IMAGE_TIMEOUT_MS", 30_000, 5_000, 60_000);
  const response = await fetchWithTimeout(
    "https://generativelanguage.googleapis.com/v1beta/interactions",
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        model,
        input: [
          { type: "text", text: input.prompt },
          {
            type: "image",
            mime_type: input.mimeType,
            data: input.imageBase64,
          },
        ],
        response_format: {
          type: "image",
          mime_type: "image/jpeg",
          aspect_ratio: input.aspectRatio?.trim() || "1:1",
          image_size: "1K",
        },
      }),
    },
    {
      timeoutMs,
      timeoutMessage: "Provider image edit timed out",
      transportMessage: "Provider image edit transport failed",
    },
  );
  const responseText = await response.text();

  if (!response.ok) {
    throw new HttpError("Provider image edit failed", response.status === 429 ? 429 : 502);
  }

  const outputImage = parseInteractionImage(responseText);
  return {
    imageBase64: outputImage.data,
    mimeType: outputImage.mime_type ?? outputImage.mimeType ?? "image/jpeg",
    model,
  };
}

async function generateJsonWithGeminiAttempt(
  systemInstruction: string,
  parts: unknown[],
  responseSchema: JsonSchema,
  options: GeminiRequestOptions,
  attempt: number,
): Promise<Record<string, unknown>> {
  const apiKey = requireEnv("GEMINI_API_KEY");
  const model = options.model?.trim() || Deno.env.get("GEMINI_MODEL")?.trim() ||
    geminiDefaultTextModel;
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
  const timeoutMs = timeoutFromEnv("GEMINI_TIMEOUT_MS", 18_000);
  const usesTools = (options.tools?.length ?? 0) > 0;

  const response = await fetchWithTimeout(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify({
      system_instruction: {
        parts: [{ text: instructionForAttempt(systemInstruction, attempt) }],
      },
      contents: [{
        role: "user",
        parts,
      }],
      ...(options.tools?.length ? { tools: options.tools } : {}),
      generationConfig: {
        temperature: options.temperature ?? 0.2,
        ...(options.maxOutputTokens
          ? { maxOutputTokens: options.maxOutputTokens }
          : {}),
        ...(!usesTools
          ? {
            responseMimeType: "application/json",
            responseSchema,
          }
          : {}),
      },
    }),
  }, {
    timeoutMs,
    timeoutMessage: "Provider request timed out",
    transportMessage: "Provider transport failed",
  });
  const responseText = await response.text();

  if (!response.ok) {
    throw new HttpError("Provider request failed", response.status === 429 ? 429 : 502);
  }

  const payload = parseProviderPayload(responseText);
  const text = payload.candidates?.[0]?.content?.parts
    ?.map((part) => part.text ?? "")
    .join("")
    .trim();

  if (!text) {
    throw new HttpError("Provider returned an empty response", 502);
  }

  return attachGroundingMetadata(parseModelJson(text), payload);
}

function parseInteractionImage(text: string): GeminiInteractionImage {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text) as GeminiInteractionResponse;
  } catch {
    throw new HttpError("Provider image edit response was not valid JSON", 502);
  }

  if (!isRecord(parsed)) {
    throw new HttpError("Provider image edit response was not a JSON object", 502);
  }

  const image = imageBlock(parsed.output_image) ?? imageBlock(parsed.outputImage) ?? nestedImageBlock(parsed);
  if (!image) {
    throw new HttpError("Provider image edit returned no image", 502);
  }
  return image;
}

function nestedImageBlock(value: unknown): GeminiInteractionImage | null {
  if (Array.isArray(value)) {
    for (const entry of value) {
      const found = nestedImageBlock(entry);
      if (found) return found;
    }
    return null;
  }
  if (!isRecord(value)) return null;

  const direct = imageBlock(value);
  if (direct) return direct;
  for (const nested of Object.values(value)) {
    const found = nestedImageBlock(nested);
    if (found) return found;
  }
  return null;
}

function imageBlock(value: unknown): GeminiInteractionImage | null {
  if (!isRecord(value)) return null;
  const data = optionalString(value.data, 20_000_000);
  const mimeType = optionalString(value.mime_type, 80) ?? optionalString(value.mimeType, 80);
  if (!data) return null;
  if (mimeType && mimeType.startsWith("image/") === false) return null;
  return { data, ...(mimeType ? { mime_type: mimeType } : {}) };
}

function instructionForAttempt(systemInstruction: string, attempt: number): string {
  if (attempt <= 1) return systemInstruction;
  return [
    systemInstruction,
    "The previous provider response was not valid JSON for the app contract.",
    "Retry once and return only one strict JSON object. Do not include markdown, comments, prose, or trailing text.",
  ].join(" ");
}

function shouldRetryGeminiJson(error: unknown): boolean {
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

function parseProviderPayload(text: string): GeminiResponse {
  try {
    return JSON.parse(text) as GeminiResponse;
  } catch {
    throw new HttpError("Provider response was not valid JSON", 502);
  }
}

function parseModelJson(text: string): Record<string, unknown> {
  const unfenced = text
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();

  let parsed: unknown;
  try {
    parsed = JSON.parse(jsonObjectText(unfenced));
  } catch {
    throw new HttpError("Provider response was not valid model JSON", 502);
  }

  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new HttpError("Provider response was not a JSON object", 502);
  }

  return parsed as Record<string, unknown>;
}

function jsonObjectText(text: string): string {
  const firstBrace = text.indexOf("{");
  const lastBrace = text.lastIndexOf("}");
  if (firstBrace >= 0 && lastBrace > firstBrace) {
    return text.slice(firstBrace, lastBrace + 1);
  }
  return text;
}

function attachGroundingMetadata(
  result: Record<string, unknown>,
  payload: GeminiResponse,
): Record<string, unknown> {
  const candidate = payload.candidates?.[0];
  const searchQueries = stringArray(
    candidate?.groundingMetadata?.webSearchQueries,
    6,
    180,
  );
  const sources = uniqueStrings([
    ...sourceStringsFromGroundingChunks(
      candidate?.groundingMetadata?.groundingChunks,
    ),
    ...sourceStringsFromUrlMetadata(candidate?.url_context_metadata?.url_metadata),
    ...sourceStringsFromUrlMetadata(candidate?.urlContextMetadata?.urlMetadata),
  ], 8);

  return {
    ...result,
    ...(searchQueries.length ? { [geminiGroundingSearchQueriesKey]: searchQueries } : {}),
    ...(sources.length ? { [geminiGroundingSourcesKey]: sources } : {}),
  };
}

function sourceStringsFromGroundingChunks(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const sources: string[] = [];
  for (const chunk of value) {
    if (!isRecord(chunk) || !isRecord(chunk.web)) continue;
    const uri = optionalString(chunk.web.uri, 360);
    if (!uri) continue;
    const title = optionalString(chunk.web.title, 120);
    sources.push(title ? `${title}: ${uri}` : uri);
  }
  return sources;
}

function sourceStringsFromUrlMetadata(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const sources: string[] = [];
  for (const metadata of value) {
    if (!isRecord(metadata)) continue;
    const url = optionalString(metadata.retrieved_url, 360) ??
      optionalString(metadata.retrievedUrl, 360);
    if (!url) continue;
    const status = optionalString(metadata.url_retrieval_status, 80) ??
      optionalString(metadata.urlRetrievalStatus, 80);
    if (status && status !== "URL_RETRIEVAL_STATUS_SUCCESS") continue;
    sources.push(url);
  }
  return sources;
}

function stringArray(value: unknown, maxItems: number, maxLength: number): string[] {
  if (!Array.isArray(value)) return [];
  const values: string[] = [];
  for (const entry of value) {
    const text = optionalString(entry, maxLength);
    if (text) values.push(text);
  }
  return uniqueStrings(values, maxItems);
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

function optionalString(value: unknown, maxLength: number): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.slice(0, maxLength);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
