import { consumeEarlyAccessUsage } from "./entitlements.ts";
import { HttpError } from "./http.ts";

type CapturedFetch = {
  url: string;
  method: string;
  authorization: string | null;
  apikey: string | null;
  body: string | null;
};

const originalFetch = globalThis.fetch;

Deno.test("early access usage resolves to full free access without service credentials", async () => {
  const previousUrl = Deno.env.get("SUPABASE_URL");
  const previousServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  Deno.env.delete("SUPABASE_URL");
  Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");

  let fetchCalls = 0;
  globalThis.fetch = (() => {
    fetchCalls += 1;
    return Promise.resolve(jsonResponse({ unexpected: true }));
  }) as typeof fetch;

  try {
    const entitlement = await consumeEarlyAccessUsage(new Request("https://example.test"), "analysis");

    assertEquals(entitlement.state, "earlyAccess");
    assertEquals(entitlement.completeFeatureAccess, true);
    assertEquals(entitlement.futurePaidAccessEnabled, false);
    assertEquals(entitlement.remainingAnalyses, 18);
    assertEquals(entitlement.remainingAiActions, 54);
    assertEquals(fetchCalls, 0);
  } finally {
    restoreEnv("SUPABASE_URL", previousUrl);
    restoreEnv("SUPABASE_SERVICE_ROLE_KEY", previousServiceRoleKey);
    globalThis.fetch = originalFetch;
  }
});

Deno.test("early access usage records service-side user, device, and IP-aware usage", async () => {
  const captured: CapturedFetch[] = [];
  await withServiceEnv(async () => {
    globalThis.fetch = (async (input, init) => {
      const request = captureFetch(input, init);
      captured.push(request);

      if (request.url.includes("/rest/v1/entitlement_config")) {
        return jsonResponse([
          {
            entitlement_state: "earlyAccess",
            complete_feature_access: true,
            future_paid_access_enabled: false,
            daily_analysis_limit: 18,
            daily_ai_action_limit: 54,
            cooldown_message:
              "You've analyzed a lot of items today. BuySell needs a little time before the next one. Your saved listings are still available.",
          },
        ]);
      }

      if (
        request.url.includes("/rest/v1/entitlement_usage_events?") &&
        request.method === "GET"
      ) {
        return jsonResponse([]);
      }

      if (
        request.url.endsWith("/rest/v1/entitlement_usage_events") &&
        request.method === "POST"
      ) {
        return new Response(null, { status: 201 });
      }

      throw new Error(`Unexpected fetch: ${request.method} ${request.url}`);
    }) as typeof fetch;

    const deviceId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
    const entitlement = await consumeEarlyAccessUsage(
      new Request("https://example.test", {
        headers: {
          "x-buysell-device-id": deviceId,
          "x-forwarded-for": "203.0.113.8",
        },
      }),
      "analysis",
      {
        estimatedAiCostCents: 1.23456,
        groundedSearchCount: 2,
      },
    );

    assertEquals(entitlement.state, "earlyAccess");
    assertEquals(entitlement.completeFeatureAccess, true);
    assertEquals(entitlement.futurePaidAccessEnabled, false);
    assertEquals(entitlement.remainingAnalyses, 17);
    assertEquals(entitlement.remainingAiActions, 53);

    const usageInsert = captured.find((request) =>
      request.method === "POST" && request.url.endsWith("/rest/v1/entitlement_usage_events")
    );
    assertExists(usageInsert);
    assertEquals(usageInsert.authorization, "Bearer service-role-key");
    assertEquals(usageInsert.apikey, "service-role-key");

    const body = JSON.parse(usageInsert.body ?? "{}") as Record<string, unknown>;
    assertEquals(body.entitlement_state, "earlyAccess");
    assertEquals(body.usage_action, "analysis");
    assertEquals(body.device_id, deviceId.toUpperCase());
    assertEquals(body.identity_key, `device:${deviceId.toUpperCase()}`);
    assertEquals(typeof body.ip_hash, "string");
    assertEquals((body.ip_hash as string).length, 64);
    assertEquals(body.estimated_ai_cost_cents, 1.2346);
    assertEquals(body.grounded_search_count, 2);

    const usageReads = captured.filter((request) =>
      request.method === "GET" && request.url.includes("/rest/v1/entitlement_usage_events?")
    );
    assertEquals(usageReads.length, 3);
    assert(usageReads.some((request) => request.url.includes("identity_key=eq.device%3A")));
    assert(usageReads.some((request) => request.url.includes("device_id=eq.")));
    assert(usageReads.some((request) => request.url.includes("ip_hash=eq.")));
  });
});

Deno.test("early access usage keeps AI available when entitlement config is unavailable", async () => {
  const captured: CapturedFetch[] = [];
  await withServiceEnv(async () => {
    globalThis.fetch = (async (input, init) => {
      const request = captureFetch(input, init);
      captured.push(request);

      if (request.url.includes("/rest/v1/entitlement_config")) {
        return jsonResponse({ message: "not available" }, 503);
      }

      throw new Error(`Unexpected fetch: ${request.method} ${request.url}`);
    }) as typeof fetch;

    const entitlement = await consumeEarlyAccessUsage(new Request("https://example.test"), "analysis");

    assertEquals(entitlement.state, "earlyAccess");
    assertEquals(entitlement.completeFeatureAccess, true);
    assertEquals(entitlement.futurePaidAccessEnabled, false);
    assertEquals(entitlement.remainingAnalyses, 18);
    assertEquals(entitlement.remainingAiActions, 54);
    assert(
      captured.some((request) =>
        request.method === "GET" && request.url.includes("/rest/v1/entitlement_config")
      ),
    );
  });
});

Deno.test("early access usage keeps AI available when usage recording is unavailable", async () => {
  const captured: CapturedFetch[] = [];
  await withServiceEnv(async () => {
    globalThis.fetch = (async (input, init) => {
      const request = captureFetch(input, init);
      captured.push(request);

      if (request.url.includes("/rest/v1/entitlement_config")) {
        return jsonResponse([
          {
            entitlement_state: "earlyAccess",
            complete_feature_access: true,
            future_paid_access_enabled: false,
            daily_analysis_limit: 18,
            daily_ai_action_limit: 54,
            cooldown_message:
              "You've analyzed a lot of items today. BuySell needs a little time before the next one. Your saved listings are still available.",
          },
        ]);
      }

      if (
        request.url.includes("/rest/v1/entitlement_usage_events?") &&
        request.method === "GET"
      ) {
        return jsonResponse({ message: "not available" }, 503);
      }

      throw new Error(`Unexpected fetch: ${request.method} ${request.url}`);
    }) as typeof fetch;

    const entitlement = await consumeEarlyAccessUsage(new Request("https://example.test"), "analysis");

    assertEquals(entitlement.state, "earlyAccess");
    assertEquals(entitlement.completeFeatureAccess, true);
    assertEquals(entitlement.futurePaidAccessEnabled, false);
    assertEquals(entitlement.remainingAnalyses, 18);
    assertEquals(entitlement.remainingAiActions, 54);
    assert(
      captured.some((request) =>
        request.method === "GET" && request.url.includes("/rest/v1/entitlement_usage_events?")
      ),
    );
  });
});

Deno.test("early access usage returns a friendly cooldown before inserting over-limit usage", async () => {
  const captured: CapturedFetch[] = [];
  await withServiceEnv(async () => {
    globalThis.fetch = (async (input, init) => {
      const request = captureFetch(input, init);
      captured.push(request);

      if (request.url.includes("/rest/v1/entitlement_config")) {
        return jsonResponse([
          {
            entitlement_state: "earlyAccess",
            complete_feature_access: true,
            future_paid_access_enabled: false,
            daily_analysis_limit: 10,
            daily_ai_action_limit: 54,
            cooldown_message:
              "You've analyzed a lot of items today. BuySell needs a little time before the next one. Your saved listings are still available.",
          },
        ]);
      }

      if (
        request.url.includes("/rest/v1/entitlement_usage_events?") &&
        request.method === "GET"
      ) {
        return jsonResponse(Array.from({ length: 10 }, () => ({ usage_action: "analysis" })));
      }

      throw new Error(`Unexpected fetch: ${request.method} ${request.url}`);
    }) as typeof fetch;

    try {
      await consumeEarlyAccessUsage(new Request("https://example.test"), "analysis");
      throw new Error("Expected rate limit");
    } catch (error) {
      assert(error instanceof HttpError);
      assertEquals(error.status, 429);
      assertEquals(
        error.message,
        "You've analyzed a lot of items today. BuySell needs a little time before the next one. Your saved listings are still available.",
      );
    }

    assertEquals(
      captured.some((request) =>
        request.method === "POST" && request.url.endsWith("/rest/v1/entitlement_usage_events")
      ),
      false,
    );
  });
});

async function withServiceEnv(work: () => Promise<void>): Promise<void> {
  const previousUrl = Deno.env.get("SUPABASE_URL");
  const previousServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  Deno.env.set("SUPABASE_URL", "https://project.supabase.co");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-key");

  try {
    await work();
  } finally {
    restoreEnv("SUPABASE_URL", previousUrl);
    restoreEnv("SUPABASE_SERVICE_ROLE_KEY", previousServiceRoleKey);
    globalThis.fetch = originalFetch;
  }
}

function captureFetch(input: string | URL | Request, init?: RequestInit): CapturedFetch {
  const url = typeof input === "string"
    ? input
    : input instanceof URL
    ? input.toString()
    : input.url;
  const headers = new Headers(init?.headers ?? (input instanceof Request ? input.headers : undefined));
  return {
    url,
    method: init?.method ?? (input instanceof Request ? input.method : "GET"),
    authorization: headers.get("authorization"),
    apikey: headers.get("apikey"),
    body: typeof init?.body === "string" ? init.body : null,
  };
}

function jsonResponse(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function restoreEnv(name: string, value: string | undefined): void {
  if (value === undefined) {
    Deno.env.delete(name);
  } else {
    Deno.env.set(name, value);
  }
}

function assert(condition: unknown, message = "Assertion failed"): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

function assertExists<T>(value: T | null | undefined): asserts value is T {
  assert(value !== null && value !== undefined, "Expected value to exist");
}

function assertEquals<T>(actual: T, expected: T): void {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
  }
}
