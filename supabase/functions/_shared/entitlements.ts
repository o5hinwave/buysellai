import {
  fetchWithTimeout,
  HttpError,
  readResponseJson,
  requireJsonArray,
  requireJsonObject,
  timeoutFromEnv,
} from "./http.ts";

export type EarlyAccessUsageAction = "analysis" | "marketplace_research" | "listing_generation";

type EntitlementState = "earlyAccess" | "free" | "plus" | "usagePack";

type EntitlementConfig = {
  state: EntitlementState;
  completeFeatureAccess: boolean;
  futurePaidAccessEnabled: boolean;
  dailyAnalysisLimit: number;
  dailyAiActionLimit: number;
  cooldownMessage: string;
};

type SupabaseServiceConfig = {
  supabaseUrl: string;
  serviceRoleKey: string;
};

type UsageIdentity = {
  userId: string | null;
  deviceId: string | null;
  ipHash: string | null;
  identityKey: string;
};

type UsageCounts = {
  analysis: number;
  aiActions: number;
};

export type EntitlementSnapshot = {
  state: EntitlementState;
  completeFeatureAccess: boolean;
  futurePaidAccessEnabled: boolean;
  remainingAnalyses: number;
  remainingAiActions: number;
};

const defaultConfig: EntitlementConfig = {
  state: "earlyAccess",
  completeFeatureAccess: true,
  futurePaidAccessEnabled: false,
  dailyAnalysisLimit: 100,
  dailyAiActionLimit: 300,
  cooldownMessage:
    "You've analyzed a lot of items today. BuySell needs a little time before the next one. Your saved listings are still available.",
};

const knownStates = new Set<EntitlementState>(["earlyAccess", "free", "plus", "usagePack"]);
const knownActions = new Set<EarlyAccessUsageAction>(["analysis", "marketplace_research", "listing_generation"]);
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function consumeEarlyAccessUsage(
  request: Request,
  action: EarlyAccessUsageAction,
  options: {
    estimatedAiCostCents?: number;
    groundedSearchCount?: number;
  } = {},
): Promise<EntitlementSnapshot> {
  if (!knownActions.has(action)) {
    throw new HttpError("Unsupported usage action", 500);
  }

  const service = supabaseServiceConfig();
  const config = await resilientEntitlementConfig(service);
  if (!service) {
    return snapshot(config, { analysis: 0, aiActions: 0 });
  }

  try {
    const identity = await resolveUsageIdentity(request, service);
    const since = startOfUtcDayIso();
    const counts = await fetchUsageCounts(service, identity, since);
    const nextAnalysisCount = counts.analysis + (action === "analysis" ? 1 : 0);
    const nextAiActionCount = counts.aiActions + 1;

    if (
      nextAnalysisCount > config.dailyAnalysisLimit ||
      nextAiActionCount > config.dailyAiActionLimit
    ) {
      throw new HttpError(config.cooldownMessage, 429);
    }

    await insertUsageEvent(service, config, identity, action, {
      estimatedAiCostCents: options.estimatedAiCostCents ?? 0,
      groundedSearchCount: options.groundedSearchCount ?? 0,
    });

    return snapshot(config, {
      analysis: nextAnalysisCount,
      aiActions: nextAiActionCount,
    });
  } catch (error) {
    if (error instanceof HttpError && error.status === 429) {
      throw error;
    }
    return snapshot(config, { analysis: 0, aiActions: 0 });
  }
}

function snapshot(config: EntitlementConfig, counts: UsageCounts): EntitlementSnapshot {
  return {
    state: config.state,
    completeFeatureAccess: config.completeFeatureAccess,
    futurePaidAccessEnabled: config.futurePaidAccessEnabled,
    remainingAnalyses: Math.max(config.dailyAnalysisLimit - counts.analysis, 0),
    remainingAiActions: Math.max(config.dailyAiActionLimit - counts.aiActions, 0),
  };
}

async function resilientEntitlementConfig(service: SupabaseServiceConfig | null): Promise<EntitlementConfig> {
  try {
    return await fetchEntitlementConfig(service);
  } catch {
    return defaultConfig;
  }
}

async function fetchEntitlementConfig(service: SupabaseServiceConfig | null): Promise<EntitlementConfig> {
  if (!service) return defaultConfig;

  const response = await serviceFetch(
    service,
    "/rest/v1/entitlement_config?config_key=eq.global&select=entitlement_state,complete_feature_access,future_paid_access_enabled,daily_analysis_limit,daily_ai_action_limit,cooldown_message&limit=1",
    { method: "GET" },
  );
  if (!response.ok) {
    throw new HttpError("Entitlement config unavailable", 503);
  }

  const rows = requireJsonArray(
    await readResponseJson(response, "Entitlement config response was not valid JSON"),
    "Entitlement config response was not a JSON array",
  );
  if (rows.length === 0) return defaultConfig;

  const row = requireJsonObject(rows[0], "Entitlement config row was not a JSON object");
  const state = typeof row.entitlement_state === "string" && knownStates.has(row.entitlement_state as EntitlementState)
    ? (row.entitlement_state as EntitlementState)
    : defaultConfig.state;
  const dailyAnalysisLimit = boundedInteger(row.daily_analysis_limit, defaultConfig.dailyAnalysisLimit, 10, 250);
  const dailyAiActionLimit = boundedInteger(row.daily_ai_action_limit, defaultConfig.dailyAiActionLimit, 10, 500);
  const cooldownMessage = cleanText(row.cooldown_message, 220) ?? defaultConfig.cooldownMessage;

  return {
    state,
    completeFeatureAccess: typeof row.complete_feature_access === "boolean"
      ? row.complete_feature_access
      : defaultConfig.completeFeatureAccess,
    futurePaidAccessEnabled: typeof row.future_paid_access_enabled === "boolean"
      ? row.future_paid_access_enabled
      : defaultConfig.futurePaidAccessEnabled,
    dailyAnalysisLimit,
    dailyAiActionLimit,
    cooldownMessage,
  };
}

async function resolveUsageIdentity(request: Request, service: SupabaseServiceConfig): Promise<UsageIdentity> {
  const userId = await verifiedUserId(request, service);
  const deviceId = normalizedDeviceId(request.headers.get("x-buysell-device-id"));
  const ipHash = await requestIpHash(request, service.serviceRoleKey);
  const identityKey = userId ? `user:${userId}` : deviceId ? `device:${deviceId}` : ipHash ? `ip:${ipHash}` : "request:unknown";

  return {
    userId,
    deviceId,
    ipHash,
    identityKey,
  };
}

async function verifiedUserId(request: Request, service: SupabaseServiceConfig): Promise<string | null> {
  const authorization = request.headers.get("authorization")?.trim() ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ")) return null;

  const response = await fetchWithTimeout(
    `${service.supabaseUrl}/auth/v1/user`,
    {
      method: "GET",
      headers: {
        authorization,
        apikey: service.serviceRoleKey,
      },
    },
    {
      timeoutMs: timeoutFromEnv("SUPABASE_SERVICE_TIMEOUT_MS", 8_000),
      timeoutMessage: "Supabase auth lookup timed out",
      transportMessage: "Supabase auth lookup failed",
      timeoutStatus: 503,
      transportStatus: 503,
    },
  );
  if (!response.ok) return null;

  const payload = requireJsonObject(
    await readResponseJson(response, "Supabase auth user response was not valid JSON"),
    "Supabase auth user response was not a JSON object",
  );
  const id = cleanText(payload.id, 64);
  return id && uuidPattern.test(id) ? id : null;
}

async function fetchUsageCounts(
  service: SupabaseServiceConfig,
  identity: UsageIdentity,
  since: string,
): Promise<UsageCounts> {
  const filters = [
    `identity_key=eq.${encodeURIComponent(identity.identityKey)}`,
    identity.deviceId ? `device_id=eq.${encodeURIComponent(identity.deviceId)}` : null,
    identity.ipHash ? `ip_hash=eq.${encodeURIComponent(identity.ipHash)}` : null,
  ].filter((value): value is string => value !== null);
  const rowSets = await Promise.all(filters.map((filter) => fetchUsageRows(service, filter, since)));
  return rowSets.reduce<UsageCounts>((maxCounts, rows) => {
    const counts = countUsageRows(rows);
    return {
      analysis: Math.max(maxCounts.analysis, counts.analysis),
      aiActions: Math.max(maxCounts.aiActions, counts.aiActions),
    };
  }, { analysis: 0, aiActions: 0 });
}

async function fetchUsageRows(
  service: SupabaseServiceConfig,
  filter: string,
  since: string,
): Promise<Array<Record<string, unknown>>> {
  const response = await serviceFetch(
    service,
    `/rest/v1/entitlement_usage_events?${filter}&occurred_at=gte.${encodeURIComponent(since)}&select=usage_action&limit=500`,
    { method: "GET" },
  );
  if (!response.ok) {
    throw new HttpError("Usage check unavailable", 503);
  }
  const rows = requireJsonArray(
    await readResponseJson(response, "Usage check response was not valid JSON"),
    "Usage check response was not a JSON array",
  );
  return rows.map((row) => requireJsonObject(row, "Usage row was not a JSON object"));
}

function countUsageRows(rows: Array<Record<string, unknown>>): UsageCounts {
  return rows.reduce<UsageCounts>((counts, row) => {
    const action = row.usage_action;
    return {
      analysis: counts.analysis + (action === "analysis" ? 1 : 0),
      aiActions: counts.aiActions + 1,
    };
  }, { analysis: 0, aiActions: 0 });
}

async function insertUsageEvent(
  service: SupabaseServiceConfig,
  config: EntitlementConfig,
  identity: UsageIdentity,
  action: EarlyAccessUsageAction,
  options: {
    estimatedAiCostCents: number;
    groundedSearchCount: number;
  },
): Promise<void> {
  const response = await serviceFetch(
    service,
    "/rest/v1/entitlement_usage_events",
    {
      method: "POST",
      headers: { prefer: "return=minimal" },
      body: JSON.stringify({
        entitlement_state: config.state,
        usage_action: action,
        user_id: identity.userId,
        device_id: identity.deviceId,
        ip_hash: identity.ipHash,
        identity_key: identity.identityKey,
        estimated_ai_cost_cents: nonnegativeNumber(options.estimatedAiCostCents),
        grounded_search_count: nonnegativeInteger(options.groundedSearchCount),
      }),
    },
  );
  if (!response.ok) {
    throw new HttpError("Usage could not be recorded", 503);
  }
}

async function serviceFetch(
  service: SupabaseServiceConfig,
  path: string,
  init: RequestInit,
): Promise<Response> {
  const headers = new Headers(serviceHeaders(service.serviceRoleKey));
  new Headers(init.headers ?? {}).forEach((value, key) => {
    headers.set(key, value);
  });

  return await fetchWithTimeout(
    `${service.supabaseUrl}${path}`,
    {
      ...init,
      headers,
    },
    {
      timeoutMs: timeoutFromEnv("SUPABASE_SERVICE_TIMEOUT_MS", 8_000),
      timeoutMessage: "Supabase service request timed out",
      transportMessage: "Supabase service transport failed",
      timeoutStatus: 503,
      transportStatus: 503,
    },
  );
}

function supabaseServiceConfig(): SupabaseServiceConfig | null {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim().replace(/\/+$/, "");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (!supabaseUrl || !serviceRoleKey) {
    return null;
  }
  return { supabaseUrl, serviceRoleKey };
}

function serviceHeaders(serviceRoleKey: string): HeadersInit {
  return {
    authorization: `Bearer ${serviceRoleKey}`,
    apikey: serviceRoleKey,
    "content-type": "application/json",
  };
}

function normalizedDeviceId(value: string | null): string | null {
  const trimmed = value?.trim() ?? "";
  return uuidPattern.test(trimmed) ? trimmed.toUpperCase() : null;
}

async function requestIpHash(request: Request, salt: string): Promise<string | null> {
  const rawIp = request.headers.get("cf-connecting-ip") ??
    request.headers.get("x-real-ip") ??
    request.headers.get("x-forwarded-for")?.split(",")[0] ??
    "";
  const ip = rawIp.trim();
  if (!ip) return null;

  const bytes = new TextEncoder().encode(`${salt}:${ip}`);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function startOfUtcDayIso(): string {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())).toISOString();
}

function boundedInteger(value: unknown, fallback: number, min: number, max: number): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) return fallback;
  return Math.min(Math.max(parsed, min), max);
}

function nonnegativeInteger(value: number): number {
  return Number.isInteger(value) && value > 0 ? value : 0;
}

function nonnegativeNumber(value: number): number {
  return Number.isFinite(value) && value > 0 ? Math.round(value * 10_000) / 10_000 : 0;
}

function cleanText(value: unknown, maxLength: number): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.replace(/\s+/g, " ").trim();
  return trimmed ? trimmed.slice(0, maxLength) : null;
}
