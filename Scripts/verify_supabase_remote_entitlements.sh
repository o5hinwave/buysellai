#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
linked_ref_file="$repo_root/supabase/.temp/project-ref"
expected_ref="${SUPABASE_PROJECT_REF:-}"
required_migrations=(
    20260724233029
    20260726132434
    20260726134945
)

export SUPABASE_TELEMETRY_DISABLED="${SUPABASE_TELEMETRY_DISABLED:-1}"

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

validate_project_ref() {
    local ref="$1"

    [[ "$ref" =~ ^[a-z0-9-]+$ ]] || fail "SUPABASE_PROJECT_REF must contain only lowercase letters, numbers, and hyphens"
    [[ "$ref" != "project-ref" ]] || fail "SUPABASE_PROJECT_REF still contains the placeholder project-ref"
}

prepare_linked_ref() {
    local linked_ref

    if [[ -n "$expected_ref" ]]; then
        expected_ref="$(printf '%s' "$expected_ref" | tr -d '[:space:]')"
        validate_project_ref "$expected_ref"

        if [[ -f "$linked_ref_file" ]]; then
            linked_ref="$(tr -d '[:space:]' < "$linked_ref_file")"
            [[ "$linked_ref" == "$expected_ref" ]] || fail "linked Supabase project '$linked_ref' does not match SUPABASE_PROJECT_REF '$expected_ref'"
            return
        fi

        mkdir -p "$(dirname "$linked_ref_file")"
        printf '%s' "$expected_ref" > "$linked_ref_file"
        return
    fi

    [[ -f "$linked_ref_file" ]] || fail "Supabase project is not linked; set SUPABASE_PROJECT_REF or run supabase link"
    linked_ref="$(tr -d '[:space:]' < "$linked_ref_file")"
    validate_project_ref "$linked_ref"
    expected_ref="$linked_ref"
}

query_remote_json() {
    local sql="$1"

    supabase db query --linked --output json "$sql"
}

command -v python3 >/dev/null 2>&1 || fail "python3 is required"
command -v supabase >/dev/null 2>&1 || fail "Supabase CLI is required"

prepare_linked_ref

migration_list="$(IFS=,; printf "'%s'" "${required_migrations[*]}" | sed "s/,/','/g")"
entitlement_json="$(query_remote_json "select config_key, entitlement_state, complete_feature_access, future_paid_access_enabled, daily_analysis_limit, daily_ai_action_limit from public.entitlement_config where config_key = 'global';")"
migration_json="$(query_remote_json "select version from supabase_migrations.schema_migrations where version in (${migration_list}) order by version;")"

ENTITLEMENT_JSON="$entitlement_json" MIGRATION_JSON="$migration_json" EXPECTED_MIGRATIONS="${required_migrations[*]}" python3 <<'PY'
import json
import os


def load_rows(name: str) -> list[dict]:
    payload = json.loads(os.environ[name])
    rows = payload.get("rows")
    if not isinstance(rows, list):
        raise SystemExit(f"{name} did not contain a rows array")
    return rows


entitlement_rows = load_rows("ENTITLEMENT_JSON")
if len(entitlement_rows) != 1:
    raise SystemExit(f"expected one global entitlement_config row, found {len(entitlement_rows)}")

row = entitlement_rows[0]
expected = {
    "config_key": "global",
    "entitlement_state": "earlyAccess",
    "complete_feature_access": True,
    "future_paid_access_enabled": False,
    "daily_analysis_limit": 18,
    "daily_ai_action_limit": 54,
}
for key, expected_value in expected.items():
    actual_value = row.get(key)
    if actual_value != expected_value:
        raise SystemExit(f"entitlement_config.{key} expected {expected_value!r}, found {actual_value!r}")

migration_rows = load_rows("MIGRATION_JSON")
actual_versions = {str(row.get("version")) for row in migration_rows if isinstance(row, dict)}
expected_versions = set(os.environ["EXPECTED_MIGRATIONS"].split())
missing = sorted(expected_versions.difference(actual_versions))
if missing:
    raise SystemExit("remote Supabase migrations missing: " + ", ".join(missing))

print("Supabase remote entitlement check passed")
print("project state: earlyAccess full-access no-paid-access")
print("limits: 18 analyses/day 54 AI-actions/day")
print("migrations: " + " ".join(sorted(expected_versions)))
PY
