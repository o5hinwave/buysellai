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
import { exchangeAppleAuthorizationCode } from "../_shared/apple.ts";

serve(async (request) => {
  const options = handleOptions(request);
  if (options) return options;

  try {
    requirePost(request);
    const body = await readJson(request);
    const authorizationCode = requireString(body, "authorization_code");
    const appleUserId = requireString(body, "apple_user_id");

    const supabaseUrl = requireEnv("SUPABASE_URL").replace(/\/+$/, "");
    const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
    const bearerToken = requireBearerToken(request.headers.get("authorization"));
    const user = await fetchCurrentUser(supabaseUrl, serviceRoleKey, bearerToken);
    await assertAppleIdentityAvailable(supabaseUrl, serviceRoleKey, appleUserId, user.id);
    const appleToken = await exchangeAppleAuthorizationCode(authorizationCode);

    if (!appleToken.identitySubject) {
      throw new HttpError("Apple token response missing identity subject", 502);
    }
    if (appleToken.identitySubject !== appleUserId) {
      throw new HttpError("Apple token subject mismatch", 401);
    }

    await upsertAppleToken(supabaseUrl, serviceRoleKey, {
      user_id: user.id,
      apple_user_id: appleUserId,
      refresh_token: appleToken.refreshToken,
      access_token: appleToken.accessToken ?? null,
      access_token_expires_at: appleToken.accessTokenExpiresAt ?? null,
      updated_at: new Date().toISOString(),
    });

    return emptyResponse(204);
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status);
    }
    return errorResponse("Could not store Apple authorization", 500);
  }
});

type SupabaseUser = { id: string };
type ExistingAppleTokenRow = { user_id?: string | null };

type AppleTokenRow = {
  user_id: string;
  apple_user_id: string;
  refresh_token: string;
  access_token: string | null;
  access_token_expires_at: string | null;
  updated_at: string;
};

function requireString(body: Record<string, unknown>, key: string): string {
  const value = body[key];
  if (typeof value !== "string" || !value.trim()) {
    throw new HttpError(`Missing ${key}`, 400);
  }
  return value.trim();
}

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

async function assertAppleIdentityAvailable(
  supabaseUrl: string,
  serviceRoleKey: string,
  appleUserId: string,
  userId: string,
): Promise<void> {
  const existingUserId = await fetchAppleTokenOwner(supabaseUrl, serviceRoleKey, appleUserId);
  if (existingUserId && existingUserId !== userId) {
    throw new HttpError("Apple account is already linked", 409);
  }
}

async function fetchAppleTokenOwner(
  supabaseUrl: string,
  serviceRoleKey: string,
  appleUserId: string,
): Promise<string | null> {
  const response = await fetchWithTimeout(
    `${supabaseUrl}/rest/v1/apple_auth_tokens?apple_user_id=eq.${encodeURIComponent(appleUserId)}&select=user_id&limit=1`,
    { headers: serviceHeaders(serviceRoleKey) },
    supabaseServiceFetchOptions(),
  );

  if (!response.ok) {
    throw new HttpError("Could not check Apple token owner", 502);
  }

  const rows = requireJsonArray(
    await readResponseJson(response, "Apple token owner response was not valid JSON"),
    "Apple token owner response was not a JSON array",
  );

  const row = rows[0];
  if (row === undefined) return null;
  const payload = requireJsonObject(row, "Apple token owner row was not a JSON object") as ExistingAppleTokenRow;
  return typeof payload.user_id === "string" && payload.user_id ? payload.user_id : null;
}

async function upsertAppleToken(
  supabaseUrl: string,
  serviceRoleKey: string,
  row: AppleTokenRow,
): Promise<void> {
  const response = await fetchWithTimeout(`${supabaseUrl}/rest/v1/apple_auth_tokens?on_conflict=user_id`, {
    method: "POST",
    headers: {
      ...serviceHeaders(serviceRoleKey),
      prefer: "resolution=merge-duplicates",
    },
    body: JSON.stringify(row),
  }, supabaseServiceFetchOptions());

  if (!response.ok) {
    if (response.status === 409) {
      throw new HttpError("Apple account is already linked", 409);
    }
    throw new HttpError("Could not store Apple token", 502);
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
