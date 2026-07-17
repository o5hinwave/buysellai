export const jsonHeaders = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
};

export const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...jsonHeaders, ...corsHeaders },
  });
}

export function emptyResponse(status = 204): Response {
  return new Response(null, {
    status,
    headers: { ...corsHeaders, "cache-control": "no-store" },
  });
}

export function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ error: message }, status);
}

export async function readJson(request: Request): Promise<Record<string, unknown>> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    throw new HttpError("Expected application/json", 415);
  }

  const body = await request.json();
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    throw new HttpError("Expected JSON object", 400);
  }

  return body as Record<string, unknown>;
}

export class HttpError extends Error {
  constructor(message: string, public readonly status = 400) {
    super(message);
  }
}

export function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new HttpError(`Missing ${name}`, 500);
  }
  return value;
}

export function handleOptions(request: Request): Response | null {
  if (request.method === "OPTIONS") {
    return emptyResponse(204);
  }
  return null;
}

export function requirePost(request: Request): void {
  if (request.method !== "POST") {
    throw new HttpError("Method not allowed", 405);
  }
}
