import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  errorResponse,
  fetchWithTimeout,
  handleOptions,
  HttpError,
  jsonResponse,
  readResponseJson,
  requireEnv,
  requireJsonArray,
  requireJsonObject,
  requirePost,
} from "../_shared/http.ts";

const requiredMigrations = [
  "20260724233029",
  "20260726132434",
  "20260726134945",
];

type EntitlementHealth = {
  config_key: string;
  entitlement_state: string;
  complete_feature_access: boolean;
  future_paid_access_enabled: boolean;
  daily_analysis_limit: number;
  daily_ai_action_limit: number;
};

serve(async (request) => {
  const options = handleOptions(request);
  if (options) return options;

  try {
    requirePost(request);
    const entitlement = await fetchEntitlementHealth();
    validateEntitlement(entitlement);

    return jsonResponse({
      ok: true,
      service: "buysell-backend",
      entitlement,
      requiredMigrations,
    });
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status);
    }
    return errorResponse("Backend health check failed", 500);
  }
});

async function fetchEntitlementHealth(): Promise<EntitlementHealth> {
  const supabaseUrl = requireEnv("SUPABASE_URL").replace(/\/+$/, "");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  const response = await fetchWithTimeout(
    `${supabaseUrl}/rest/v1/entitlement_config?config_key=eq.global&select=config_key,entitlement_state,complete_feature_access,future_paid_access_enabled,daily_analysis_limit,daily_ai_action_limit&limit=1`,
    {
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
        accept: "application/json",
      },
    },
    {
      timeoutMs: 8_000,
      timeoutMessage: "Entitlement health query timed out",
      transportMessage: "Entitlement health query failed",
    },
  );

  if (!response.ok) {
    throw new HttpError("Entitlement health query failed", 502);
  }

  const data = requireJsonArray(await readResponseJson(response, "Invalid entitlement health response"), "Invalid entitlement health response");
  if (data.length !== 1) {
    throw new HttpError("Expected one entitlement configuration", 500);
  }

  const row = requireJsonObject(data[0], "Invalid entitlement configuration");
  return {
    config_key: requireString(row.config_key, "config_key"),
    entitlement_state: requireString(row.entitlement_state, "entitlement_state"),
    complete_feature_access: requireBoolean(row.complete_feature_access, "complete_feature_access"),
    future_paid_access_enabled: requireBoolean(row.future_paid_access_enabled, "future_paid_access_enabled"),
    daily_analysis_limit: requireNumber(row.daily_analysis_limit, "daily_analysis_limit"),
    daily_ai_action_limit: requireNumber(row.daily_ai_action_limit, "daily_ai_action_limit"),
  };
}

function validateEntitlement(entitlement: EntitlementHealth): void {
  const expected: EntitlementHealth = {
    config_key: "global",
    entitlement_state: "earlyAccess",
    complete_feature_access: true,
    future_paid_access_enabled: false,
    daily_analysis_limit: 18,
    daily_ai_action_limit: 54,
  };

  for (const [key, value] of Object.entries(expected)) {
    if (entitlement[key as keyof EntitlementHealth] !== value) {
      throw new HttpError(`Unexpected entitlement ${key}`, 500);
    }
  }
}

function requireString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim() === "") {
    throw new HttpError(`Invalid entitlement ${field}`, 500);
  }
  return value;
}

function requireBoolean(value: unknown, field: string): boolean {
  if (typeof value !== "boolean") {
    throw new HttpError(`Invalid entitlement ${field}`, 500);
  }
  return value;
}

function requireNumber(value: unknown, field: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpError(`Invalid entitlement ${field}`, 500);
  }
  return value;
}
