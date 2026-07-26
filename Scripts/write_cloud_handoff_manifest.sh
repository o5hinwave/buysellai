#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_path="${1:-/tmp/buysell-cloud-handoff-manifest.log}"
config_path="${M10_CONFIG_PLIST:-$repo_root/BuySellAI/App/Config.plist}"
metadata_path="$repo_root/M10_APP_STORE_METADATA.md"
project_ref_file="$repo_root/supabase/.temp/project-ref"

mkdir -p "$(dirname "$output_path")"
cd "$repo_root"

plist_value() {
    local key="$1"

    [[ -f "$config_path" ]] || return 0
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

metadata_value() {
    local field="$1"

    [[ -f "$metadata_path" ]] || return 0
    awk -F '|' -v field="$field" '
        $2 {
            key=$2
            value=$3
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (key == field) {
                print value
                exit
            }
        }
    ' "$metadata_path"
}

supabase_host_from_url() {
    local value="$1"

    URL_VALUE="$value" python3 <<'PY' 2>/dev/null || true
import os
from urllib.parse import urlparse

host = urlparse(os.environ["URL_VALUE"].strip()).hostname
if host:
    print(host)
PY
}

clean_value() {
    python3 -c 'import sys; print(sys.stdin.read().strip(), end="")'
}

supabase_url="$(plist_value SUPABASE_URL | clean_value)"
supabase_host="$(supabase_host_from_url "$supabase_url" | clean_value)"
project_ref=""
if [[ -f "$project_ref_file" ]]; then
    project_ref="$(clean_value < "$project_ref_file")"
elif [[ "$supabase_host" =~ ^([a-z0-9-]+)\.supabase\.co$ ]]; then
    project_ref="${BASH_REMATCH[1]}"
fi

commit_sha="$(git -c core.fsmonitor=false rev-parse HEAD 2>/dev/null || printf 'unknown')"
branch_name="$(git -c core.fsmonitor=false branch --show-current 2>/dev/null || true)"
support_url="$(metadata_value "Support URL" | clean_value)"
privacy_url="$(metadata_value "Privacy Policy URL" | clean_value)"
accessibility_url="$(metadata_value "Accessibility URL" | clean_value)"
terms_url="$(metadata_value "Terms URL" | clean_value)"

{
    printf 'BuySell cloud handoff manifest\n'
    printf 'repo: https://github.com/o5hinwave/buysellai\n'
    printf 'commit: %s\n' "$commit_sha"
    printf 'branch: %s\n' "${branch_name:-detached-or-cloud-checkout}"
    printf 'bundle id: com.despia.buysellai\n'
    printf 'team id: ZVFG6KC7KA\n'
    printf 'supabase project ref: %s\n' "${project_ref:-pending SUPABASE_PROJECT_REF secret or local link}"
    printf 'supabase host: %s\n' "${supabase_host:-pending SUPABASE_URL secret or Config.plist}"
    printf 'support url: %s\n' "${support_url:-pending M10_APP_STORE_METADATA.md}"
    printf 'privacy url: %s\n' "${privacy_url:-pending M10_APP_STORE_METADATA.md}"
    printf 'accessibility url: %s\n' "${accessibility_url:-pending M10_APP_STORE_METADATA.md}"
    printf 'terms url: %s\n' "${terms_url:-pending M10_APP_STORE_METADATA.md}"
    printf 'cloud workflows: iOS Cloud Check, Cloud Handoff Check, Supabase Backend Deploy, App Store Preflight\n'
    printf 'github secret names: SUPABASE_ACCESS_TOKEN SUPABASE_PROJECT_REF SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_DB_PASSWORD M10_DEVELOPMENT_TEAM IOS_DISTRIBUTION_CERTIFICATE_BASE64 IOS_DISTRIBUTION_CERTIFICATE_PASSWORD IOS_PROVISIONING_PROFILE_BASE64 IOS_KEYCHAIN_PASSWORD ASC_API_KEY_ID ASC_API_ISSUER_ID ASC_API_PRIVATE_KEY\n'
    printf 'supabase secret names: GEMINI_API_KEY SUPABASE_SERVICE_ROLE_KEY APPLE_TEAM_ID APPLE_KEY_ID APPLE_CLIENT_ID APPLE_PRIVATE_KEY\n'
    printf 'source roots: BuySellAI BuySellAITests BuySellAIUITests supabase Scripts AppStoreAssets AppStoreSite\n'
    printf 'release docs: README.md M10_ACCEPTANCE.md M10_APP_STORE_METADATA.md M10_TODAY_FEATURE_NOMINATION.md\n'
    printf 'support site: external Sites project, public production URL recorded above\n'
    printf 'handoff rule: keep secret values only in GitHub Actions secrets, Supabase Edge Function secrets, App Store Connect, or Apple Developer\n'
    printf 'manifest: no secret values emitted\n'
} > "$output_path"

cat "$output_path"
