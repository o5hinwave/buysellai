import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { generateJsonWithGemini } from "./gemini.ts";
import { HttpError } from "./http.ts";

const originalFetch = globalThis.fetch;

Deno.test("Gemini JSON helper retries one malformed model response", async () => {
  const previousApiKey = Deno.env.get("GEMINI_API_KEY");
  Deno.env.set("GEMINI_API_KEY", "test-key");
  let fetchCalls = 0;

  globalThis.fetch = (async (_input, init) => {
    fetchCalls += 1;
    const body = JSON.parse(String(init?.body ?? "{}")) as {
      system_instruction?: { parts?: Array<{ text?: string }> };
    };
    const instruction = body.system_instruction?.parts?.[0]?.text ?? "";

    if (fetchCalls === 1) {
      assertEquals(instruction.includes("previous provider response"), false);
      return geminiResponse("not json");
    }

    assertEquals(instruction.includes("previous provider response was not valid JSON"), true);
    return geminiResponse('{"ok":true}');
  }) as typeof fetch;

  try {
    const result = await generateJsonWithGemini(
      "Return JSON only.",
      [{ text: "test" }],
      { type: "object" },
    );

    assertEquals(result.ok, true);
    assertEquals(fetchCalls, 2);
  } finally {
    restoreEnv("GEMINI_API_KEY", previousApiKey);
    globalThis.fetch = originalFetch;
  }
});

Deno.test("Gemini JSON helper does not retry provider rate limits", async () => {
  const previousApiKey = Deno.env.get("GEMINI_API_KEY");
  Deno.env.set("GEMINI_API_KEY", "test-key");
  let fetchCalls = 0;

  globalThis.fetch = (() => {
    fetchCalls += 1;
    return Promise.resolve(new Response("rate limited", { status: 429 }));
  }) as typeof fetch;

  try {
    await generateJsonWithGemini(
      "Return JSON only.",
      [{ text: "test" }],
      { type: "object" },
    );
    throw new Error("Expected rate limit");
  } catch (error) {
    assertEquals(error instanceof HttpError, true);
    assertEquals((error as HttpError).status, 429);
    assertEquals(fetchCalls, 1);
  } finally {
    restoreEnv("GEMINI_API_KEY", previousApiKey);
    globalThis.fetch = originalFetch;
  }
});

function geminiResponse(text: string): Response {
  return new Response(JSON.stringify({
    candidates: [{
      content: {
        parts: [{ text }],
      },
    }],
  }), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}

function restoreEnv(name: string, value: string | undefined): void {
  if (typeof value === "string") {
    Deno.env.set(name, value);
  } else {
    Deno.env.delete(name);
  }
}
