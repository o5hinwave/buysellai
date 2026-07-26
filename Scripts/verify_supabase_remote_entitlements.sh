#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_path="${M10_CONFIG_PLIST:-$repo_root/BuySellAI/App/Config.plist}"
required_migrations=(
    20260724233029
    20260726132434
    20260726134945
)

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

plist_value() {
    local key="$1"

    if [[ -x /usr/libexec/PlistBuddy && -f "$config_path" ]]; then
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

validate_config() {
    local raw_supabase_url="${SUPABASE_URL:-}"
    local anon_key="${SUPABASE_ANON_KEY:-}"
    local config_output

    if [[ -z "$raw_supabase_url" ]]; then
        raw_supabase_url="$(plist_value SUPABASE_URL | trim_value)"
    fi
    if [[ -z "$anon_key" ]]; then
        anon_key="$(plist_value SUPABASE_ANON_KEY | trim_value)"
    fi

    [[ -n "$raw_supabase_url" ]] || fail "SUPABASE_URL is required"
    [[ -n "$anon_key" ]] || fail "SUPABASE_ANON_KEY is required"

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
if parts[0] == "project-ref":
    raise SystemExit("SUPABASE_URL still contains the placeholder project-ref")
if anon_key == "public-anon-key":
    raise SystemExit("SUPABASE_ANON_KEY still contains the placeholder public-anon-key")
if provider_secret.search(url_value):
    raise SystemExit("SUPABASE_URL contains a provider/server-secret-shaped value")
if provider_secret.search(anon_key):
    raise SystemExit("SUPABASE_ANON_KEY looks like a provider/server-secret-shaped value")

print(f"https://{host}")
PY
)" || fail "invalid Supabase remote entitlement config"
    supabase_url="$(printf '%s\n' "$config_output" | sed -n '1p')"
    [[ -n "$supabase_url" ]] || fail "invalid Supabase remote entitlement config"
    supabase_anon_key="$anon_key"
}

command -v python3 >/dev/null 2>&1 || fail "python3 is required"
command -v curl >/dev/null 2>&1 || fail "curl is required"

supabase_url=""
supabase_anon_key=""
validate_config

health_json="$(
    curl -sS --show-error --fail-with-body --max-time "${M10_SUPABASE_HEALTH_TIMEOUT_SECONDS:-20}" \
        -X POST \
        -H "apikey: ${supabase_anon_key}" \
        -H "authorization: Bearer ${supabase_anon_key}" \
        -H "content-type: application/json" \
        --data '{}' \
        "${supabase_url}/functions/v1/backend-health"
)"

HEALTH_JSON="$health_json" EXPECTED_MIGRATIONS="${required_migrations[*]}" python3 <<'PY'
import json
import os

payload = json.loads(os.environ["HEALTH_JSON"])
if payload.get("ok") is not True:
    raise SystemExit("backend-health did not return ok=true")
if payload.get("service") != "buysell-backend":
    raise SystemExit("backend-health returned the wrong service name")

entitlement = payload.get("entitlement")
if not isinstance(entitlement, dict):
    raise SystemExit("backend-health did not return an entitlement object")

expected = {
    "config_key": "global",
    "entitlement_state": "earlyAccess",
    "complete_feature_access": True,
    "future_paid_access_enabled": False,
    "daily_analysis_limit": 18,
    "daily_ai_action_limit": 54,
}
for key, expected_value in expected.items():
    actual_value = entitlement.get(key)
    if actual_value != expected_value:
        raise SystemExit(f"entitlement.{key} expected {expected_value!r}, found {actual_value!r}")

actual_migrations = payload.get("requiredMigrations")
if not isinstance(actual_migrations, list):
    raise SystemExit("backend-health did not return requiredMigrations")
actual_versions = {str(version) for version in actual_migrations}
expected_versions = set(os.environ["EXPECTED_MIGRATIONS"].split())
missing = sorted(expected_versions.difference(actual_versions))
if missing:
    raise SystemExit("backend-health requiredMigrations missing: " + ", ".join(missing))

monitoring = payload.get("usageMonitoring")
if not isinstance(monitoring, dict):
    raise SystemExit("backend-health did not return usageMonitoring")

if monitoring.get("windowHours") != 24:
    raise SystemExit("usageMonitoring.windowHours expected 24")
if monitoring.get("status") not in {"normal", "watch", "limit"}:
    raise SystemExit("usageMonitoring.status was not recognized")

for key in (
    "eventCount",
    "analysisCount",
    "marketplaceResearchCount",
    "listingGenerationCount",
    "estimatedAiCostCents",
    "groundedSearchCount",
):
    value = monitoring.get(key)
    if not isinstance(value, (int, float)) or value < 0:
        raise SystemExit(f"usageMonitoring.{key} must be a non-negative number")

thresholds = monitoring.get("thresholds")
if not isinstance(thresholds, dict):
    raise SystemExit("usageMonitoring did not return thresholds")
expected_thresholds = {
    "dailyEventLimit": 200,
    "dailyEstimatedAiCostCentsLimit": 500,
    "dailyGroundedSearchLimit": 250,
    "sampleLimit": 1000,
}
for key, expected_value in expected_thresholds.items():
    if thresholds.get(key) != expected_value:
        raise SystemExit(f"usageMonitoring.thresholds.{key} expected {expected_value!r}")

alerts = monitoring.get("alerts")
if not isinstance(alerts, list) or not all(isinstance(alert, str) for alert in alerts):
    raise SystemExit("usageMonitoring.alerts must be a string array")

print("Supabase remote entitlement check passed")
print("project state: earlyAccess full-access no-paid-access")
print("limits: 18 analyses/day 54 AI-actions/day")
print(
    "usage monitor: "
    f"{monitoring['status']} "
    f"{monitoring['eventCount']} events "
    f"{monitoring['estimatedAiCostCents']} AI-cents "
    f"{monitoring['groundedSearchCount']} grounded-searches/24h"
)
print("migrations: " + " ".join(sorted(expected_versions)))
PY
