#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-preflight}"
config_path="${M10_CONFIG_PLIST:-$repo_root/BuySellAI/App/Config.plist}"
allow_missing="${ALLOW_MISSING_SUPABASE_DEPLOY:-0}"
linked_ref_file="$repo_root/supabase/.temp/project-ref"
functions=(analyze-image compare-marketplaces generate-listing store-apple-token delete-account)
required_secrets=(GEMINI_API_KEY SUPABASE_SERVICE_ROLE_KEY APPLE_TEAM_ID APPLE_KEY_ID APPLE_CLIENT_ID APPLE_PRIVATE_KEY)
pending_items=()
supabase_url=""
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
  bash Scripts/deploy_supabase_backend.sh preflight
  CONFIRM_SUPABASE_DEPLOY=<project-ref> bash Scripts/deploy_supabase_backend.sh deploy

Preflight checks the local Supabase config, linked project, required server-side
secret names, migrations, and Edge Function sources without printing secret
values. Deploy applies the migration and deploys all BuySell Edge Functions.
Use Scripts/setup_supabase_config.sh and Scripts/setup_supabase_secrets.sh full
before deploy mode.
USAGE
}

pending() {
    pending_items+=("$*")
}

pending_or_fail() {
    if [[ "$allow_missing" == "1" ]]; then
        pending "$*"
        return 0
    fi

    fail "$*"
}

print_pending_and_exit() {
    printf 'M10 Supabase deploy preflight pending:\n'
    printf ' - %s\n' "${pending_items[@]}"
    if [[ -n "$supabase_url" && -n "$project_ref" ]]; then
        printf 'config: %s\n' "${config_path#$repo_root/}"
        printf 'project: %s\n' "$supabase_url"
        printf 'project ref: %s\n' "$project_ref"
        printf 'schema: history apple_auth_tokens marketplace_research_cache entitlement_config entitlement_usage_events\n'
        printf 'constraints: history category condition marketplace listing metadata identification-profile marketplace-comparison supplemental-photos apple-token-identity marketplace-research-cache early-access-entitlements usage-protection\n'
        printf 'functions: %s\n' "${functions[*]}"
    fi
    printf 'Complete app config, Supabase CLI login/link, server-side secrets, and then rerun without ALLOW_MISSING_SUPABASE_DEPLOY=1.\n'
    exit 0
}

plist_value() {
    local key="$1"

    if [[ -x /usr/libexec/PlistBuddy ]]; then
        /usr/libexec/PlistBuddy -c "Print :${key}" "$config_path" 2>/dev/null || true
        return 0
    fi

    CONFIG_INPUT_PATH="$config_path" CONFIG_INPUT_KEY="$key" python3 <<'PY' 2>/dev/null || true
import os
import plistlib

with open(os.environ["CONFIG_INPUT_PATH"], "rb") as handle:
    data = plistlib.load(handle)

value = data.get(os.environ["CONFIG_INPUT_KEY"], "")
if isinstance(value, str):
    print(value)
PY
}

trim_value() {
    python3 -c 'import sys; print(sys.stdin.read().strip(), end="")'
}

run_secret_list_with_timeout() {
    local project_ref="$1"
    local output_path="$2"
    local elapsed=0
    local pid
    local status=0

    [[ "$secret_list_timeout" =~ ^[0-9]+$ && "$secret_list_timeout" -gt 0 ]] || fail "M10_SUPABASE_SECRET_LIST_TIMEOUT_SECONDS must be a positive integer"

    supabase secrets list --project-ref "$project_ref" --output json > "$output_path" 2>/dev/null &
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

validate_config() {
    local raw_supabase_url
    local anon_key
    local config_output

    if [[ ! -f "$config_path" ]]; then
        pending_or_fail "Config.plist is missing at ${config_path#$repo_root/}"
        return 0
    fi

    raw_supabase_url="$(plist_value SUPABASE_URL | trim_value)"
    anon_key="$(plist_value SUPABASE_ANON_KEY | trim_value)"
    [[ -n "$raw_supabase_url" ]] || pending_or_fail "SUPABASE_URL is missing from ${config_path#$repo_root/}"
    [[ -n "$anon_key" ]] || pending_or_fail "SUPABASE_ANON_KEY is missing from ${config_path#$repo_root/}"
    if (( ${#pending_items[@]} > 0 )); then
        return 0
    fi

    config_output="$(SUPABASE_URL_VALUE="$raw_supabase_url" SUPABASE_ANON_KEY_VALUE="$anon_key" python3 <<'PY'
import os
import re
from urllib.parse import urlparse

provider_secret = re.compile(r"AQ\.[0-9A-Za-z_-]{20,}|AIza[0-9A-Za-z_-]{20,}|sk-[0-9A-Za-z_-]{20,}|sb_secret_[0-9A-Za-z_-]{20,}")
url_value = os.environ["SUPABASE_URL_VALUE"].strip()
anon_key = os.environ["SUPABASE_ANON_KEY_VALUE"].strip()
parsed = urlparse(url_value)

try:
    port = parsed.port
except ValueError:
    raise SystemExit("SUPABASE_URL must not include a port")

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
    raise SystemExit("SUPABASE_URL must be a root https://<project>.supabase.co URL")
parts = host.split(".")
if len(parts) != 3 or parts[1:] != ["supabase", "co"] or not re.fullmatch(r"[a-z0-9-]+", parts[0]):
    raise SystemExit("SUPABASE_URL must be a root https://<project>.supabase.co URL")
if host == "project-ref.supabase.co":
    raise SystemExit("SUPABASE_URL still contains the Config.plist.example placeholder")
if anon_key == "public-anon-key":
    raise SystemExit("SUPABASE_ANON_KEY still contains the Config.plist.example placeholder")
if not anon_key:
    raise SystemExit("SUPABASE_ANON_KEY is required")
if provider_secret.search(url_value):
    raise SystemExit("SUPABASE_URL contains a provider/server-secret-shaped value")
if provider_secret.search(anon_key):
    raise SystemExit("SUPABASE_ANON_KEY looks like a provider/server-secret-shaped value")

print(f"https://{host}")
print(parts[0])
PY
)" || fail "invalid Supabase app config"
    supabase_url="$(printf '%s\n' "$config_output" | sed -n '1p')"
    project_ref="$(printf '%s\n' "$config_output" | sed -n '2p')"
    [[ -n "$supabase_url" && -n "$project_ref" ]] || fail "invalid Supabase app config"
}

require_source_files() {
    local path

    [[ -f "$repo_root/supabase/config.toml" ]] || fail "supabase/config.toml is missing"
    for path in \
        "$repo_root/supabase/migrations/20260717000100_create_remote_history_and_apple_auth_tokens.sql" \
        "$repo_root/supabase/migrations/20260718000100_harden_history_constraints.sql" \
        "$repo_root/supabase/migrations/20260718000200_harden_apple_auth_token_identity.sql" \
        "$repo_root/supabase/migrations/20260722000100_create_marketplace_research_cache.sql" \
        "$repo_root/supabase/migrations/20260724233029_early_access_entitlements.sql" \
        "$repo_root/supabase/migrations/20260725001000_add_history_listing_metadata.sql" \
        "$repo_root/supabase/migrations/20260725141629_add_history_identification_profile.sql" \
        "$repo_root/supabase/migrations/20260726045209_add_history_marketplace_comparison.sql" \
        "$repo_root/supabase/migrations/20260726051236_add_history_supplemental_photos.sql" \
        "$repo_root/supabase/migrations/20260726092634_raise_early_access_usage_limits.sql" \
        "$repo_root/supabase/functions/analyze-image/index.ts" \
        "$repo_root/supabase/functions/compare-marketplaces/index.ts" \
        "$repo_root/supabase/functions/generate-listing/index.ts" \
        "$repo_root/supabase/functions/store-apple-token/index.ts" \
        "$repo_root/supabase/functions/delete-account/index.ts"
    do
        [[ -f "$path" ]] || fail "${path#$repo_root/} is missing"
    done
}

require_linked_project() {
    local expected_ref="$1"
    local linked_ref

    if [[ ! -f "$linked_ref_file" ]]; then
        pending_or_fail "Supabase project is not linked; run supabase link --project-ref $expected_ref"
        return 0
    fi

    linked_ref="$(trim_value < "$linked_ref_file")"
    if [[ "$linked_ref" != "$expected_ref" ]]; then
        fail "linked Supabase project '$linked_ref' does not match Config.plist project '$expected_ref'"
    fi
}

require_secret_names() {
    local project_ref="$1"
    local secrets_file

    secrets_file="$(mktemp "${TMPDIR:-/tmp}/buysell-supabase-secrets-list.XXXXXX")"
    trap 'rm -f "$secrets_file"' RETURN

    if ! run_secret_list_with_timeout "$project_ref" "$secrets_file"; then
        pending_or_fail "Supabase secret names could not be listed within ${secret_list_timeout}s; run supabase login and Scripts/setup_supabase_secrets.sh full"
        return 0
    fi

    python3 - "$secrets_file" "${required_secrets[@]}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)

names = set()
if isinstance(data, list):
    for item in data:
        if isinstance(item, dict):
            for key in ("name", "Name", "key", "Key"):
                value = item.get(key)
                if isinstance(value, str):
                    names.add(value)
elif isinstance(data, dict):
    for key in ("secrets", "data"):
        value = data.get(key)
        if isinstance(value, list):
            for item in value:
                if isinstance(item, dict):
                    for name_key in ("name", "Name", "key", "Key"):
                        name_value = item.get(name_key)
                        if isinstance(name_value, str):
                            names.add(name_value)

missing = [secret for secret in sys.argv[2:] if secret not in names]
if missing:
    raise SystemExit("missing Supabase secrets: " + ", ".join(missing))
PY
}

run_deno_check() {
    bash "$repo_root/Scripts/check_supabase_functions.sh"
}

run_schema_check() {
    bash "$repo_root/Scripts/check_supabase_schema.sh"
}

run_deploy() {
    local project_ref="$1"
    local function_name

    if [[ "${CONFIRM_SUPABASE_DEPLOY:-}" != "$project_ref" ]]; then
        fail "set CONFIRM_SUPABASE_DEPLOY=$project_ref to deploy to this Supabase project"
    fi

    supabase db push --linked --yes
    for function_name in "${functions[@]}"; do
        supabase functions deploy "$function_name" --project-ref "$project_ref" --use-api
    done
}

case "$mode" in
    preflight|deploy)
        ;;
    -h|--help|help)
        usage
        exit 0
        ;;
    *)
        fail "unknown mode '$mode'"
        ;;
esac

command -v python3 >/dev/null 2>&1 || fail "python3 is required"

require_source_files
run_schema_check
validate_config

if ! command -v supabase >/dev/null 2>&1; then
    pending_or_fail "Supabase CLI is required; install it, run supabase login, and link the project"
fi

if (( ${#pending_items[@]} == 0 )); then
    require_linked_project "$project_ref"
fi

if (( ${#pending_items[@]} == 0 )); then
    run_deno_check
    require_secret_names "$project_ref"
fi

if (( ${#pending_items[@]} > 0 )); then
    print_pending_and_exit
fi

if [[ "$mode" == "deploy" ]]; then
    run_deploy "$project_ref"
    printf 'M10 Supabase deploy passed\n'
else
    printf 'M10 Supabase deploy preflight passed\n'
fi
printf 'config: %s\n' "${config_path#$repo_root/}"
printf 'project: %s\n' "$supabase_url"
printf 'project ref: %s\n' "$project_ref"
printf 'schema: history apple_auth_tokens marketplace_research_cache entitlement_config entitlement_usage_events\n'
printf 'constraints: history category condition marketplace listing metadata identification-profile marketplace-comparison supplemental-photos apple-token-identity marketplace-research-cache early-access-entitlements usage-protection\n'
printf 'functions: %s\n' "${functions[*]}"
printf 'secrets: required names present\n'
