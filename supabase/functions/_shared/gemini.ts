import { fetchWithTimeout, HttpError, requireEnv, timeoutFromEnv } from "./http.ts";

type GeminiPart = { text?: string };
type GeminiResponse = {
  candidates?: Array<{
    content?: {
      parts?: GeminiPart[];
    };
  }>;
};

export type JsonSchema = Record<string, unknown>;

export async function generateJsonWithGemini(
  systemInstruction: string,
  parts: unknown[],
  responseSchema: JsonSchema,
): Promise<Record<string, unknown>> {
  const apiKey = requireEnv("GEMINI_API_KEY");
  const model = Deno.env.get("GEMINI_MODEL")?.trim() || "gemini-3.5-flash";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
  const timeoutMs = timeoutFromEnv("GEMINI_TIMEOUT_MS", 18_000);

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
      generationConfig: {
        temperature: 0.2,
        responseMimeType: "application/json",
        responseSchema,
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

  return parseModelJson(text);
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
