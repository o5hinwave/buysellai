# BuySell AI Supabase Functions

These Edge Functions are deployment templates for the native iOS contracts. They keep provider and service-role secrets server-side; do not copy those values into `BuySellAI/App/Config.plist`, source, tests, or shell commands that persist in history.

Required Supabase secrets:

```sh
read -rsp "Gemini API key: " GEMINI_API_KEY; printf '\n'
read -rsp "Supabase service-role key: " SUPABASE_SERVICE_ROLE_KEY; printf '\n'
printf 'GEMINI_API_KEY=%s\nSUPABASE_SERVICE_ROLE_KEY=%s\n' "$GEMINI_API_KEY" "$SUPABASE_SERVICE_ROLE_KEY" > .env
supabase secrets set --env-file .env
rm .env
unset GEMINI_API_KEY SUPABASE_SERVICE_ROLE_KEY
```

Rotate any provider key that was pasted into chat, logs, or git before using it for production. Do not copy Gemini or service-role secrets into `BuySellAI/App/Config.plist`, source, tests, Xcode build settings, or long-lived shell history. The final M10 secret scan reads hidden files, so remove temporary `.env` files before collecting submit-readiness evidence.

Optional model override:

```sh
supabase secrets set GEMINI_MODEL=gemini-3.5-flash
```

Deploy:

```sh
supabase functions deploy analyze-image
supabase functions deploy generate-listing
supabase functions deploy delete-account
```

`analyze-image` and `generate-listing` are configured with `verify_jwt = false` so guest requests that include only the public anon `apikey` can work. `delete-account` keeps `verify_jwt = true` and also verifies the bearer token before deleting user-owned history and the auth user with the service-role key.

After deployment, run the backend smoke preflight from the repository root:

```sh
M10_ANALYZE_IMAGE_JPEG=/path/to/common-item.jpg \
bash Scripts/preflight_m10_backend.sh BuySellAI/App/Config.plist
```
