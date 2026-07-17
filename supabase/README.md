# BuySell AI Supabase Functions

These Edge Functions are deployment templates for the native iOS contracts. They keep provider and service-role secrets server-side; do not copy those values into `BuySellAI/App/Config.plist`, source, tests, or shell commands that persist in history.

Required Supabase secrets:

```sh
supabase secrets set GEMINI_API_KEY
supabase secrets set SUPABASE_SERVICE_ROLE_KEY
```

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
