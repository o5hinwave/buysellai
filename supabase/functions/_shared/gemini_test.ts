import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { generateEditedImageWithGemini, generateJsonWithGemini } from "./gemini.ts";
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

Deno.test("Gemini image helper uses Interactions API and parses output image", async () => {
  const previousApiKey = Deno.env.get("GEMINI_API_KEY");
  const previousImageModel = Deno.env.get("GEMINI_IMAGE_MODEL");
  Deno.env.set("GEMINI_API_KEY", "test-key");
  Deno.env.delete("GEMINI_IMAGE_MODEL");

  globalThis.fetch = (async (input, init) => {
    assertEquals(String(input), "https://generativelanguage.googleapis.com/v1beta/interactions");
    assertEquals(init?.method, "POST");
    const headers = init?.headers as Record<string, string>;
    assertEquals(headers["x-goog-api-key"], "test-key");

    const body = JSON.parse(String(init?.body ?? "{}")) as {
      model?: string;
      input?: Array<Record<string, unknown>>;
      response_format?: Record<string, unknown>;
    };
    assertEquals(body.model, "gemini-3.1-flash-image");
    assertEquals(body.input?.[0], { type: "text", text: "Improve this listing photo safely." });
    assertEquals(body.input?.[1], {
      type: "image",
      mime_type: "image/jpeg",
      data: "aW1hZ2U=",
    });
    assertEquals(body.response_format?.type, "image");
    assertEquals(body.response_format?.mime_type, "image/jpeg");
    assertEquals(body.response_format?.aspect_ratio, "4:3");

    return new Response(JSON.stringify({
      output_image: {
        data: "ZWRpdGVk",
        mime_type: "image/jpeg",
      },
    }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;

  try {
    const result = await generateEditedImageWithGemini({
      prompt: "Improve this listing photo safely.",
      imageBase64: "aW1hZ2U=",
      mimeType: "image/jpeg",
      aspectRatio: "4:3",
    });

    assertEquals(result.imageBase64, "ZWRpdGVk");
    assertEquals(result.mimeType, "image/jpeg");
    assertEquals(result.model, "gemini-3.1-flash-image");
  } finally {
    restoreEnv("GEMINI_API_KEY", previousApiKey);
    restoreEnv("GEMINI_IMAGE_MODEL", previousImageModel);
    globalThis.fetch = originalFetch;
  }
});

Deno.test("Gemini image helper maps missing output image to provider error", async () => {
  const previousApiKey = Deno.env.get("GEMINI_API_KEY");
  Deno.env.set("GEMINI_API_KEY", "test-key");

  globalThis.fetch = (() =>
    Promise.resolve(new Response(JSON.stringify({ id: "interaction-id" }), {
      status: 200,
      headers: { "content-type": "application/json" },
    }))) as typeof fetch;

  try {
    await generateEditedImageWithGemini({
      prompt: "Improve this listing photo safely.",
      imageBase64: "aW1hZ2U=",
      mimeType: "image/jpeg",
    });
    throw new Error("Expected missing image error");
  } catch (error) {
    assertEquals(error instanceof HttpError, true);
    assertEquals((error as HttpError).status, 502);
    assertEquals((error as HttpError).message, "Provider image edit returned no image");
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
