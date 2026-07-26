#!/usr/bin/env bash
set -euo pipefail

allow_missing="${ALLOW_MISSING_APP_STORE_CREDENTIALS:-0}"

required_credentials=(
    "M10_DEVELOPMENT_TEAM"
    "IOS_DISTRIBUTION_CERTIFICATE_BASE64"
    "IOS_DISTRIBUTION_CERTIFICATE_PASSWORD"
    "IOS_PROVISIONING_PROFILE_BASE64"
    "ASC_API_KEY_ID"
    "ASC_API_ISSUER_ID"
    "ASC_API_PRIVATE_KEY"
)

optional_credentials=(
    "IOS_KEYCHAIN_PASSWORD"
)

missing=()

is_set() {
    local name="$1"
    [[ -n "${!name:-}" ]]
}

printf 'App Store cloud credential check\n'
printf 'lane: signed archive, App Store Connect export, and App Store validation\n'
printf 'bundle id: com.despia.buysellai\n'

for name in "${required_credentials[@]}"; do
    if is_set "$name"; then
        printf 'present: %s\n' "$name"
    else
        printf 'missing: %s\n' "$name"
        missing+=("$name")
    fi
done

for name in "${optional_credentials[@]}"; do
    if is_set "$name"; then
        printf 'optional present: %s\n' "$name"
    else
        printf 'optional defaulted: %s\n' "$name"
    fi
done

if [[ "${#missing[@]}" -gt 0 ]]; then
    if [[ "$allow_missing" == "1" ]]; then
        printf 'App Store cloud credential check pending: %s required GitHub secret(s) are not configured\n' "${#missing[@]}"
        printf 'Set the missing secrets in GitHub Actions, then rerun App Store Preflight with allow_missing_credentials=false.\n'
        exit 0
    fi

    printf 'error: App Store cloud credential check failed: %s required GitHub secret(s) are not configured\n' "${#missing[@]}" >&2
    printf 'Set the missing secrets in GitHub Actions or rerun with ALLOW_MISSING_APP_STORE_CREDENTIALS=1 for pending evidence.\n' >&2
    exit 1
fi

printf 'App Store cloud credential check passed\n'
