import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  emptyResponse,
  errorResponse,
  fetchWithTimeout,
  handleOptions,
  HttpError,
  readJson,
  readResponseJson,
  requireEnv,
  requireJsonArray,
  requireJsonObject,
  requirePost,
  timeoutFromEnv,
} from "../_shared/http.ts";
import { revokeAppleToken } from "../_shared/apple.ts";

serve(async (request) => {
  const options = handleOptions(request);
  if (options) return options;

  try {
    requirePost(request);
    await readJson(request);

    const supabaseUrl = requireEnv("SUPABASE_URL").replace(/\/+$/, "");
    const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
    const bearerToken = requireBearerToken(request.headers.get("authorization"));
    const user = await fetchCurrentUser(supabaseUrl, serviceRoleKey, bearerToken);
    const appleToken = await fetchAppleToken(supabaseUrl, serviceRoleKey, user.id);

    if (appleToken) {
      await tryRevokeAppleToken(appleToken);
      await deleteAppleToken(supabaseUrl, serviceRoleKey, user.id);
    }

    await deleteHistory(supabaseUrl, serviceRoleKey, user.id);
    await deleteAuthUser(supabaseUrl, serviceRoleKey, user.id);

    return emptyResponse(204);
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status);
    }
    return errorResponse("Delete account failed", 500);
  }
});

type SupabaseUser = { id: string };
type AppleTokenRow = {
  refresh_token?: string | null;
  access_token?: string | null;
};

function requireBearerToken(header: string | null): string {
  const match = /^Bearer\s+(.+)$/i.exec(header ?? "");
  if (!match?.[1]) {
    throw new HttpError("Missing bearer token", 401);
  }
  return match[1].trim();
}

async function fetchCurrentUser(
  supabaseUrl: string,
  serviceRoleKey: string,
  bearerToken: string,
): Promise<SupabaseUser> {
  const response = await fetchWithTimeout(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      authorization: `Bearer ${bearerToken}`,
      apikey: serviceRoleKey,
    },
  }, supabaseServiceFetchOptions());

  if (!response.ok) {
    throw new HttpError("Invalid bearer token", 401);
  }

  const payload = requireJsonObject(
    await readResponseJson(response, "Supabase user response was not valid JSON"),
    "Supabase user response was not a JSON object",
  ) as Partial<SupabaseUser>;
  if (typeof payload.id !== "string" || !payload.id) {
    throw new HttpError("Invalid user response", 401);
  }
  return { id: payload.id };
}

async function deleteHistory(supabaseUrl: string, serviceRoleKey: string, userId: string): Promise<void> {
  const response = await fetchWithTimeout(`${supabaseUrl}/rest/v1/history?user_id=eq.${encodeURIComponent(userId)}`, {
    method: "DELETE",
    headers: serviceHeaders(serviceRoleKey),
  }, supabaseServiceFetchOptions());

  if (!response.ok) {
    throw new HttpError("Could not delete history", 502);
  }
}

async function fetchAppleToken(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
): Promise<AppleTokenRow | null> {
  const response = await fetchWithTimeout(
    `${supabaseUrl}/rest/v1/apple_auth_tokens?user_id=eq.${encodeURIComponent(userId)}&select=refresh_token,access_token&limit=1`,
    { headers: serviceHeaders(serviceRoleKey) },
    supabaseServiceFetchOptions(),
  );

  if (!response.ok) {
    throw new HttpError("Could not fetch Apple token", 502);
  }

  const rows = requireJsonArray(
    await readResponseJson(response, "Apple token rows response was not valid JSON"),
    "Apple token rows response was not a JSON array",
  );
  const row = rows[0];
  if (row === undefined) return null;
  return requireJsonObject(row, "Apple token row was not a JSON object") as AppleTokenRow;
}

async function tryRevokeAppleToken(token: AppleTokenRow): Promise<void> {
  try {
    await revokeAppleToken({
      refreshToken: token.refresh_token,
      accessToken: token.access_token,
    });
  } catch (error) {
    if (isAppleSecretConfigurationError(error)) {
      throw error;
    }
    // Account deletion must still complete if Apple token cleanup is stale or unavailable.
  }
}

function isAppleSecretConfigurationError(error: unknown): boolean {
  return error instanceof HttpError &&
    error.status === 500 &&
    (/^Missing APPLE_/.test(error.message) || error.message === "Invalid Apple private key");
}

async function deleteAppleToken(supabaseUrl: string, serviceRoleKey: string, userId: string): Promise<void> {
  const response = await fetchWithTimeout(`${supabaseUrl}/rest/v1/apple_auth_tokens?user_id=eq.${encodeURIComponent(userId)}`, {
    method: "DELETE",
    headers: serviceHeaders(serviceRoleKey),
  }, supabaseServiceFetchOptions());

  if (!response.ok) {
    throw new HttpError("Could not delete Apple token", 502);
  }
}

async function deleteAuthUser(supabaseUrl: string, serviceRoleKey: string, userId: string): Promise<void> {
  const response = await fetchWithTimeout(`${supabaseUrl}/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
    method: "DELETE",
    headers: serviceHeaders(serviceRoleKey),
  }, supabaseServiceFetchOptions());

  if (!response.ok) {
    throw new HttpError("Could not delete auth user", 502);
  }
}

function serviceHeaders(serviceRoleKey: string): HeadersInit {
  return {
    authorization: `Bearer ${serviceRoleKey}`,
    apikey: serviceRoleKey,
    "content-type": "application/json",
  };
}

function supabaseServiceFetchOptions() {
  return {
    timeoutMs: timeoutFromEnv("SUPABASE_SERVICE_TIMEOUT_MS", 8_000),
    timeoutMessage: "Supabase service request timed out",
    transportMessage: "Supabase service transport failed",
  };
}
