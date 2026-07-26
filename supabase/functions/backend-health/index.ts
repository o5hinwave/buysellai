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

const usageMonitoringWindowHours = 24;
const usageMonitoringThresholds = {
  dailyEventLimit: 200,
  dailyEstimatedAiCostCentsLimit: 500,
  dailyGroundedSearchLimit: 250,
  sampleLimit: 1_000,
};

type EntitlementHealth = {
  config_key: string;
  entitlement_state: string;
  complete_feature_access: boolean;
  future_paid_access_enabled: boolean;
  daily_analysis_limit: number;
  daily_ai_action_limit: number;
};

type SupabaseServiceConfig = {
  supabaseUrl: string;
  serviceRoleKey: string;
};

type UsageMonitoringStatus = "normal" | "watch" | "limit";

type UsageMonitoring = {
  status: UsageMonitoringStatus;
  windowHours: number;
  eventCount: number;
  analysisCount: number;
  marketplaceResearchCount: number;
  listingGenerationCount: number;
  estimatedAiCostCents: number;
  groundedSearchCount: number;
  thresholds: typeof usageMonitoringThresholds;
  alerts: string[];
};

type UsageSummary = {
  eventCount: number;
  analysisCount: number;
  marketplaceResearchCount: number;
  listingGenerationCount: number;
  estimatedAiCostCents: number;
  groundedSearchCount: number;
};

serve(async (request) => {
  const options = handleOptions(request);
  if (options) return options;

  try {
    requirePost(request);
    const service = supabaseServiceConfig();
    const entitlement = await fetchEntitlementHealth(service);
    validateEntitlement(entitlement);
    const usageMonitoring = await fetchUsageMonitoring(service);

    return jsonResponse({
      ok: true,
      service: "buysell-backend",
      entitlement,
      usageMonitoring,
      requiredMigrations,
    });
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status);
    }
    return errorResponse("Backend health check failed", 500);
  }
});

function supabaseServiceConfig(): SupabaseServiceConfig {
  const supabaseUrl = requireEnv("SUPABASE_URL").replace(/\/+$/, "");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  return { supabaseUrl, serviceRoleKey };
}

async function fetchEntitlementHealth(service: SupabaseServiceConfig): Promise<EntitlementHealth> {
  const response = await fetchWithTimeout(
    `${service.supabaseUrl}/rest/v1/entitlement_config?config_key=eq.global&select=config_key,entitlement_state,complete_feature_access,future_paid_access_enabled,daily_analysis_limit,daily_ai_action_limit&limit=1`,
    {
      headers: {
        apikey: service.serviceRoleKey,
        authorization: `Bearer ${service.serviceRoleKey}`,
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

async function fetchUsageMonitoring(service: SupabaseServiceConfig): Promise<UsageMonitoring> {
  const since = new Date(Date.now() - usageMonitoringWindowHours * 60 * 60 * 1_000).toISOString();
  const select = "usage_action,estimated_ai_cost_cents,grounded_search_count";
  const response = await fetchWithTimeout(
    `${service.supabaseUrl}/rest/v1/entitlement_usage_events?occurred_at=gte.${encodeURIComponent(since)}&select=${select}&order=occurred_at.desc&limit=${usageMonitoringThresholds.sampleLimit}`,
    {
      headers: {
        apikey: service.serviceRoleKey,
        authorization: `Bearer ${service.serviceRoleKey}`,
        accept: "application/json",
      },
    },
    {
      timeoutMs: 8_000,
      timeoutMessage: "Usage monitoring query timed out",
      transportMessage: "Usage monitoring query failed",
    },
  );

  if (!response.ok) {
    throw new HttpError("Usage monitoring query failed", 502);
  }

  const rows = requireJsonArray(
    await readResponseJson(response, "Invalid usage monitoring response"),
    "Invalid usage monitoring response",
  );
  const usage = rows.reduce<UsageSummary>((summary, value) => {
    const row = requireJsonObject(value, "Invalid usage monitoring row");
    const action = typeof row.usage_action === "string" ? row.usage_action : "";
    return {
      eventCount: summary.eventCount + 1,
      analysisCount: summary.analysisCount + (action === "analysis" ? 1 : 0),
      marketplaceResearchCount: summary.marketplaceResearchCount + (action === "marketplace_research" ? 1 : 0),
      listingGenerationCount: summary.listingGenerationCount + (action === "listing_generation" ? 1 : 0),
      estimatedAiCostCents: summary.estimatedAiCostCents + optionalNonnegativeNumber(row.estimated_ai_cost_cents),
      groundedSearchCount: summary.groundedSearchCount + optionalNonnegativeInteger(row.grounded_search_count),
    };
  }, {
    eventCount: 0,
    analysisCount: 0,
    marketplaceResearchCount: 0,
    listingGenerationCount: 0,
    estimatedAiCostCents: 0,
    groundedSearchCount: 0,
  });

  const normalizedUsage = {
    ...usage,
    estimatedAiCostCents: roundedNumber(usage.estimatedAiCostCents, 4),
  };
  const alerts = usageMonitoringAlerts(normalizedUsage, rows.length);

  return {
    status: usageMonitoringStatus(alerts),
    windowHours: usageMonitoringWindowHours,
    ...normalizedUsage,
    thresholds: usageMonitoringThresholds,
    alerts,
  };
}

function usageMonitoringAlerts(
  usage: {
    eventCount: number;
    estimatedAiCostCents: number;
    groundedSearchCount: number;
  },
  sampledRows: number,
): string[] {
  const alerts: string[] = [];
  if (usage.eventCount >= usageMonitoringThresholds.dailyEventLimit) {
    alerts.push("event_limit_reached");
  } else if (usage.eventCount >= usageMonitoringThresholds.dailyEventLimit * 0.75) {
    alerts.push("event_watch");
  }
  if (usage.estimatedAiCostCents >= usageMonitoringThresholds.dailyEstimatedAiCostCentsLimit) {
    alerts.push("ai_cost_limit_reached");
  } else if (usage.estimatedAiCostCents >= usageMonitoringThresholds.dailyEstimatedAiCostCentsLimit * 0.75) {
    alerts.push("ai_cost_watch");
  }
  if (usage.groundedSearchCount >= usageMonitoringThresholds.dailyGroundedSearchLimit) {
    alerts.push("grounded_search_limit_reached");
  } else if (usage.groundedSearchCount >= usageMonitoringThresholds.dailyGroundedSearchLimit * 0.75) {
    alerts.push("grounded_search_watch");
  }
  if (sampledRows >= usageMonitoringThresholds.sampleLimit) {
    alerts.push("usage_sample_limit_reached");
  }
  return alerts;
}

function usageMonitoringStatus(alerts: string[]): UsageMonitoringStatus {
  if (alerts.some((alert) => alert.endsWith("_limit_reached"))) {
    return "limit";
  }
  return alerts.length > 0 ? "watch" : "normal";
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

function optionalNonnegativeNumber(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) && value > 0 ? value : 0;
}

function optionalNonnegativeInteger(value: unknown): number {
  return typeof value === "number" && Number.isInteger(value) && value > 0 ? value : 0;
}

function roundedNumber(value: number, places: number): number {
  const scale = 10 ** places;
  return Math.round(value * scale) / scale;
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
