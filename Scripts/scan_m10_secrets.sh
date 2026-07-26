#!/usr/bin/env bash
set -euo pipefail

root="${1:-.}"
pattern='AQ\.[0-9A-Za-z_-]{20,}|AIza[0-9A-Za-z_-]{20,}|sk-[0-9A-Za-z_-]{20,}|sb_secret_[0-9A-Za-z_-]{20,}'

repeat_char() {
    local character="$1"
    local count="$2"
    printf '%*s' "$count" '' | tr ' ' "$character"
}

scan_root() (
    local scan_root="$1"
    local matches
    local status
    local search_paths

    cd "$scan_root"
    search_paths=(.)
    if [[ -d BuySellAI || -d supabase || -d Scripts ]]; then
        search_paths=()
        for path in \
            .github \
            BuySellAI \
            BuySellAITests \
            BuySellAIUITests \
            Scripts \
            supabase \
            README.md \
            M10_ACCEPTANCE.md \
            M10_APP_STORE_METADATA.md \
            M10_TODAY_FEATURE_NOMINATION.md \
            M12_MARKETPLACE_PHOTO_INTELLIGENCE.md \
            .env \
            .env.*
        do
            [[ -e "$path" ]] && search_paths+=("$path")
        done
    fi

    set +e
    matches="$(
        rg -l -I --hidden \
            --no-ignore \
            --glob '!.git/*' \
            --glob '!node_modules/**' \
            --glob '!.build/**' \
            --glob '!.swiftpm/**' \
            --glob '!AppStoreSite/**' \
            --glob '!DerivedData/**' \
            --glob '!*.xcresult/**' \
            --glob '!*.xcarchive/**' \
            --glob '!*.dSYM/**' \
            "$pattern" \
            "${search_paths[@]}"
    )"
    status=$?
    set -e

    case "$status" in
        0)
            printf 'M10 secret scan failed. Remove provider/server secrets from these files:\n' >&2
            printf '%s\n' "$matches" >&2
            return 1
            ;;
        1)
            printf 'M10 secret scan passed\n'
            ;;
        *)
            return "$status"
            ;;
    esac
)

self_test() {
    local temp_root
    local output
    local fake_aq_token
    local fake_google_token
    local fake_openai_token
    local fake_supabase_secret

    temp_root="$(mktemp -d "${TMPDIR:-/tmp}/buysell-secret-scan.XXXXXX")"

    fake_aq_token="AQ.$(repeat_char A 24)"
    fake_google_token="AIza$(repeat_char B 24)"
    fake_openai_token="sk-$(repeat_char C 24)"
    fake_supabase_secret="sb_secret_$(repeat_char D 24)"

    mkdir -p "$temp_root/src" "$temp_root/Generated.xcresult" "$temp_root/Generated.xcarchive" "$temp_root/Generated.dSYM"
    printf 'GEMINI_API_KEY=%s\n' "$fake_aq_token" > "$temp_root/src/.env"
    printf 'SUPABASE_SERVICE_ROLE_KEY=%s\n' "$fake_supabase_secret" > "$temp_root/src/server.env"
    printf '%s\n' "$fake_google_token" > "$temp_root/Generated.xcresult/ignored.txt"
    printf '%s\n' "$fake_openai_token" > "$temp_root/Generated.xcarchive/ignored.txt"
    printf '%s\n' "$fake_aq_token" > "$temp_root/Generated.dSYM/ignored.txt"

    if output="$(scan_root "$temp_root" 2>&1)"; then
        printf 'error: M10 secret scan self-test did not catch a provider secret fixture\n' >&2
        rm -rf "$temp_root"
        return 1
    fi

    if [[ "$output" != *"src/.env"* || "$output" != *"src/server.env"* ]]; then
        printf 'error: M10 secret scan self-test did not report the provider/server secret fixture paths\n' >&2
        rm -rf "$temp_root"
        return 1
    fi

    rm "$temp_root/src/.env"
    rm "$temp_root/src/server.env"
    if ! output="$(scan_root "$temp_root" 2>&1)"; then
        printf 'error: M10 secret scan self-test did not ignore generated bundle fixtures\n' >&2
        printf '%s\n' "$output" >&2
        rm -rf "$temp_root"
        return 1
    fi

    rm -rf "$temp_root"
    printf 'M10 secret scan self-test passed\n'
}

self_test
scan_root "$root"
