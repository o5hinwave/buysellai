#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
mode="${1:-full}"
config_path="${SUPABASE_CONFIG_PATH:-$repo_root/BuySellAI/App/Config.plist}"
linked_ref_file="$repo_root/supabase/.temp/project-ref"
secret_file=""
project_ref=""
secret_list_timeout="${M10_SUPABASE_SECRET_LIST_TIMEOUT_SECONDS:-30}"

export SUPABASE_TELEMETRY_DISABLED="${SUPABASE_TELEMETRY_DISABLED:-1}"

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'USAGE'
Usage:
  bash Scripts/setup_supabase_secrets.sh [preflight|full|gemini-only]

Prompts for server-side Supabase Edge Function secrets, writes them to a
0600 temporary env file outside the repository, runs `supabase secrets set`
against the resolved project ref, then removes the temporary file. Never put
Gemini, service-role, or Apple private-key material in
BuySellAI/App/Config.plist.

Preflight resolves the project and verifies Supabase CLI secret access before
any secret values are requested.

For CI, set SUPABASE_SECRETS_FROM_ENV=1 and provide the required secret
environment variables. In full mode this includes APPLE_PRIVATE_KEY_PATH,
which must point to a .p8 private-key file outside the repository.

Set SUPABASE_PROJECT_REF=<project-ref> to choose the target project without
requiring `supabase link`. If unset, the helper derives the ref from
BuySellAI/App/Config.plist, then falls back to supabase/.temp/project-ref.
USAGE
}

cleanup() {
    if [[ -n "$secret_file" && -f "$secret_file" ]]; then
        rm -f "$secret_file"
    fi
    unset GEMINI_API_KEY SUPABASE_SERVICE_ROLE_KEY APPLE_TEAM_ID APPLE_KEY_ID APPLE_CLIENT_ID APPLE_PRIVATE_KEY APPLE_PRIVATE_KEY_PATH SUPABASE_PROJECT_REF
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

validate_project_ref() {
    local ref="$1"

    [[ "$ref" =~ ^[a-z0-9-]+$ ]] || fail "SUPABASE_PROJECT_REF must contain only lowercase letters, numbers, and hyphens"
    [[ "$ref" != "project-ref" ]] || fail "SUPABASE_PROJECT_REF still contains the placeholder project-ref"
}

project_ref_from_config() {
    local url_value

    [[ -f "$config_path" ]] || return 1
    [[ -x /usr/libexec/PlistBuddy ]] || return 1

    url_value="$(/usr/libexec/PlistBuddy -c "Print :SUPABASE_URL" "$config_path" 2>/dev/null || true)"
    [[ -n "$url_value" ]] || return 1

    SUPABASE_URL_VALUE="$url_value" python3 <<'PY'
import os
import re
from urllib.parse import urlparse

url_value = os.environ["SUPABASE_URL_VALUE"].strip()
parsed = urlparse(url_value)

try:
    port = parsed.port
except ValueError:
    raise SystemExit(1)

host = parsed.hostname.lower() if parsed.hostname else ""
if (
    parsed.scheme != "https"
    or not host
    or parsed.username is not None
    or parsed.password is not None
    or port is not None
    or parsed.path not in ("", "/")
    or parsed.params
    or parsed.query
    or parsed.fragment
):
    raise SystemExit(1)

parts = host.split(".")
if len(parts) != 3 or parts[1:] != ["supabase", "co"] or not re.fullmatch(r"[a-z0-9-]+", parts[0]):
    raise SystemExit(1)
if parts[0] == "project-ref":
    raise SystemExit("BuySellAI/App/Config.plist still contains the placeholder Supabase project URL")

print(parts[0])
PY
}

resolve_project_ref() {
    local ref="${SUPABASE_PROJECT_REF:-}"

    if [[ -n "$ref" ]]; then
        ref="$(printf '%s' "$ref" | tr -d '[:space:]')"
        validate_project_ref "$ref"
        project_ref="$ref"
        return
    fi

    if [[ -f "$config_path" ]]; then
        if ref="$(project_ref_from_config)"; then
            validate_project_ref "$ref"
            project_ref="$ref"
            return
        fi

        fail "Supabase project ref could not be derived from ${config_path#$repo_root/}; set SUPABASE_PROJECT_REF=<project-ref> or rerun Scripts/setup_supabase_config.sh"
    fi

    if [[ -f "$linked_ref_file" ]]; then
        ref="$(tr -d '[:space:]' < "$linked_ref_file")"
        if [[ -n "$ref" ]]; then
            validate_project_ref "$ref"
            project_ref="$ref"
            return
        fi
    fi

    fail "SUPABASE_PROJECT_REF is required, or write BuySellAI/App/Config.plist with Scripts/setup_supabase_config.sh, or run supabase link --project-ref <project-ref>"
}

run_secret_list_with_timeout() {
    local output_path="$1"
    local elapsed=0
    local pid
    local status=0

    [[ "$secret_list_timeout" =~ ^[0-9]+$ && "$secret_list_timeout" -gt 0 ]] || fail "M10_SUPABASE_SECRET_LIST_TIMEOUT_SECONDS must be a positive integer"

    supabase secrets list --project-ref "$project_ref" --output-format json > "$output_path" 2>/dev/null &
    pid="$!"
    while kill -0 "$pid" 2>/dev/null; do
        if (( elapsed >= secret_list_timeout )); then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
            return 124
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    wait "$pid" || status="$?"
    return "$status"
}

require_secret_access() {
    local secrets_file

    secrets_file="$(mktemp "${TMPDIR:-/tmp}/buysell-supabase-secret-access.XXXXXX")"
    if ! run_secret_list_with_timeout "$secrets_file"; then
        rm -f "$secrets_file"
        fail "Supabase secret access unavailable within ${secret_list_timeout}s for project '$project_ref'; run supabase login and confirm the project before entering secrets"
    fi
    rm -f "$secrets_file"
}

validate_apple_private_key_path() {
    local raw_path="$1"
    local absolute_path

    [[ -n "$raw_path" ]] || fail "APPLE_PRIVATE_KEY_PATH is required"

    case "$raw_path" in
        *.p8)
            ;;
        *)
            fail "APPLE_PRIVATE_KEY_PATH must point to a .p8 file outside the repository"
            ;;
    esac

    absolute_path="$(
        APPLE_PRIVATE_KEY_PATH_VALUE="$raw_path" python3 <<'PY'
import os
from pathlib import Path

try:
    print(Path(os.environ["APPLE_PRIVATE_KEY_PATH_VALUE"]).expanduser().resolve(strict=True))
except OSError:
    raise SystemExit(1)
PY
    )" || fail "Apple private key file is missing"

    case "$absolute_path" in
        "$repo_root"/*)
            fail "APPLE_PRIVATE_KEY_PATH must not point inside the repository"
            ;;
    esac

    if ! grep -Fq "BEGIN PRIVATE KEY" "$absolute_path" || ! grep -Fq "END PRIVATE KEY" "$absolute_path"; then
        fail "APPLE_PRIVATE_KEY_PATH must point to a .p8 private-key file"
    fi

    APPLE_PRIVATE_KEY_PATH="$absolute_path"
}

case "$mode" in
    preflight|full|gemini-only)
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
command -v python3 >/dev/null 2>&1 || fail "python3 is required"

resolve_project_ref
require_secret_access

if [[ "$mode" == "preflight" ]]; then
    printf 'Supabase secret setup preflight passed\n'
    printf 'project ref: %s\n' "$project_ref"
    printf 'secret access: available\n'
    exit 0
fi

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
    read_required_or_env "Apple native client ID / bundle ID: " APPLE_CLIENT_ID
    read_required_or_env "Apple private key .p8 path: " APPLE_PRIVATE_KEY_PATH

    validate_apple_private_key_path "$APPLE_PRIVATE_KEY_PATH"
    APPLE_PRIVATE_KEY="$(awk '{printf "%s\\n", $0}' "$APPLE_PRIVATE_KEY_PATH")"
    [[ -n "$APPLE_PRIVATE_KEY" ]] || fail "APPLE_PRIVATE_KEY is required"

    write_secret "SUPABASE_SERVICE_ROLE_KEY" "$SUPABASE_SERVICE_ROLE_KEY"
    write_secret "APPLE_TEAM_ID" "$APPLE_TEAM_ID"
    write_secret "APPLE_KEY_ID" "$APPLE_KEY_ID"
    write_secret "APPLE_CLIENT_ID" "$APPLE_CLIENT_ID"
    write_secret "APPLE_PRIVATE_KEY" "$APPLE_PRIVATE_KEY"
fi

supabase secrets set --project-ref "$project_ref" --env-file "$secret_file"

printf 'Supabase secrets set\n'
printf 'mode: %s\n' "$mode"
printf 'project ref: %s\n' "$project_ref"
if [[ "$mode" == "full" ]]; then
    printf 'secrets: GEMINI_API_KEY SUPABASE_SERVICE_ROLE_KEY APPLE_TEAM_ID APPLE_KEY_ID APPLE_CLIENT_ID APPLE_PRIVATE_KEY\n'
else
    printf 'secrets: GEMINI_API_KEY\n'
fi
