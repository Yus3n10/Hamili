# Color Palette + Offline Support Design

Two independent features. Palette ships first.

## Feature 1 — Custom accent color (full recolor)

**Goal:** Let users pick an accent color; the whole app recolors.

- `AppAccent` model: name, `primary`, `dark`; `gradient => [primary, dark]`. Presets: Green (default), Blue, Purple, Pink, Red, Orange, Amber, Teal. Chosen for readable white-on-color contrast.
- `accentProvider` (Riverpod `Notifier<AppAccent>`) persists the choice in the existing `app_settings` Hive box, same pattern as `themeModeProvider`.
- `AppTheme.light(accent)` / `AppTheme.dark(accent)`: build the `ColorScheme` and every accent-driven component (buttons, FAB, nav, inputs, progress, segmented, text button) from `accent`, and attach a `BrandTheme` `ThemeExtension` carrying `dark` and `gradient`.
- Widgets that hardcode `AppColors.primary` / `primaryDark` / `brandGradient` read `context.accent` / `context.accentDark` / `context.accentGradient` (a `BuildContext` extension over `colorScheme` + `BrandTheme`).
- `income` / `expense` / `warning` stay fixed — they carry meaning.
- Picker UI: a row of swatches in the appearance settings, next to the light/dark toggle.

## Feature 2 — Pragmatic offline support

**Goal:** Every non-AI feature works with no connection and syncs on reconnect. Hami stays online-only.

- The `OfflineQueue` already stores generic `{method, path, data}` ops and replays them; only the transaction repo enqueues today.
- Extend budget, goal, and recurring repos: on a connection error during create/update/delete, enqueue the op and throw `OfflineQueuedException`; their providers optimistically update local state and the Hive cache (transactions already do this).
- Reads already fall back to the Hive cache.
- Replay the queue in order when a request next succeeds (already wired via the response interceptor) and on app resume.
- Hami (chat + insights): detect no connection and show a "needs a connection" state instead of failing silently.

**Known limitation (accepted):** editing or deleting an item that was *created offline and has not synced yet* is best-effort — the queued op references a temporary id. Documented, not solved here (that needs server-id remapping).

## Out of scope

- Conflict resolution across devices.
- Server-side token/id remapping for offline-created records.
