#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

entrypoints=(
    "supabase/functions/analyze-image/index.ts"
    "supabase/functions/generate-listing/index.ts"
    "supabase/functions/store-apple-token/index.ts"
    "supabase/functions/delete-account/index.ts"
)

deno_cmd=()
if [[ -n "${DENO_BIN:-}" ]]; then
    deno_cmd=("$DENO_BIN")
elif command -v deno >/dev/null 2>&1; then
    deno_cmd=(deno)
elif command -v npx >/dev/null 2>&1; then
    deno_cmd=(npx --yes deno)
else
    printf 'error: deno or npx is required to type-check Supabase functions\n' >&2
    exit 1
fi

export DENO_DIR="${DENO_DIR:-${TMPDIR:-/tmp}/buysell-deno-cache}"

"${deno_cmd[@]}" check "${entrypoints[@]}"

printf 'Supabase function Deno check passed\n'
printf 'functions: analyze-image generate-listing store-apple-token delete-account\n'
