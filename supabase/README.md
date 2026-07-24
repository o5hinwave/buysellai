# BuySell AI Supabase Functions

These Edge Functions are deployment templates for the native iOS contracts. They keep provider and service-role secrets server-side; do not copy those values into `BuySellAI/App/Config.plist`, source, tests, or shell commands that persist in history.

Required Supabase secrets:

```sh
SUPABASE_PROJECT_REF=<project-ref> bash Scripts/setup_supabase_secrets.sh preflight
SUPABASE_PROJECT_REF=<project-ref> bash Scripts/setup_supabase_secrets.sh full
```

The `preflight` mode resolves the target project and verifies Supabase CLI secret access before any secret values are requested. The `full` helper prompts for `GEMINI_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_ID`, and an Apple private-key `.p8` path, or reads those values from CI secret environment variables when `SUPABASE_SECRETS_FROM_ENV` is set to `1`. It resolves the target from `SUPABASE_PROJECT_REF`, `BuySellAI/App/Config.plist`, or the linked Supabase project before prompting for secrets, validates that the Apple private-key path resolves outside the repository and must be a `.p8` private-key file, writes a 0600 temporary env file outside the repository, calls `supabase secrets set --project-ref <project-ref> --env-file`, then removes the temp file on exit. The Supabase release helpers default `SUPABASE_TELEMETRY_DISABLED=1` so CLI telemetry cannot make release checks flaky. Use `SUPABASE_PROJECT_REF=<project-ref> bash Scripts/setup_supabase_secrets.sh gemini-only` only for an early guest analyze/listing smoke test; full App Store readiness still requires the service-role and Apple secrets. Rotate any provider or server-side key that was pasted into chat, logs, or git before using it for production. Do not copy Gemini, Supabase `sb_secret_...`, JWT signing secrets, service-role secrets, or Apple private-key material into `BuySellAI/App/Config.plist`, source, tests, Xcode build settings, or long-lived shell history. The final M10 secret scan reads hidden files, so remove any temporary local secret files before collecting submit-readiness evidence.

Optional backend tuning:

```sh
# Optional: override the stable production default only after collecting fresh release evidence.
supabase secrets set GEMINI_MODEL=gemini-2.5-flash
supabase secrets set GEMINI_TIMEOUT_MS=18000
supabase secrets set APPLE_TIMEOUT_MS=8000
supabase secrets set SUPABASE_SERVICE_TIMEOUT_MS=8000
```

The shared Gemini helper defaults to Google's stable `gemini-2.5-flash` model so final App Store evidence proves one exact model version while keeping listing research fast and low-cost. `compare-marketplaces` runs the minimal grounded search needed before the picker recommends a place to sell, then saves useful grounded findings to `marketplace_research_cache` for the selected listing step. `generate-listing` creates a minimal search plan, reuses fresh cache rows, and only enables live Google Search when saved research is missing or stale. Override `GEMINI_MODEL` only for a deliberate model change, then rerun the backend smoke preflight, Deno check, unit/UI evidence, and M10 submit-readiness gate before submission.

Apply the bundled schema migrations before deploying functions:

```sh
supabase db push
```

The migrations create signed-in history sync storage, harden history rows with native category/condition/marketplace/listing constraints, and create the private Apple token table with RLS, least-privilege grants, and unique Apple subject storage. The history policy wraps `auth.uid()` in `select` so Postgres can evaluate it once per statement while enforcing user-owned rows. The hardening deploy marker is `constraints: history category condition marketplace listing apple-token-identity`. The Apple token table shape is:

```sql
create table public.apple_auth_tokens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  apple_user_id text not null,
  refresh_token text not null,
  access_token text,
  access_token_expires_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint apple_auth_tokens_apple_user_id_unique unique (apple_user_id)
);

alter table public.apple_auth_tokens enable row level security;
```

Deploy after the migration and secrets are in place:

```sh
ALLOW_MISSING_SUPABASE_DEPLOY=1 bash Scripts/deploy_supabase_backend.sh preflight

CONFIRM_SUPABASE_DEPLOY=<project-ref> bash Scripts/deploy_supabase_backend.sh deploy | tee /tmp/buysell-submit-readiness-supabase-deploy.log
```

The deploy helper validates the public app config, linked project, required server-side secret names, migrations, and Edge Function sources, then runs `supabase db push --linked --yes` and deploys each function with `--use-api`. It bounds secret-name listing with `M10_SUPABASE_SECRET_LIST_TIMEOUT_SECONDS` so local CLI stalls become explicit pending evidence instead of indefinite waits, and it never prints secret values. Passing deploy evidence includes `constraints: history category condition marketplace listing apple-token-identity`. Manual equivalent commands are:

```sh
supabase functions deploy analyze-image
supabase functions deploy compare-marketplaces
supabase functions deploy generate-listing
supabase functions deploy store-apple-token
supabase functions deploy delete-account
```

`analyze-image`, `compare-marketplaces`, and `generate-listing` are configured with `verify_jwt = false` so guest requests that include only the public anon `apikey` can work. `store-apple-token` and `delete-account` keep `verify_jwt = true` and also verify the bearer token. `store-apple-token` checks whether the Apple subject is already owned by another Supabase user before exchanging the short-lived Apple authorization code, requires Apple's token response to include an identity subject that matches the submitted Apple user ID, exchanges valid codes for server-side Apple tokens, and returns a 409 conflict for duplicate Apple identity storage. `delete-account` attempts to revoke the stored Apple token through Apple's `/auth/revoke` endpoint, deletes the private token row, then deletes user-owned history and the auth user with the service-role key. BuySell account deletion still completes if Apple token cleanup is stale or temporarily unavailable, but missing or malformed Apple private-key secrets remain hard backend errors so release evidence cannot hide a revocation misconfiguration.

After deployment, run the backend smoke preflight from the repository root:

```sh
bash Scripts/setup_supabase_config.sh

M10_ANALYZE_IMAGE_JPEG=/path/to/common-item.jpg \
bash Scripts/preflight_m10_backend.sh BuySellAI/App/Config.plist
```

The app config helper writes only the public `SUPABASE_URL` and `SUPABASE_ANON_KEY` values to `BuySellAI/App/Config.plist`, prompts for them or reads environment variables with the same names for noninteractive setup, supports `SUPABASE_CONFIG_FROM_ENV=1` for fail-fast CI/release setup, accepts public anon or `sb_publishable_...` keys, rejects copied placeholders and provider/server-secret-shaped values including `sb_secret_...`, and keeps the key out of terminal output.

Before deployment, type-check the local Edge Function sources from the repository root:

```sh
bash Scripts/check_supabase_schema.sh | tee /tmp/buysell-submit-readiness-supabase-schema.log

bash Scripts/check_supabase_functions.sh | tee /tmp/buysell-submit-readiness-supabase-functions.log
```

The schema checker verifies forced RLS, the cached authenticated history policy, indexes for RLS-filtered reads and Apple subject identity, least-privilege grants, idempotent hardening constraints, and Swift-to-SQL category/condition/marketplace value parity. Passing output includes `Supabase schema static check passed`, `rls: history apple_auth_tokens forced`, `policy: history authenticated select-auth-uid`, `indexes: history_user_created_at_idx apple_auth_tokens_apple_user_id_unique`, and `swift parity: category condition marketplace`.

The checker uses a local `deno` binary when available, or a temporary `npx --yes deno` fallback with `DENO_DIR` outside the repo. Passing output includes `Supabase function Deno check passed`; retain it as `/tmp/buysell-submit-readiness-supabase-functions.log` for the combined M10 gate.

The preflight verifies live `analyze-image`, `compare-marketplaces`, and `generate-listing` responses, including the plain-text `TITLE:` and `DESCRIPTION:` listing contract, verifies `analyze-image` rejects missing image data, non-JPEG data URLs, and malformed base64, verifies `generate-listing` rejects unsupported platform, category, and condition values, confirms `store-apple-token` and `delete-account` reject anonymous requests, and probes `history` and `apple_auth_tokens` through PostgREST so a missing migration cannot pass release evidence. Passing output includes `schema: history apple_auth_tokens`, `functions: analyze-image compare-marketplaces generate-listing store-apple-token delete-account`, `protected functions: store-apple-token delete-account`, `protected tables: history apple_auth_tokens`, `analyze rejection contract: missing jpeg base64`, `marketplace compare contract: grounded candidates with evidence status`, `listing contract: title-description-plain-text`, and `listing rejection contract: platform category condition`.
