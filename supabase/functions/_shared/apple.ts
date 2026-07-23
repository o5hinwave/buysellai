import {
  fetchWithTimeout,
  HttpError,
  readResponseJson,
  requireEnv,
  requireJsonObject,
  timeoutFromEnv,
} from "./http.ts";

export type AppleTokenExchange = {
  refreshToken: string;
  accessToken?: string;
  accessTokenExpiresAt?: string;
  identitySubject?: string;
};

export type AppleStoredToken = {
  refreshToken?: string | null;
  accessToken?: string | null;
};

type AppleTokenResponse = {
  access_token?: string;
  expires_in?: number;
  id_token?: string;
  refresh_token?: string;
  error?: string;
  error_description?: string;
};

export async function exchangeAppleAuthorizationCode(authorizationCode: string): Promise<AppleTokenExchange> {
  const params = new URLSearchParams({
    client_id: appleClientID(),
    client_secret: await appleClientSecret(),
    code: authorizationCode,
    grant_type: "authorization_code",
  });

  const response = await fetchWithTimeout("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: params,
  }, {
    timeoutMs: appleTimeoutMs(),
    timeoutMessage: "Apple authorization request timed out",
    transportMessage: "Apple authorization transport failed",
  });
  if (!response.ok) {
    throw new HttpError("Could not exchange Apple authorization code", 502);
  }
  const payload = requireJsonObject(
    await readResponseJson(response, "Apple token response was not valid JSON"),
    "Apple token response was not a JSON object",
  ) as AppleTokenResponse;
  if (typeof payload.refresh_token !== "string" || !payload.refresh_token) {
    throw new HttpError("Apple token response did not include a refresh token", 502);
  }

  return {
    refreshToken: payload.refresh_token,
    accessToken: payload.access_token,
    accessTokenExpiresAt: accessTokenExpiresAt(payload.expires_in),
    identitySubject: identitySubject(payload.id_token),
  };
}

export async function revokeAppleToken(token: AppleStoredToken): Promise<void> {
  const refreshToken = cleanToken(token.refreshToken);
  const accessToken = cleanToken(token.accessToken);
  const tokenToRevoke = refreshToken ?? accessToken;
  if (!tokenToRevoke) {
    throw new HttpError("Apple authorization token is missing", 502);
  }

  const params = new URLSearchParams({
    client_id: appleClientID(),
    client_secret: await appleClientSecret(),
    token: tokenToRevoke,
    token_type_hint: refreshToken ? "refresh_token" : "access_token",
  });

  const response = await fetchWithTimeout("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: params,
  }, {
    timeoutMs: appleTimeoutMs(),
    timeoutMessage: "Apple authorization request timed out",
    transportMessage: "Apple authorization transport failed",
  });
  if (!response.ok) {
    throw new HttpError("Could not revoke Apple authorization", 502);
  }
}

function appleClientID(): string {
  return requireEnv("APPLE_CLIENT_ID");
}

function appleTimeoutMs(): number {
  return timeoutFromEnv("APPLE_TIMEOUT_MS", 8_000);
}

async function appleClientSecret(): Promise<string> {
  const keyID = requireEnv("APPLE_KEY_ID");
  const teamID = requireEnv("APPLE_TEAM_ID");
  const clientID = appleClientID();
  const issuedAt = Math.floor(Date.now() / 1000);
  const expiresAt = issuedAt + 86_400;
  const header = base64urlJSON({ alg: "ES256", kid: keyID });
  const claims = base64urlJSON({
    aud: "https://appleid.apple.com",
    exp: expiresAt,
    iat: issuedAt,
    iss: teamID,
    sub: clientID,
  });
  const unsignedToken = `${header}.${claims}`;
  const privateKeyData = applePrivateKeyBytes();
  const key = await crypto.subtle.importKey(
    "pkcs8",
    privateKeyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  ).catch(() => {
    throw new HttpError("Invalid Apple private key", 500);
  });
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(unsignedToken),
  );
  return `${unsignedToken}.${base64url(new Uint8Array(signature))}`;
}

function accessTokenExpiresAt(expiresIn: number | undefined): string | undefined {
  if (typeof expiresIn !== "number" || Number.isFinite(expiresIn) == false || expiresIn <= 0) {
    return undefined;
  }
  return new Date(Date.now() + expiresIn * 1000).toISOString();
}

function identitySubject(idToken: string | undefined): string | undefined {
  if (!idToken) return undefined;
  const parts = idToken.split(".");
  if (parts.length < 2) return undefined;
  try {
    const payload = JSON.parse(new TextDecoder().decode(base64urlDecode(parts[1]))) as { sub?: unknown };
    return typeof payload.sub === "string" && payload.sub ? payload.sub : undefined;
  } catch {
    return undefined;
  }
}

function cleanToken(value: string | null | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

function applePrivateKeyBytes(): ArrayBuffer {
  try {
    return privateKeyBytes(requireEnv("APPLE_PRIVATE_KEY"));
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError("Invalid Apple private key", 500);
  }
}

function privateKeyBytes(pem: string): ArrayBuffer {
  const normalized = pem.replace(/\\n/g, "\n");
  const body = normalized
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const binary = atob(body);
  const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
  const buffer = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(buffer).set(bytes);
  return buffer;
}

function base64urlJSON(value: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(value)));
}

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64urlDecode(value: string): Uint8Array {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(value.length / 4) * 4, "=");
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}
