#!/usr/bin/env bash
set -euo pipefail

config_path="${1:-${M10_CONFIG_PLIST:-BuySellAI/App/Config.plist}}"
allow_missing="${ALLOW_MISSING_BACKEND:-0}"
timeout_seconds="${M10_BACKEND_TIMEOUT:-30}"
provider_secret_pattern='AQ\.[0-9A-Za-z_-]{20,}|AIza[0-9A-Za-z_-]{20,}|sk-[0-9A-Za-z_-]{20,}|sb_secret_[0-9A-Za-z_-]{20,}'
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
    if [[ -n "${supabase_url:-}" ]]; then
        printf 'config: %s\n' "$config_path"
        printf 'project: %s\n' "$supabase_url"
        printf 'schema: history apple_auth_tokens marketplace_research_cache\n'
        printf 'functions: analyze-image compare-marketplaces generate-listing store-apple-token delete-account\n'
        printf 'protected functions: store-apple-token delete-account\n'
        printf 'protected tables: history apple_auth_tokens marketplace_research_cache\n'
    fi
    printf 'Complete real Supabase config, deployed schema migration, deployed Edge Functions including protected account functions, and an analyze sample image, then rerun without ALLOW_MISSING_BACKEND=1.\n'
    exit 0
}

pending_or_fail() {
    if [[ "$allow_missing" == "1" ]]; then
        pending "$*"
        return
    fi

    fail "$*"
}

external_or_fail() {
    if [[ "$allow_missing" == "1" ]]; then
        pending "$*"
        print_pending_and_exit
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

validate_compare_response() {
    local response_file="$1"

    python3 - "$response_file" <<'PY'
import json
import sys
from decimal import Decimal, InvalidOperation

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)

comparisons = data.get("comparisons")
if not isinstance(comparisons, list) or not comparisons:
    raise SystemExit("comparisons is missing or empty")

supported = {"ebay", "craigslist", "facebook", "mercari", "offerup", "poshmark"}
seen = set()
for row in comparisons:
    if not isinstance(row, dict):
        raise SystemExit("comparison row is not an object")
    marketplace = row.get("marketplace")
    if marketplace not in supported:
        raise SystemExit("unsupported marketplace in comparison response")
    if marketplace in seen:
        raise SystemExit("duplicate marketplace in comparison response")
    seen.add(marketplace)
    if not isinstance(row.get("reason"), str) or not row["reason"].strip():
        raise SystemExit("comparison reason is missing")
    status = row.get("evidenceStatus")
    if status not in ("grounded", "limited", "unavailable"):
        raise SystemExit("comparison evidenceStatus is invalid")
    for field in ("listPrice", "likelyRangeLow", "likelyRangeHigh", "takeHomeEstimate", "compLowPrice", "compMedianPrice", "compHighPrice"):
        if row.get(field) in (None, ""):
            continue
        try:
            value = Decimal(str(row[field]))
        except (InvalidOperation, ValueError):
            raise SystemExit(f"{field} is not numeric")
        if value <= 0:
            raise SystemExit(f"{field} must be greater than zero")
    sources = row.get("evidenceSources", [])
    if sources is not None and not isinstance(sources, list):
        raise SystemExit("evidenceSources is not an array")

print(len(comparisons))
PY
}

validate_listing_response() {
    local response_file="$1"

    python3 - "$response_file" <<'PY'
import json
import re
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)

listing = data.get("listing")
if not isinstance(listing, str) or not listing.strip():
    raise SystemExit("listing is missing or blank")
if "```" in listing:
    raise SystemExit("listing contains markdown fences")
preamble = listing.lstrip()[:96].lower().replace("\u2019", "'")
if re.search(r"^here(?:'s| is)\s+(?:your\s+)?listing\s*[:\-]", preamble):
    raise SystemExit("listing contains a generated preamble")
title_match = re.search(r"^TITLE\s*:", listing, re.IGNORECASE | re.MULTILINE)
if not title_match:
    raise SystemExit("listing is missing TITLE")
after_title = listing[title_match.end():]
description_match = re.search(r"^DESCRIPTION\s*:", after_title, re.IGNORECASE | re.MULTILINE)
if not description_match:
    raise SystemExit("listing is missing DESCRIPTION")
title_body = after_title[:description_match.start()].strip()
description_body = after_title[description_match.end():].strip()
if not title_body:
    raise SystemExit("listing has empty TITLE")
if not description_body:
    raise SystemExit("listing has empty DESCRIPTION")

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
        external_or_fail "$label request failed"
    fi

    status="${curl_output##*$'\n'}"
    body="${curl_output%$'\n'$status}"

    if [[ ! "$status" =~ ^2[0-9][0-9]$ ]]; then
        external_or_fail "$label returned HTTP $status"
    fi

    printf '%s' "$body" > "$response_file"
}

call_rejected_function() {
    local label="$1"
    local url="$2"
    local payload_file="$3"
    local expected_status="${4:-400}"
    local curl_output
    local status

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
        external_or_fail "$label rejection probe failed"
    fi

    status="${curl_output##*$'\n'}"
    if [[ "$status" == "$expected_status" ]]; then
        return 0
    fi
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
        fail "$label accepted invalid payload; expected HTTP $expected_status"
    fi
    external_or_fail "$label returned HTTP $status, expected $expected_status"
}

probe_protected_function() {
    local label="$1"
    local url="$2"
    local payload_file="$3"
    local curl_output
    local status

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
        external_or_fail "$label protected-function probe failed"
    fi

    status="${curl_output##*$'\n'}"

    case "$status" in
        401|403)
            return 0
            ;;
        404)
            external_or_fail "$label protected endpoint is not deployed"
            ;;
        2??)
            fail "$label accepted an anonymous request; expected JWT protection"
            ;;
        *)
            external_or_fail "$label protected-function probe returned HTTP $status, expected 401 or 403"
            ;;
    esac
}

probe_protected_table() {
    local label="$1"
    local url="$2"
    local curl_output
    local status

    if ! curl_output="$(
        curl -sS --show-error --max-time "$timeout_seconds" \
            -X GET "$url" \
            -H "Accept: application/json" \
            -H "apikey: $anon_key" \
            -H "Authorization: Bearer $anon_key" \
            -w '\n%{http_code}' \
            2>&1
    )"; then
        external_or_fail "$label protected-table probe failed"
    fi

    status="${curl_output##*$'\n'}"

    case "$status" in
        401|403)
            return 0
            ;;
        404)
            external_or_fail "$label protected table is not deployed"
            ;;
        2??)
            fail "$label accepted an anonymous read; expected RLS/grant protection"
            ;;
        *)
            external_or_fail "$label protected-table probe returned HTTP $status, expected 401 or 403"
            ;;
    esac
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
[[ "$supabase_url" == "https://project-ref.supabase.co" ]] && pending_or_fail "SUPABASE_URL still contains the Config.plist.example placeholder"
[[ "$anon_key" == "public-anon-key" ]] && pending_or_fail "SUPABASE_ANON_KEY still contains the Config.plist.example placeholder"
[[ "$anon_key" =~ $provider_secret_pattern ]] && fail "SUPABASE_ANON_KEY looks like a provider/server-secret-shaped value"
[[ "$supabase_url" =~ $provider_secret_pattern ]] && fail "SUPABASE_URL contains a provider/server-secret-shaped value"

if (( ${#pending_items[@]} > 0 )); then
    print_pending_and_exit
fi

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
rest_base="${supabase_url}/rest/v1"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/buysell-backend-preflight.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

printf '{"imageDataUrl":%s}\n' "$(json_string "$analyze_image_data_url")" > "$work_dir/analyze-payload.json"
printf '{}\n' > "$work_dir/invalid-analyze-missing-image-payload.json"
cat > "$work_dir/invalid-analyze-png-payload.json" <<'JSON'
{
  "imageDataUrl": "data:image/png;base64,AQID"
}
JSON
cat > "$work_dir/invalid-analyze-base64-payload.json" <<'JSON'
{
  "imageDataUrl": "data:image/jpeg;base64,not-base64"
}
JSON
cat > "$work_dir/invalid-analyze-jpeg-bytes-payload.json" <<'JSON'
{
  "imageDataUrl": "data:image/jpeg;base64,AQID"
}
JSON
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
cat > "$work_dir/compare-payload.json" <<'JSON'
{
  "item": {
    "name": "Vintage brass table lamp",
    "category": "Home",
    "condition": "good",
    "originalPrice": 45,
    "currentPrice": 45
  },
  "details": {
    "labelOrBrand": "unknown",
    "isLargeOrFragile": false
  },
  "candidateMarketplaces": ["ebay", "craigslist", "facebook", "mercari", "offerup", "poshmark"]
}
JSON
cat > "$work_dir/invalid-listing-platform-payload.json" <<'JSON'
{
  "item": {
    "name": "Vintage brass table lamp",
    "category": "Home",
    "condition": "good",
    "originalPrice": 45,
    "currentPrice": 45
  },
  "platform": "garage-sale"
}
JSON
cat > "$work_dir/invalid-listing-category-payload.json" <<'JSON'
{
  "item": {
    "name": "Vintage brass table lamp",
    "category": "Pets",
    "condition": "good",
    "originalPrice": 45,
    "currentPrice": 45
  },
  "platform": "ebay"
}
JSON
cat > "$work_dir/invalid-listing-condition-payload.json" <<'JSON'
{
  "item": {
    "name": "Vintage brass table lamp",
    "category": "Home",
    "condition": "broken",
    "originalPrice": 45,
    "currentPrice": 45
  },
  "platform": "ebay"
}
JSON
cat > "$work_dir/store-apple-token-probe.json" <<'JSON'
{
  "authorization_code": "probe",
  "apple_user_id": "probe"
}
JSON
printf '{}\n' > "$work_dir/delete-account-probe.json"

call_function "analyze-image" "${functions_base}/analyze-image" "$work_dir/analyze-payload.json" "$work_dir/analyze-response.json"
call_function "compare-marketplaces" "${functions_base}/compare-marketplaces" "$work_dir/compare-payload.json" "$work_dir/compare-response.json"
call_function "generate-listing" "${functions_base}/generate-listing" "$work_dir/listing-payload.json" "$work_dir/listing-response.json"
call_rejected_function "analyze-image missing image" "${functions_base}/analyze-image" "$work_dir/invalid-analyze-missing-image-payload.json"
call_rejected_function "analyze-image non-JPEG image" "${functions_base}/analyze-image" "$work_dir/invalid-analyze-png-payload.json"
call_rejected_function "analyze-image invalid base64" "${functions_base}/analyze-image" "$work_dir/invalid-analyze-base64-payload.json"
call_rejected_function "analyze-image non-JPEG bytes" "${functions_base}/analyze-image" "$work_dir/invalid-analyze-jpeg-bytes-payload.json"
call_rejected_function "generate-listing invalid platform" "${functions_base}/generate-listing" "$work_dir/invalid-listing-platform-payload.json"
call_rejected_function "generate-listing invalid category" "${functions_base}/generate-listing" "$work_dir/invalid-listing-category-payload.json"
call_rejected_function "generate-listing invalid condition" "${functions_base}/generate-listing" "$work_dir/invalid-listing-condition-payload.json"
probe_protected_function "store-apple-token" "${functions_base}/store-apple-token" "$work_dir/store-apple-token-probe.json"
probe_protected_function "delete-account" "${functions_base}/delete-account" "$work_dir/delete-account-probe.json"
probe_protected_table "history" "${rest_base}/history?select=id&limit=1"
probe_protected_table "apple_auth_tokens" "${rest_base}/apple_auth_tokens?select=user_id&limit=1"
probe_protected_table "marketplace_research_cache" "${rest_base}/marketplace_research_cache?select=cache_key&limit=1"

analyze_item="$(validate_analyze_response "$work_dir/analyze-response.json")" || fail "analyze-image response shape is invalid"
validate_compare_response "$work_dir/compare-response.json" || fail "compare-marketplaces response shape is invalid"
listing_bytes="$(validate_listing_response "$work_dir/listing-response.json")" || fail "generate-listing response shape is invalid"

printf 'M10 backend preflight passed\n'
printf 'config: %s\n' "$config_path"
printf 'project: %s\n' "$supabase_url"
printf 'schema: history apple_auth_tokens marketplace_research_cache\n'
printf 'functions: analyze-image compare-marketplaces generate-listing store-apple-token delete-account\n'
printf 'protected functions: store-apple-token delete-account\n'
printf 'protected tables: history apple_auth_tokens marketplace_research_cache\n'
printf 'analyze item: %s\n' "$analyze_item"
printf 'analyze rejection contract: missing jpeg base64\n'
printf 'marketplace compare contract: grounded candidates with evidence status\n'
printf 'listing contract: title-description-plain-text\n'
printf 'listing rejection contract: platform category condition\n'
printf 'listing bytes: %s\n' "$listing_bytes"
