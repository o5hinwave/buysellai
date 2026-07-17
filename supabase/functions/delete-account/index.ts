import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  emptyResponse,
  errorResponse,
  handleOptions,
  HttpError,
  readJson,
  requireEnv,
  requirePost,
} from "../_shared/http.ts";

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
  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      authorization: `Bearer ${bearerToken}`,
      apikey: serviceRoleKey,
    },
  });

  if (!response.ok) {
    throw new HttpError("Invalid bearer token", 401);
  }

  const payload = await response.json() as Partial<SupabaseUser>;
  if (typeof payload.id !== "string" || !payload.id) {
    throw new HttpError("Invalid user response", 401);
  }
  return { id: payload.id };
}

async function deleteHistory(supabaseUrl: string, serviceRoleKey: string, userId: string): Promise<void> {
  const response = await fetch(`${supabaseUrl}/rest/v1/history?user_id=eq.${encodeURIComponent(userId)}`, {
    method: "DELETE",
    headers: serviceHeaders(serviceRoleKey),
  });

  if (!response.ok) {
    throw new HttpError("Could not delete history", 502);
  }
}

async function deleteAuthUser(supabaseUrl: string, serviceRoleKey: string, userId: string): Promise<void> {
  const response = await fetch(`${supabaseUrl}/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
    method: "DELETE",
    headers: serviceHeaders(serviceRoleKey),
  });

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
