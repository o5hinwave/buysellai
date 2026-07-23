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

export type JsonSchema = Record<string, unknown>;
export type GeminiTool = Record<string, Record<string, unknown>>;
export const geminiGroundingSearchQueriesKey = "__geminiGroundingSearchQueries";
export const geminiGroundingSourcesKey = "__geminiGroundingSources";

type GeminiRequestOptions = {
  tools?: GeminiTool[];
  model?: string;
  temperature?: number;
  maxOutputTokens?: number;
};

export async function generateJsonWithGemini(
  systemInstruction: string,
  parts: unknown[],
  responseSchema: JsonSchema,
  options: GeminiRequestOptions = {},
): Promise<Record<string, unknown>> {
  const apiKey = requireEnv("GEMINI_API_KEY");
  const model = options.model?.trim() || Deno.env.get("GEMINI_MODEL")?.trim() ||
    "gemini-2.5-flash";
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
        parts: [{ text: systemInstruction }],
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
    parsed = JSON.parse(unfenced);
  } catch {
    throw new HttpError("Provider response was not valid model JSON", 502);
  }

  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new HttpError("Provider response was not a JSON object", 502);
  }

  return parsed as Record<string, unknown>;
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
