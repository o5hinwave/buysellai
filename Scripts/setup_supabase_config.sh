#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_path="${CONFIG_PATH:-$repo_root/BuySellAI/App/Config.plist}"
provider_secret_pattern='AQ\.[0-9A-Za-z_-]{20,}|AIza[0-9A-Za-z_-]{20,}|sk-[0-9A-Za-z_-]{20,}|sb_secret_[0-9A-Za-z_-]{20,}'
tmp_config=""

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'USAGE'
Usage:
  bash Scripts/setup_supabase_config.sh

Prompts for the public Supabase project URL and public anon/publishable key used by the iOS app,
then writes BuySellAI/App/Config.plist with only SUPABASE_URL and
SUPABASE_ANON_KEY. Provider and server-side Supabase secrets belong in
Supabase Edge Function secrets, not in the app bundle.

Set CONFIG_PATH=/path/to/Config.plist to write somewhere else.
For CI, set SUPABASE_CONFIG_FROM_ENV=1 plus SUPABASE_URL and
SUPABASE_ANON_KEY so missing values fail fast instead of prompting.
USAGE
}

cleanup() {
    if [[ -n "$tmp_config" && -f "$tmp_config" ]]; then
        rm -f "$tmp_config"
    fi
    unset SUPABASE_URL_VALUE SUPABASE_ANON_KEY_VALUE supabase_url anon_key normalized_url
}

trim_value() {
    python3 -c 'import sys; print(sys.stdin.read().strip(), end="")'
}

read_required() {
    local prompt="$1"
    local variable_name="$2"
    local value

    read -r -p "$prompt" value
    value="$(printf '%s' "$value" | trim_value)"
    [[ -n "$value" ]] || fail "$variable_name is required"
    printf -v "$variable_name" '%s' "$value"
}

read_required_or_env() {
    local prompt="$1"
    local variable_name="$2"
    local env_name="$3"
    local value="${!env_name:-}"

    if [[ -n "$value" ]]; then
        value="$(printf '%s' "$value" | trim_value)"
        [[ -n "$value" ]] || fail "$env_name is required"
        printf -v "$variable_name" '%s' "$value"
        return
    fi

    if [[ "${SUPABASE_CONFIG_FROM_ENV:-0}" == "1" ]]; then
        fail "$env_name is required in environment when SUPABASE_CONFIG_FROM_ENV=1"
    fi

    read_required "$prompt" "$variable_name"
}

validate_public_config() {
    SUPABASE_URL_VALUE="$supabase_url" SUPABASE_ANON_KEY_VALUE="$anon_key" python3 <<'PY'
import os
import re
from urllib.parse import urlparse

provider_secret = re.compile(r"AQ\.[0-9A-Za-z_-]{20,}|AIza[0-9A-Za-z_-]{20,}|sk-[0-9A-Za-z_-]{20,}|sb_secret_[0-9A-Za-z_-]{20,}")
url_value = os.environ["SUPABASE_URL_VALUE"].strip()
anon_key = os.environ["SUPABASE_ANON_KEY_VALUE"].strip()


def fail(message):
    raise SystemExit(message)


if provider_secret.search(url_value):
    fail("SUPABASE_URL contains a provider/server-secret-shaped value")
if provider_secret.search(anon_key):
    fail("SUPABASE_ANON_KEY looks like a provider/server-secret-shaped value")
if not anon_key:
    fail("SUPABASE_ANON_KEY is required")
if anon_key == "public-anon-key":
    fail("SUPABASE_ANON_KEY still contains the Config.plist.example placeholder")

parsed = urlparse(url_value)
try:
    port = parsed.port
except ValueError:
    fail("SUPABASE_URL must not include a port")

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
    fail("SUPABASE_URL must be a root https://<project>.supabase.co URL")

parts = host.split(".")
if len(parts) != 3 or parts[1:] != ["supabase", "co"] or not re.fullmatch(r"[a-z0-9-]+", parts[0]):
    fail("SUPABASE_URL must be a root https://<project>.supabase.co URL")
if host == "project-ref.supabase.co":
    fail("SUPABASE_URL still contains the Config.plist.example placeholder")

print(f"https://{host}")
PY
}

case "${1:-}" in
    "")
        ;;
    -h|--help|help)
        usage
        exit 0
        ;;
    *)
        fail "unknown argument '$1'"
        ;;
esac

command -v python3 >/dev/null 2>&1 || fail "python3 is required"
[[ -x /usr/libexec/PlistBuddy ]] || fail "PlistBuddy is required"

read_required_or_env "Supabase project URL: " supabase_url SUPABASE_URL
read_required_or_env "Supabase anon key: " anon_key SUPABASE_ANON_KEY
normalized_url="$(validate_public_config)" || fail "invalid Supabase app config"

config_dir="$(dirname "$config_path")"
mkdir -p "$config_dir"

trap cleanup EXIT
tmp_config="$(mktemp "$config_dir/Config.plist.XXXXXX")"
rm -f "$tmp_config"
/usr/libexec/PlistBuddy -c "Clear dict" "$tmp_config" >/dev/null 2>&1
/usr/libexec/PlistBuddy -c "Add :SUPABASE_URL string $normalized_url" "$tmp_config" >/dev/null
/usr/libexec/PlistBuddy -c "Add :SUPABASE_ANON_KEY string $anon_key" "$tmp_config" >/dev/null
chmod 600 "$tmp_config"
mv "$tmp_config" "$config_path"
chmod 600 "$config_path"
tmp_config=""

printf 'Supabase app config written\n'
printf 'config: %s\n' "${config_path#$repo_root/}"
printf 'project: %s\n' "$normalized_url"
printf 'keys: SUPABASE_URL SUPABASE_ANON_KEY\n'
