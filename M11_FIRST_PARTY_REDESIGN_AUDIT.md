# M11 First-Party iOS Redesign Audit

## Existing Product Surface

- Home: launch/splash handoff, primary snap action, optional auth entry, settings entry, recent listings, empty history, pull-to-refresh.
- Camera: full-screen capture, permission recovery, camera-unavailable handling, flash, shutter feedback, offline/analyze recovery.
- Snap Result: analysis loading, success, inline name/price/category/condition editing, retry, retake, error recovery.
- Marketplace Picker: best/lowest summary, marketplace list, estimate badges, loading and fallback rows.
- Listing: generation loading, generated listing text, copy, regenerate, retake while keeping marketplace, success toast.
- History: local SwiftData history, remote Supabase history for signed-in users, swipe/delete confirmation, reopen listing.
- Auth: optional Sign in with Apple, email sign-in, guest escape, account/session persistence, local-to-remote migration.
- Tutorial: compact first-launch guide, keyboard dismissal support, Settings/Home re-entry, Reduce Motion-aware footer behavior.
- Settings: account state, theme and Reduce Motion preferences, tutorial, clear history, review prompt gate, legal/support links, delete account.

## Current Navigation Structure

- `AppRouter` owns a single state-driven primary flow with `NavigationStack` on Home, full-screen camera presentation, and system sheets for auth, settings, result, marketplace, listing, and tutorial.
- The top-level product intentionally avoids tabs because the product’s core model is one task: snap, pick, copy.
- Settings and auth are secondary tasks entered from Home and dismissed back to the primary flow.

## Redesign Findings

- The functional IA already matches the desired one-task product model; adding tabs or dashboards would make the app less first-party for this use case.
- Shared typography now follows San Francisco semantic Dynamic Type roles; remaining redesign work should continue replacing older custom visual compositions screen by screen.
- Home has moved from the earlier decorative hero/pill composition to a native grouped-list task hub with toolbar account/settings actions and a row-based primary snap action.
- Onboarding has moved from a long illustrated carousel to a compact native first-use guide that surfaces snap, pick, and copy steps immediately.
- Marketplace Picker has moved from a custom pinned material header to a native navigation/list sheet with inset grouped marketplace rows and native bordered best/lowest summary actions.
- Listing has moved from custom material panels to a native navigation/list compose sheet with toolbar dismissal and a system bottom action bar.
- Snap Result has moved from a custom scroll/pill composition to a native navigation/list review sheet with a sticky system decision action and bordered retake/retry/menu controls.
- Settings has moved to a quieter native grouped-list surface with standard row highlighting, disclosure indicators, toolbar icon buttons, and a native destructive account confirmation flow.
- Auth has moved from a centered custom pill setup screen to a native inset grouped sign-in sheet with row-based provider actions, `NavigationLink` email entry, toolbar dismissal, native form rows, and system bottom bars for guest/sign-in actions.
- Camera has moved toward a first-party capture surface with AVFoundation tap-to-focus/exposure, a focus indicator, capability-aware front/rear switching, scene-phase pause/restart recovery, torch gating, and full-screen aspect-fill preview while preserving camera-only capture, orientation handling, and downsampled upload data.
- Native material and Liquid Glass fallbacks are centralized, but final SDK evidence remains pending until Xcode/iPhoneOS SDK 27+ is available.
- The camera and critical flow have strong simulator coverage, but final camera quality cannot be accepted until a trusted physical device and Instruments traces are recorded.
- Local loading, empty, offline, error, and success states are represented across tests and screens; backend production states remain pending without real Supabase config and deployed functions.
- App Store metadata and final acceptance docs deliberately preserve owner/legal placeholders until the account owner confirms them.

## Proposed System Direction

- Keep the one-task information architecture: Home to Camera to Result to Marketplace to Listing, with optional Auth, Tutorial, Settings, and History recovery.
- Move typography to native SF semantic roles (`largeTitle`, `title`, `title2`, `title3`, `body`, `caption`, `caption2`, `headline`) while preserving a small wordmark helper.
- Keep the warm orange accent as a restrained functional brand signal, not a decorative color layer.
- Continue using SF Symbols for functional iconography and reserve custom imagery for product identity moments such as the app icon or launch treatment.
- Use system sheets, semantic backgrounds, centralized material surfaces, and Reduce Motion-aware transitions.

## Redesign Sequence

1. Migrate shared typography away from bundled static font faces and into native Dynamic Type system roles.
2. Replace Home’s legacy hero/pill task hub with native grouped-list navigation and toolbar affordances.
3. Keep launch and SwiftUI splash visually aligned through system-bold wordmark styling and shared launch color tokens.
4. Replace the legacy onboarding carousel with a compact first-use guide that preserves first-launch and re-entry behavior.
5. Validate the redesigned Camera surface on a trusted physical device, including preview startup, focus/exposure behavior, switching, torch/flash behavior, capture freeze, and processing handoff.
6. Preserve the current native material layer and continue final SDK verification when the latest toolchain is available.
7. Use real Supabase config/deploy evidence, signed archive/export evidence, physical-device acceptance, and Instruments traces to close the remaining M10 gates.
