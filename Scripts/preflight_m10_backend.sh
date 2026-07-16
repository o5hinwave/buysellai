#!/usr/bin/env bash
set -euo pipefail

config_path="${1:-${M10_CONFIG_PLIST:-BuySellAI/App/Config.plist}}"
allow_missing="${ALLOW_MISSING_BACKEND:-0}"
timeout_seconds="${M10_BACKEND_TIMEOUT:-30}"
provider_secret_pattern='AQ\.[0-9A-Za-z_-]{20,}|AIza[0-9A-Za-z_-]{20,}|sk-[0-9A-Za-z_-]{20,}'
pending_items=()

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

pending() {
    pending_items+=("$*")
}

print_pending_and_exit() {
    printf 'M10 backend preflight pending:\n'
    printf ' - %s\n' "${pending_items[@]}"
    printf 'Complete real Supabase config, deployed Edge Functions, and an analyze sample image, then rerun without ALLOW_MISSING_BACKEND=1.\n'
    exit 0
}

pending_or_fail() {
    if [[ "$allow_missing" == "1" ]]; then
        pending "$*"
        return
    fi

    fail "$*"
}

plist_value() {
    local key="$1"

    /usr/libexec/PlistBuddy -c "Print :${key}" "$config_path" 2>/dev/null || true
}

json_string() {
    python3 -c 'import json, sys; print(json.dumps(sys.argv[1]))' "$1"
}

validate_analyze_response() {
    local response_file="$1"

    python3 - "$response_file" <<'PY'
import json
import sys
from decimal import Decimal, InvalidOperation

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)

missing = [
    key for key in ("name", "category", "condition", "currentPrice")
    if key not in data or data[key] in ("", None)
]
if missing:
    raise SystemExit("missing analyze fields: " + ", ".join(missing))

try:
    price = Decimal(str(data["currentPrice"]))
except (InvalidOperation, ValueError):
    raise SystemExit("currentPrice is not numeric")

if price <= 0:
    raise SystemExit("currentPrice must be greater than zero")

print(str(data["name"]).strip())
PY
}

validate_listing_response() {
    local response_file="$1"

    python3 - "$response_file" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)

listing = data.get("listing")
if not isinstance(listing, str) or not listing.strip():
    raise SystemExit("listing is missing or blank")

print(len(listing.encode("utf-8")))
PY
}

call_function() {
    local label="$1"
    local url="$2"
    local payload_file="$3"
    local response_file="$4"
    local curl_output
    local status
    local body

    if ! curl_output="$(
        curl -sS --show-error --max-time "$timeout_seconds" \
            -X POST "$url" \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -H "apikey: $anon_key" \
            --data-binary "@${payload_file}" \
            -w '\n%{http_code}' \
            2>&1
    )"; then
        fail "$label request failed"
    fi

    status="${curl_output##*$'\n'}"
    body="${curl_output%$'\n'$status}"

    if [[ ! "$status" =~ ^2[0-9][0-9]$ ]]; then
        fail "$label returned HTTP $status"
    fi

    printf '%s' "$body" > "$response_file"
}

command -v curl >/dev/null 2>&1 || fail "curl is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"

if [[ ! -f "$config_path" ]]; then
    pending_or_fail "Config.plist is missing at $config_path"
    print_pending_and_exit
fi

supabase_url="$(plist_value SUPABASE_URL)"
anon_key="$(plist_value SUPABASE_ANON_KEY)"

[[ -n "$supabase_url" ]] || pending_or_fail "SUPABASE_URL is missing from $config_path"
[[ -n "$anon_key" ]] || pending_or_fail "SUPABASE_ANON_KEY is missing from $config_path"

if (( ${#pending_items[@]} > 0 )); then
    print_pending_and_exit
fi

supabase_url="${supabase_url%/}"

[[ "$supabase_url" =~ ^https://[a-z0-9-]+\.supabase\.co$ ]] || fail "SUPABASE_URL must be a root https://<project>.supabase.co URL"
[[ "$anon_key" =~ $provider_secret_pattern ]] && fail "SUPABASE_ANON_KEY looks like an AI provider secret"
[[ "$supabase_url" =~ $provider_secret_pattern ]] && fail "SUPABASE_URL contains a provider secret-shaped value"

if [[ -n "${M10_ANALYZE_IMAGE_DATA_URL:-}" ]]; then
    analyze_image_data_url="$M10_ANALYZE_IMAGE_DATA_URL"
elif [[ -n "${M10_ANALYZE_IMAGE_JPEG:-}" ]]; then
    [[ -f "$M10_ANALYZE_IMAGE_JPEG" ]] || fail "M10_ANALYZE_IMAGE_JPEG does not exist at $M10_ANALYZE_IMAGE_JPEG"
    analyze_image_data_url="data:image/jpeg;base64,$(base64 < "$M10_ANALYZE_IMAGE_JPEG" | tr -d '\n')"
else
    pending_or_fail "M10_ANALYZE_IMAGE_JPEG or M10_ANALYZE_IMAGE_DATA_URL is unset"
    print_pending_and_exit
fi

[[ "$analyze_image_data_url" == data:image/jpeg\;base64,* ]] || fail "analyze sample must be a JPEG data URL"

functions_base="${supabase_url}/functions/v1"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/buysell-backend-preflight.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

printf '{"imageDataUrl":%s}\n' "$(json_string "$analyze_image_data_url")" > "$work_dir/analyze-payload.json"
cat > "$work_dir/listing-payload.json" <<'JSON'
{
  "item": {
    "name": "Vintage brass table lamp",
    "category": "Home",
    "condition": "good",
    "originalPrice": 45,
    "currentPrice": 45
  },
  "platform": "ebay"
}
JSON

call_function "analyze-image" "${functions_base}/analyze-image" "$work_dir/analyze-payload.json" "$work_dir/analyze-response.json"
call_function "generate-listing" "${functions_base}/generate-listing" "$work_dir/listing-payload.json" "$work_dir/listing-response.json"

analyze_item="$(validate_analyze_response "$work_dir/analyze-response.json")" || fail "analyze-image response shape is invalid"
listing_bytes="$(validate_listing_response "$work_dir/listing-response.json")" || fail "generate-listing response shape is invalid"

printf 'M10 backend preflight passed\n'
printf 'config: %s\n' "$config_path"
printf 'project: %s\n' "$supabase_url"
printf 'functions: analyze-image generate-listing\n'
printf 'analyze item: %s\n' "$analyze_item"
printf 'listing bytes: %s\n' "$listing_bytes"
