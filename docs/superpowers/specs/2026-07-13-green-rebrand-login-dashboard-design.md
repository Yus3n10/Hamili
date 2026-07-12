# Design — Hamili green rebrand + Login & Dashboard redesign

**Date:** 2026-07-13
**Status:** Approved (design), pending implementation plan

Adopt the new Hamili brand (from the user's Lovable reference + logo board) across the whole app,
and redesign the Login and Dashboard screens to match the reference. Other screens keep their
current layouts but inherit the new brand (colors, font, radii, logo).

## Reference source
- Live preview: `https://goal-spark-ai-73.lovable.app` (Login `/`, Dashboard `/dashboard`).
- Logo: extracted inline SVG (saved during brainstorming), self-contained with two linear gradients.
- Tokens read from live CSS: Inter font (headings 700), primary green, navy foreground, white bg,
  mint accents, large radii (~20px cards, pill buttons). Icons Lucide, charts Recharts (reference only).

## Brand tokens (target)
- **Primary** `#16A34A` · **Primary dark** `#15803D` · **Primary light / accent (mint)** `#6EE7B7`
  (deep mint `#34D399`) · **Secondary / navy** `#0F172A` · **Background** `#FFFFFF` (light).
- Logo gradient: bg `#22C55E → #15803D`; rising path `#A7F3D0 → #34D399`; H bars + star `#F8FAFC`.
- **Font:** Inter (replaces Nunito headings + DM Sans body).
- **Radius:** cards ~20px; buttons stadium/pill.

---

## Phase A — Brand foundation (app-wide)

**Files:**
- `lib/core/theme/app_colors.dart` — rewrite palette.
- `lib/core/theme/app_theme.dart` — Inter via google_fonts; rounder card/button shapes; wire new colors.
- `pubspec.yaml` — add `flutter_svg`; add `flutter_launcher_icons` (dev); register `assets/logo/`.
- Create `assets/logo/hamili_logo.svg` (extracted SVG).
- Create `lib/shared/widgets/hamili_logo.dart` — `HamiliLogo` (static, sized) + `AnimatedHamiliLogo`.

**Palette rules:**
- `primary=#16A34A`, `primaryDark=#15803D`, `primaryLight=#6EE7B7`, `secondary=#0F172A` (navy).
- Keep `expense=#F5455C` (coral). Set `income` to a distinct teal-green (e.g. `#0EA5A4` / keep a
  green that is visibly different from brand primary) so income vs brand green don't blend.
- Light: `lightBackground=#F5F7FA`-ish, `lightSurface=#FFFFFF`, text `#0F172A` / secondary
  `#64748B`. Dark: `darkBackground=#0F172A`, `darkSurface=#161E2E`-ish, text `#F1F5F9`.
- `brandGradient=[#22C55E, #15803D]`. Keep a `chartPalette` re-anchored on green/mint/navy/coral.

**Theme:**
- `GoogleFonts.interTextTheme(...)` for both themes; headings weight 700.
- `cardTheme` radius ~20; `filledButtonTheme`/`elevatedButtonTheme` StadiumBorder (pill);
  `inputDecorationTheme` rounded ~14–16.

**Logo widget:**
- `HamiliLogo({double size})` → `SvgPicture.asset('assets/logo/hamili_logo.svg', width/height: size)`.
- `AnimatedHamiliLogo` → entrance (scale 0.85→1 + fadeIn), a periodic **star twinkle** (small overlay
  star scales/opacity pulse), and a subtle gentle float/shine — via `flutter_animate`. Storage-light,
  no extra assets. (flutter_svg renders the static gradient logo; animation is layered at the widget
  level, not by mutating SVG sub-paths.)

**App launcher icons:**
- Rasterize the SVG → a 1024×1024 PNG (`assets/logo/hamili_icon_1024.png`) and configure
  `flutter_launcher_icons` (Android adaptive + iOS) to regenerate launcher icons, then run it.
  Rasterization method chosen at implementation time (headless render or available tool); the PNG is
  committed so the generation is reproducible.

**Verify:** `flutter analyze`; `flutter build web`; app boots (Hive logs, no console errors).

---

## Phase B — Login redesign

**Files:** `lib/features/auth/presentation/login_page.dart` (+ the existing
`shared/widgets/animated_finance_preview.dart` may be retired or kept behind the hero).

**Layout (responsive, themed light + dark):**
- Wide: two-panel — brand hero (AnimatedHamiliLogo + "hamili" wordmark + "Welcome back." +
  "Handle money. Achieve life.") beside the sign-in card. Narrow: stacked, logo on top.
- Form: Email, Password (show/hide toggle), Remember me, Forgot password (link/stub), **pill "Sign in"**.
  Below: "New to Hamili? Create an account."
- **Omit "Continue with Google"** (no OAuth backend). If a forgot-password flow doesn't exist in the
  backend, the link is a styled stub (SnackBar "coming soon") — flagged, not faked.
- Uses only Hamili's real email/password auth; no behavior change to auth logic.

**Verify:** `flutter analyze`; build; user visual check (login renders, logo animates, sign-in works).

---

## Phase C — Dashboard redesign

**Files:** `lib/features/dashboard/presentation/dashboard_page.dart` and its `widgets/`
(`summary_card.dart`, `insights_card.dart`, new small widgets as needed). Reuse existing providers
(balance/analytics/goals/budgets/transactions/insights) — **no data-layer changes**.

**Reordered, goal-first layout (Hamili data):**
1. Greeting header ("Hi, <name>" + time-of-day) with a small logo mark + notifications icon.
2. **Active Goal** card — top/most-progressed goal: title, `$x of $y · N left`, % ring/bar, "Add funds".
   (If no goals: a friendly "set a goal" prompt.)
3. **Stat tiles** row: Today's balance (+trend), Monthly income (status), Monthly spending (vs last month).
4. Spending **chart** with W/M/Y toggle (reuse fl_chart; existing analytics data).
5. **AI Insight** card — existing insights, restyled (respects the insights on/off toggle).
6. **Budgets** list — category rows with % bars (reuse budgets provider), "Manage".
7. **Recent activity** — recent transactions, "See all".
- Keeps the budget-over-limit overlay (from MainShell). **Omit "Send"** quick action.

**Verify:** `flutter analyze`; build; user visual check.

---

## Phase D — App-wide recolor cleanup

Every other screen inherits the new theme automatically. Sweep for hard spots the palette swap can't
fix:
- Recolor the piggy mascot from gold to brand green (`hami_mascot.dart` uses `AppColors.primary*`, so it
  largely follows automatically — verify it reads well).
- Any widget with hardcoded gold/legacy colors → route through `AppColors`.
- Onboarding, chat header, analytics charts, confetti colors — quick pass for brand consistency.

**Verify:** `flutter analyze`; full `flutter build web`; user visual spot-check across tabs.

---

## Cross-cutting
- New packages: `flutter_svg`, `flutter_launcher_icons` (dev). `google_fonts` already present.
- Ships as ordered commits per phase (A→B→C→D); each independently analyzable/buildable.
- Honest gaps (no backend): Google sign-in and Send-money are omitted, not stubbed as working.
- Verification limit: Flutter web is CanvasKit — automated checks are `analyze` + `build web` + boot;
  pixel/animation confirmation is the user's in Opera GX at each phase.
