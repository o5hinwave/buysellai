#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

python3 - "$repo_root" <<'PY'
import re
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
migration_paths = [
    repo_root / "supabase/migrations/20260717000100_create_remote_history_and_apple_auth_tokens.sql",
    repo_root / "supabase/migrations/20260718000100_harden_history_constraints.sql",
    repo_root / "supabase/migrations/20260718000200_harden_apple_auth_token_identity.sql",
]
swift_paths = {
    "marketplace": repo_root / "BuySellAI/Data/Marketplace.swift",
    "models": repo_root / "BuySellAI/Data/Models.swift",
}

for path in migration_paths + list(swift_paths.values()):
    if not path.is_file():
        raise SystemExit(f"missing required file: {path.relative_to(repo_root)}")

sql = "\n".join(path.read_text(encoding="utf-8") for path in migration_paths)
compact_sql = re.sub(r"\s+", " ", sql.lower())


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"error: {message}")


def require_sql(pattern: str, message: str) -> None:
    require(re.search(pattern, sql, re.IGNORECASE | re.DOTALL) is not None, message)


def require_compact(fragment: str, message: str) -> None:
    require(fragment.lower() in compact_sql, message)


def enum_cases(path: Path, enum_name: str) -> list[str]:
    text = path.read_text(encoding="utf-8")
    match = re.search(rf"enum\s+{enum_name}\b[^\{{]*\{{(?P<body>.*?)\n\}}", text, re.DOTALL)
    require(match is not None, f"{enum_name} enum body not found")
    cases: list[str] = []
    for line in match.group("body").splitlines():
        case_match = re.match(r"\s*case\s+([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)\s*$", line)
        if case_match:
            cases.extend(value.strip() for value in case_match.group(1).split(","))
    require(cases, f"{enum_name} enum has no simple raw-value cases")
    return cases


def constraint_values(column: str) -> set[str]:
    match = re.search(
        rf"\b{column}\b\s+(?:is\s+null\s+or\s+\b{column}\b\s+)?in\s*\((?P<body>.*?)\)",
        sql,
        re.IGNORECASE | re.DOTALL,
    )
    require(match is not None, f"{column} value constraint is missing")
    return set(re.findall(r"'([^']+)'", match.group("body")))


def require_value_parity(label: str, swift_values: list[str], sql_values: set[str]) -> None:
    missing = [value for value in swift_values if value not in sql_values]
    extra = sorted(sql_values.difference(swift_values))
    require(not missing, f"{label} constraint is missing Swift values: {', '.join(missing)}")
    require(not extra, f"{label} constraint has values not present in Swift: {', '.join(extra)}")


marketplace_cases = enum_cases(swift_paths["marketplace"], "Marketplace")
category_cases = enum_cases(swift_paths["models"], "Category")
condition_cases = enum_cases(swift_paths["models"], "Condition")

require("add constraint if not exists" not in compact_sql, "Postgres does not support ADD CONSTRAINT IF NOT EXISTS")

require_sql(r"create\s+table\s+if\s+not\s+exists\s+public\.history\b", "history table is missing")
require_sql(r"create\s+table\s+if\s+not\s+exists\s+public\.apple_auth_tokens\b", "apple_auth_tokens table is missing")
require_sql(
    r"user_id\s+uuid\s+not\s+null\s+default\s+auth\.uid\(\)\s+references\s+auth\.users\s*\(\s*id\s*\)\s+on\s+delete\s+cascade",
    "history.user_id must default to auth.uid() and cascade from auth.users",
)
require_sql(
    r"create\s+table\s+if\s+not\s+exists\s+public\.apple_auth_tokens\b.*?user_id\s+uuid\s+primary\s+key\s+references\s+auth\.users\s*\(\s*id\s*\)\s+on\s+delete\s+cascade",
    "apple_auth_tokens.user_id must be the auth.users cascade primary key",
)

for table in ("history", "apple_auth_tokens"):
    require_sql(rf"alter\s+table\s+public\.{table}\s+enable\s+row\s+level\s+security", f"{table} must enable RLS")
    require_sql(rf"alter\s+table\s+public\.{table}\s+force\s+row\s+level\s+security", f"{table} must force RLS")

require_sql(
    r"create\s+policy\s+\"Users can manage their own history\"\s+on\s+public\.history\s+for\s+all\s+to\s+authenticated\s+using\s*\(\s*\(\s*select\s+auth\.uid\(\)\s*\)\s*=\s*user_id\s*\)\s+with\s+check\s*\(\s*\(\s*select\s+auth\.uid\(\)\s*\)\s*=\s*user_id\s*\)",
    "history policy must scope authenticated users with cached auth.uid() checks",
)
require_sql(
    r"create\s+index\s+if\s+not\s+exists\s+history_user_created_at_idx\s+on\s+public\.history\s*\(\s*user_id\s*,\s*created_at\s+desc\s*\)",
    "history must index user_id and created_at for RLS-filtered history reads",
)
require_sql(
    r"conname\s*=\s*'apple_auth_tokens_apple_user_id_unique'.*?unique\s*\(\s*apple_user_id\s*\)",
    "apple_auth_tokens.apple_user_id must be unique",
)

for constraint in (
    "history_item_name_not_blank",
    "history_marketplace_not_blank",
    "history_listing_text_not_blank",
    "history_suggested_price_positive",
    "apple_auth_tokens_apple_user_id_not_blank",
    "apple_auth_tokens_refresh_token_not_blank",
    "history_category_known",
    "history_condition_known",
    "history_marketplace_known",
    "history_listing_text_has_sections",
    "apple_auth_tokens_apple_user_id_unique",
):
    require_sql(rf"\b{re.escape(constraint)}\b", f"{constraint} constraint is missing")

require_value_parity("category", category_cases, constraint_values("category"))
require_value_parity("condition", condition_cases, constraint_values("condition"))
require_value_parity("marketplace", marketplace_cases, constraint_values("marketplace"))

require_compact("revoke all on table public.history from anon", "history must revoke anon access")
require_compact("grant select, insert, update, delete on table public.history to authenticated", "history must grant only authenticated CRUD")
require_compact("grant all on table public.history to service_role", "history must grant service_role access")
require_compact("revoke all on table public.apple_auth_tokens from anon", "apple_auth_tokens must revoke anon access")
require_compact("revoke all on table public.apple_auth_tokens from authenticated", "apple_auth_tokens must revoke authenticated access")
require_compact("grant all on table public.apple_auth_tokens to service_role", "apple_auth_tokens must grant service_role access")
require(
    re.search(r"grant\s+[^;]*on\s+table\s+public\.apple_auth_tokens\s+to\s+authenticated", sql, re.IGNORECASE | re.DOTALL)
    is None,
    "apple_auth_tokens must not grant authenticated table access",
)

print("Supabase schema static check passed")
print("files: " + " ".join(path.relative_to(repo_root).as_posix() for path in migration_paths))
print("tables: history apple_auth_tokens")
print("rls: history apple_auth_tokens forced")
print("policy: history authenticated select-auth-uid")
print("indexes: history_user_created_at_idx apple_auth_tokens_apple_user_id_unique")
print("grants: history authenticated service_role apple_auth_tokens service_role")
print("constraints: history category condition marketplace listing apple-token-identity")
print("swift parity: category condition marketplace")
PY
