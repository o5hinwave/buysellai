import { HttpError, requireEnv } from "./http.ts";

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
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`;

  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      system_instruction: {
        parts: [{ text: systemInstruction }],
      },
      contents: [{
        role: "user",
        parts,
      }],
      generation_config: {
        temperature: 0.2,
        response_mime_type: "application/json",
        response_schema: responseSchema,
      },
    }),
  });

  if (!response.ok) {
    throw new HttpError("Provider request failed", response.status === 429 ? 429 : 502);
  }

  const payload = await response.json() as GeminiResponse;
  const text = payload.candidates?.[0]?.content?.parts
    ?.map((part) => part.text ?? "")
    .join("")
    .trim();

  if (!text) {
    throw new HttpError("Provider returned an empty response", 502);
  }

  return parseModelJson(text);
}

function parseModelJson(text: string): Record<string, unknown> {
  const unfenced = text
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();

  const parsed = JSON.parse(unfenced);
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new HttpError("Provider response was not a JSON object", 502);
  }

  return parsed as Record<string, unknown>;
}
