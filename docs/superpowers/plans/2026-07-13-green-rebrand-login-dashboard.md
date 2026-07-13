# Green Rebrand + Login/Dashboard Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Rebrand Hamili to the new green identity (colors, Inter font, new logo, rounder shapes) app-wide, and redesign the Login and Dashboard to match the Lovable reference; other screens inherit the theme.

**Architecture:** Ship in 4 ordered phases (A foundation → B login → C dashboard → D recolor cleanup). Foundation changes the shared theme/colors/logo so every screen shifts at once; login and dashboard are then restructured; a final sweep fixes hardcoded-color stragglers.

**Tech Stack:** Flutter · google_fonts (Inter) · flutter_svg (logo) · flutter_launcher_icons (dev) · flutter_animate (logo animation).

## Global Constraints
- Colors only via `AppColors`; money via `CurrencyFormatter`; Inter via google_fonts.
- `flutter analyze` → 0 issues and `flutter build web` compiles after each phase.
- No backend changes. Omit reference elements with no backend: "Continue with Google", "Send money".
- Commit per phase.

---

## Phase A — Brand foundation

### Task A1: New palette (`app_colors.dart`)

**Files:** Modify `hamili-app/lib/core/theme/app_colors.dart`

- [ ] **Step 1: Replace brand + semantic + neutral colors** (keep the class structure & `chartPalette` shape)

```dart
  // Brand — green identity (H + rising path + star)
  static const Color primary = Color(0xFF16A34A);
  static const Color primaryDark = Color(0xFF15803D);
  static const Color primaryLight = Color(0xFF6EE7B7); // mint accent
  static const Color secondary = Color(0xFF0F172A);    // deep navy

  // Semantic
  static const Color income = Color(0xFF0EA5A4);  // teal — distinct from brand green
  static const Color expense = Color(0xFFF5455C); // coral red
  static const Color warning = Color(0xFFF59E0B);

  // Light neutrals
  static const Color lightBackground = Color(0xFFF4F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark neutrals — brand navy
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF161E2E);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Brand gradient (logo bg): light green -> deep green
  static const List<Color> brandGradient = [Color(0xFF22C55E), Color(0xFF15803D)];

  static const List<Color> chartPalette = [
    Color(0xFF16A34A), // green
    Color(0xFF0EA5A4), // teal
    Color(0xFF6EE7B7), // mint
    Color(0xFFF5455C), // coral
    Color(0xFF3B82F6), // blue
    Color(0xFF9B6DFF), // violet
    Color(0xFFF59E0B), // amber
    Color(0xFFEC4899), // pink
  ];
```

- [ ] **Step 2:** `cd hamili-app && flutter analyze` → 0 issues.

### Task A2: Inter font + pill buttons (`app_theme.dart`)

**Files:** Modify `hamili-app/lib/core/theme/app_theme.dart`

- [ ] **Step 1: On-primary → white** (green is dark enough for white text)

Change `static const Color _onPrimary = Color(0xFF241A05);` to `static const Color _onPrimary = Color(0xFFFFFFFF);`

- [ ] **Step 2: Inter everywhere** — replace `_textTheme`:

```dart
  static TextTheme _textTheme(TextTheme base, Color textPrimary) {
    final t = GoogleFonts.interTextTheme(base).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    TextStyle h(TextStyle? s, FontWeight w) =>
        GoogleFonts.inter(textStyle: s, fontWeight: w, color: textPrimary);
    return t.copyWith(
      displayLarge: h(t.displayLarge, FontWeight.w700),
      displayMedium: h(t.displayMedium, FontWeight.w700),
      displaySmall: h(t.displaySmall, FontWeight.w700),
      headlineLarge: h(t.headlineLarge, FontWeight.w700),
      headlineMedium: h(t.headlineMedium, FontWeight.w700),
      headlineSmall: h(t.headlineSmall, FontWeight.w700),
      titleLarge: h(t.titleLarge, FontWeight.w700),
      titleMedium: h(t.titleMedium, FontWeight.w600),
    );
  }
```

- [ ] **Step 3: Replace remaining `GoogleFonts.nunito(...)` / `GoogleFonts.dmSans(...)` calls with `GoogleFonts.inter(...)`** (appBar title, the three button themes, textButton, navigationBar label) — same params, just the font family swapped. Keep weights (appBar 700, buttons 700, nav label 600).

- [ ] **Step 4: Pill buttons** — in `elevatedButtonTheme`, `filledButtonTheme`, `outlinedButtonTheme` change `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))` to `shape: const StadiumBorder()`. Leave input/card radii at 16/20.

- [ ] **Step 5:** `flutter analyze` → 0 issues.

### Task A3: Logo asset + widget + animation

**Files:** Create `hamili-app/assets/logo/hamili_logo.svg`; create `hamili-app/lib/shared/widgets/hamili_logo.dart`; modify `pubspec.yaml`.

- [ ] **Step 1: Add the SVG asset** — write the extracted logo (from scratchpad `hamili_logo.svg`) to `hamili-app/assets/logo/hamili_logo.svg`.

- [ ] **Step 2: pubspec** — add under dependencies: `flutter_svg: ^2.0.10`; register assets under the `flutter:` section:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/logo/
```

Run `cd hamili-app && flutter pub get`.

- [ ] **Step 3: Logo widgets** (`hamili_logo.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Hamili mark (H + rising path + star), rendered from the brand SVG.
class HamiliLogo extends StatelessWidget {
  const HamiliLogo({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('assets/logo/hamili_logo.svg', width: size, height: size);
  }
}

/// Animated brand mark for the login/splash: scales + fades in, gently floats,
/// and a star twinkle pulses over the corner. Asset-light (flutter_animate).
class AnimatedHamiliLogo extends StatelessWidget {
  const AnimatedHamiliLogo({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) {
    final star = size * 0.16;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          HamiliLogo(size: size)
              .animate()
              .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeOutBack)
              .fadeIn(duration: 400.ms)
              .then()
              .shimmer(duration: 1600.ms, color: Colors.white.withValues(alpha: 0.25)),
          Positioned(
            right: size * 0.14,
            top: size * 0.14,
            child: Icon(Icons.auto_awesome, size: star, color: Colors.white)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.7, end: 1.1, duration: 1200.ms, curve: Curves.easeInOut)
                .fadeIn(),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4:** `flutter analyze` → 0 issues; `flutter build web` compiles.

### Task A4: App launcher icons

**Files:** Create `hamili-app/assets/logo/hamili_icon_1024.png`; modify `pubspec.yaml` (dev dep + config).

- [ ] **Step 1: Rasterize** the SVG to a 1024×1024 PNG at `assets/logo/hamili_icon_1024.png` (render via an available method — headless browser canvas export or an installed SVG rasterizer; commit the PNG).
- [ ] **Step 2: pubspec** — add dev dep `flutter_launcher_icons: ^0.13.1` and a config block:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/logo/hamili_icon_1024.png"
  adaptive_icon_background: "#0F172A"
  adaptive_icon_foreground: "assets/logo/hamili_icon_1024.png"
```

- [ ] **Step 3: Generate** — `cd hamili-app && flutter pub get && dart run flutter_launcher_icons`.
- [ ] **Step 4: Commit Phase A**

```bash
git add hamili-app/lib/core/theme/app_colors.dart hamili-app/lib/core/theme/app_theme.dart \
        hamili-app/lib/shared/widgets/hamili_logo.dart hamili-app/assets/logo/ hamili-app/pubspec.yaml \
        hamili-app/android hamili-app/ios
git commit -m "feat(brand): green rebrand foundation — palette, Inter, logo, launcher icons"
```

---

## Phase B — Login redesign

**Files:** Modify `hamili-app/lib/features/auth/presentation/login_page.dart`.

- [ ] **Step 1:** Read the current `login_page.dart` to preserve auth wiring (controllers, submit, error handling, providers).
- [ ] **Step 2:** Rebuild the layout: responsive two-panel (wide) / stacked (narrow):
  - Hero: `AnimatedHamiliLogo(size: 96)` + "hamili" wordmark (Inter 700) + "Welcome back." + "Handle money. Achieve life." on a brand-tinted panel (light: subtle green wash; dark: navy).
  - Card: Email, Password with show/hide, Remember-me switch, "Forgot password?" (stub → SnackBar if no backend flow), pill **Sign in** (existing submit), "New to Hamili? Create an account".
  - **Omit** "Continue with Google".
- [ ] **Step 3:** Keep all existing auth logic/providers unchanged; only the presentation changes.
- [ ] **Step 4:** `flutter analyze` → 0; `flutter build web` compiles.
- [ ] **Step 5:** Commit `feat(auth): redesign login to the new brand with animated logo`.

---

## Phase C — Dashboard redesign

**Files:** Modify `hamili-app/lib/features/dashboard/presentation/dashboard_page.dart` and `widgets/` (reuse providers; no data-layer change). Add small private section widgets as needed.

- [ ] **Step 1:** Read current `dashboard_page.dart` + `widgets/summary_card.dart` + `widgets/insights_card.dart` and the goals/budgets/analytics providers to reuse their data.
- [ ] **Step 2:** Rebuild into the goal-first order:
  1. Greeting header (`Hi, <preferredName>` + time-of-day) with small `HamiliLogo(size: 28)` + notifications icon.
  2. **Active Goal** card — top goal by progress: title, `formatted saved of target`, % bar/ring, "Add funds" (routes to the goal contribution flow). Empty-state prompt if no goals.
  3. **Stat tiles** row (reuse existing balance/analytics): Balance (+trend), Monthly income, Monthly spending (vs last month).
  4. Spending **chart** (reuse fl_chart + analytics data) with a W/M/Y `SegmentedButton`.
  5. **AI Insight** card (existing `InsightsCard`, restyled; still gated by `insightsEnabledProvider`).
  6. **Budgets** list — category rows + % bars (reuse `budgetsProvider`), "Manage" → budgets tab.
  7. **Recent activity** — recent transactions (reuse `transactionsProvider`), "See all".
  - Keep the budget-over-limit overlay; **omit** "Send".
- [ ] **Step 3:** `flutter analyze` → 0; `flutter build web` compiles.
- [ ] **Step 4:** Commit `feat(dashboard): goal-first redesign on the new brand`.

---

## Phase D — App-wide recolor cleanup

**Files:** sweep `hamili-app/lib/**`.

- [ ] **Step 1:** `grep` for hardcoded legacy/gold hex (e.g. `0xFFF6A821`, `0xFFE0890A`, `0xFFFFD37E`, `241A05`) and any `Colors.amber/orange` in widgets; route through `AppColors`.
- [ ] **Step 2:** Verify `hami_mascot.dart` (piggy) reads well in green — it uses `AppColors.primary*` so it recolors automatically; adjust the dark eye/detail contrast if needed.
- [ ] **Step 3:** Quick brand pass: onboarding, chat header, analytics chart colors, confetti colors → brand palette.
- [ ] **Step 4:** `flutter analyze` → 0; full `flutter build web`.
- [ ] **Step 5:** Commit `style(brand): recolor remaining screens to the green identity`.

---

## Self-Review
- Spec Phase A (palette/Inter/logo/icons) → A1–A4 ✓; Phase B login → B ✓; Phase C dashboard → C ✓; Phase D recolor → D ✓.
- Placeholder scan: foundation steps carry full code; B/C/D are read-then-rebuild tasks against the reference structure (screen redesigns), each with explicit section lists + verification. No TBDs.
- Type/consistency: `AppColors.primary/primaryDark/primaryLight/secondary/income/expense`, `HamiliLogo({size})`, `AnimatedHamiliLogo({size})`, `_onPrimary=white`, StadiumBorder buttons — consistent across tasks and with the read source files.
