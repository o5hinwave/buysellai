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

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    throw new HttpError("Expected valid JSON", 400);
  }

  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    throw new HttpError("Expected JSON object", 400);
  }

  return body as Record<string, unknown>;
}

export async function readResponseJson(response: Response, message: string): Promise<unknown> {
  try {
    return await response.json();
  } catch {
    throw new HttpError(message, 502);
  }
}

export function requireJsonObject(value: unknown, message: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError(message, 502);
  }
  return value as Record<string, unknown>;
}

export function requireJsonArray(value: unknown, message: string): unknown[] {
  if (!Array.isArray(value)) {
    throw new HttpError(message, 502);
  }
  return value;
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

type TimedFetchOptions = {
  timeoutMs?: number;
  timeoutMessage?: string;
  transportMessage?: string;
  timeoutStatus?: number;
  transportStatus?: number;
};

export async function fetchWithTimeout(
  input: string | URL | Request,
  init: RequestInit = {},
  options: TimedFetchOptions = {},
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), options.timeoutMs ?? 8_000);

  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new HttpError(options.timeoutMessage ?? "Request timed out", options.timeoutStatus ?? 504);
    }
    throw new HttpError(options.transportMessage ?? "Request failed", options.transportStatus ?? 502);
  } finally {
    clearTimeout(timeout);
  }
}

export function timeoutFromEnv(name: string, defaultMs: number, minMs = 1_000, maxMs = 30_000): number {
  const raw = Deno.env.get(name)?.trim();
  if (!raw) return defaultMs;

  const parsed = Number(raw);
  if (!Number.isFinite(parsed) || parsed < minMs || parsed > maxMs) {
    throw new HttpError(`Invalid ${name}`, 500);
  }
  return parsed;
}
