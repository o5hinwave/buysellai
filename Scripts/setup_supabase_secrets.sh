#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-full}"
secret_file=""

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'USAGE'
Usage:
  bash Scripts/setup_supabase_secrets.sh [full|gemini-only]

Prompts for server-side Supabase Edge Function secrets, writes them to a
0600 temporary env file outside the repository, runs `supabase secrets set`,
then removes the temporary file. Never put Gemini, service-role, or Apple
private-key material in BuySellAI/App/Config.plist.

For CI, set SUPABASE_SECRETS_FROM_ENV=1 and provide the required secret
environment variables. In full mode this includes APPLE_PRIVATE_KEY_PATH,
which must point to a .p8 file outside the repository.
USAGE
}

cleanup() {
    if [[ -n "$secret_file" && -f "$secret_file" ]]; then
        rm -f "$secret_file"
    fi
    unset GEMINI_API_KEY SUPABASE_SERVICE_ROLE_KEY APPLE_TEAM_ID APPLE_KEY_ID APPLE_CLIENT_ID APPLE_PRIVATE_KEY APPLE_PRIVATE_KEY_PATH
}

read_secret() {
    local prompt="$1"
    local variable_name="$2"
    local value

    read -r -s -p "$prompt" value
    printf '\n'
    [[ -n "$value" ]] || fail "$variable_name is required"
    printf -v "$variable_name" '%s' "$value"
}

read_secret_or_env() {
    local prompt="$1"
    local variable_name="$2"
    local value="${!variable_name:-}"

    if [[ -n "$value" ]]; then
        printf -v "$variable_name" '%s' "$value"
        return
    fi

    if [[ "${SUPABASE_SECRETS_FROM_ENV:-0}" == "1" ]]; then
        fail "$variable_name is required in environment when SUPABASE_SECRETS_FROM_ENV=1"
    fi

    read_secret "$prompt" "$variable_name"
}

read_required() {
    local prompt="$1"
    local variable_name="$2"
    local value

    read -r -p "$prompt" value
    [[ -n "$value" ]] || fail "$variable_name is required"
    printf -v "$variable_name" '%s' "$value"
}

read_required_or_env() {
    local prompt="$1"
    local variable_name="$2"
    local value="${!variable_name:-}"

    if [[ -n "$value" ]]; then
        printf -v "$variable_name" '%s' "$value"
        return
    fi

    if [[ "${SUPABASE_SECRETS_FROM_ENV:-0}" == "1" ]]; then
        fail "$variable_name is required in environment when SUPABASE_SECRETS_FROM_ENV=1"
    fi

    read_required "$prompt" "$variable_name"
}

write_secret() {
    local key="$1"
    local value="$2"

    printf '%s=%s\n' "$key" "$value" >> "$secret_file"
}

case "$mode" in
    full|gemini-only)
        ;;
    -h|--help|help)
        usage
        exit 0
        ;;
    *)
        fail "unknown mode '$mode'"
        ;;
esac

command -v supabase >/dev/null 2>&1 || fail "supabase CLI is required"

trap cleanup EXIT
secret_file="$(mktemp "${TMPDIR:-/tmp}/buysell-supabase-secrets.XXXXXX")"
chmod 600 "$secret_file"

case "$secret_file" in
    "$repo_root"/*)
        fail "temporary secret file must not be inside the repository"
        ;;
esac

read_secret_or_env "Gemini API key: " GEMINI_API_KEY
write_secret "GEMINI_API_KEY" "$GEMINI_API_KEY"

if [[ "$mode" == "full" ]]; then
    read_secret_or_env "Supabase service-role key: " SUPABASE_SERVICE_ROLE_KEY
    read_required_or_env "Apple Team ID: " APPLE_TEAM_ID
    read_required_or_env "Apple Key ID: " APPLE_KEY_ID
    read_required_or_env "Apple Client ID / bundle ID: " APPLE_CLIENT_ID
    read_required_or_env "Apple private key .p8 path: " APPLE_PRIVATE_KEY_PATH

    [[ -f "$APPLE_PRIVATE_KEY_PATH" ]] || fail "Apple private key file is missing"
    APPLE_PRIVATE_KEY="$(awk '{printf "%s\\n", $0}' "$APPLE_PRIVATE_KEY_PATH")"
    [[ -n "$APPLE_PRIVATE_KEY" ]] || fail "APPLE_PRIVATE_KEY is required"

    write_secret "SUPABASE_SERVICE_ROLE_KEY" "$SUPABASE_SERVICE_ROLE_KEY"
    write_secret "APPLE_TEAM_ID" "$APPLE_TEAM_ID"
    write_secret "APPLE_KEY_ID" "$APPLE_KEY_ID"
    write_secret "APPLE_CLIENT_ID" "$APPLE_CLIENT_ID"
    write_secret "APPLE_PRIVATE_KEY" "$APPLE_PRIVATE_KEY"
fi

supabase secrets set --env-file "$secret_file"

printf 'Supabase secrets set\n'
printf 'mode: %s\n' "$mode"
if [[ "$mode" == "full" ]]; then
    printf 'secrets: GEMINI_API_KEY SUPABASE_SERVICE_ROLE_KEY APPLE_TEAM_ID APPLE_KEY_ID APPLE_CLIENT_ID APPLE_PRIVATE_KEY\n'
else
    printf 'secrets: GEMINI_API_KEY\n'
fi
