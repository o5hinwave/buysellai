#!/usr/bin/env bash
set -euo pipefail

root="${1:-.}"
pattern='AQ\.[0-9A-Za-z_-]{20,}|AIza[0-9A-Za-z_-]{20,}|sk-[0-9A-Za-z_-]{20,}'

cd "$root"

set +e
matches="$(
    rg -l -I --hidden \
        --glob '!.git/*' \
        --glob '!DerivedData/**' \
        --glob '!*.xcresult/**' \
        --glob '!*.xcarchive/**' \
        --glob '!*.dSYM/**' \
        "$pattern" \
        .
)"
status=$?
set -e

case "$status" in
    0)
        printf 'M10 secret scan failed. Remove provider secrets from these files:\n' >&2
        printf '%s\n' "$matches" >&2
        exit 1
        ;;
    1)
        printf 'M10 secret scan passed\n'
        ;;
    *)
        exit "$status"
        ;;
esac
