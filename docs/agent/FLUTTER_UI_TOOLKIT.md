---
title: Flutter UI Toolkit — Zad
date: 2026-09-25
tags:
  - agent
  - flutter
  - design
  - reference
aliases:
  - مكتبات واجهة فلاتر
  - FLUTTER_UI_TOOLKIT
---

# Flutter UI Toolkit — Zad

Packages, MCPs and skills for making `zad_flutter/` look polished: motion,
glass, charts, loading skeletons, 3D. The owner collected these as a recommendation
list, and each one is checked here against what the repo already has. **Read
this note before adding a UI package or reaching for an effect.** Most of the list
is already installed or already built in-house.

> [!important] Order of preference
> 1. What `zad_flutter/lib/design/` already has (tokens, `GlassSurface`, `ZadCard`,
>    `ZadPressable`, `ZadEmptyState`, `zad_motion.dart`).
> 2. An effect from a package that is **already in `pubspec.yaml`**, such as
>    `flutter_animate`'s `.shimmer()`.
> 3. A new dependency, added deliberately in its own commit with a reason
>    comment in `pubspec.yaml`, as every existing entry has. Check that the
>    package supports Dart 3 before adding it: `hive`, `isar` and `lucide_icons`
>    were all ruled out because they don't.

## Packages

| Package | Status in repo | Use it for | Notes |
|---|---|---|---|
| `flutter_animate` | ✅ `^4.5.2` | Entrance, stagger, list reveal: `.animate().fadeIn().moveY(begin: 12)` | Take durations/curves from `design/tokens/zad_motion.dart`, never inline new ones. |
| `rive` | ✅ `^0.14.11` | Interactive icons (bottom nav), the assistant's animated character | `.riv` assets go in `assets/`, declared in `pubspec.yaml`. |
| `fl_chart` | ✅ `^1.2.0` | Spending curves (`isCurved: true`), gradient fills | Load the `dataviz` skill before any chart. |
| `flutter_shaders` / `smooth_corner` | ✅ | Shader effects; squircle corners | `design/foundation/squircle.dart` wraps the corner shape, so use it. |
| Glassmorphism | ✅ built in | Frosted cards, top bar | **`backdrop_filter` is not a package.** `BackdropFilter` is core Flutter, already wrapped in `design/foundation/glass_surface.dart`, which always clips (an unclipped blur is the costliest widget here). Use `GlassSurface`, don't hand-roll it. |
| Shimmer skeleton | ✅ built in (partly) | Loading placeholders instead of spinners | `ZadMotion.shimmer` (1600ms) exists. Prefer `flutter_animate`'s built-in `.shimmer()` over adding the `shimmer` package, since it's the same effect with no new dependency. |
| `google_fonts` | ❌ rejected | — | Cairo and Inter are **bundled** (`assets/fonts/`, `kZadArabicFont`). `google_fonts` fetches at runtime by default, which breaks the offline-first rule and leaves a fresh install with no text font. |
| Material 3 theme | ✅ | — | `design/zad_theme.dart` already sets `useMaterial3: true` and `fontFamily: kZadArabicFont`. Elevation lives in `design/foundation/elevation.dart`. |
| `smooth_sheets` | ➖ candidate | iOS-style rubber-band bottom sheets | Not added. Adopt only when a sheet actually needs it. |
| `wolt_modal_sheet` | ➖ candidate | Multi-page sheets (step-by-step quick-add transaction) | Not added. Same rule. |
| `o3d` / `flutter_cube` | ➖ candidate, unverified | Real `.glb` 3D (wallet, piggy bank, gyroscope card) | Heavy for what it buys. Check the render path, APK size and Dart 3 support before adding. For spatial feel, try parallax/tilt with `Transform` first (the principles in the `zad-compose-depth` skill carry over). |

> [!warning] Deprecated API to avoid
> `Colors.white.withOpacity(0.15)` is deprecated in current Flutter. Use
> `Colors.white.withValues(alpha: 0.15)`. `flutter analyze` flags it (the
> `very_good_analysis` lint set).

## MCPs and tools in this environment

| Suggested | Reality here | How to use |
|---|---|---|
| Figma to Flutter / design tokens | ✅ Figma MCP connected (`mcp__claude_ai_Figma__*`, `mcp__figma__*`) | Only useful if a Figma file exists. Zad has none. **The source of truth for pixel-matching is the Kotlin code**: `app/.../ui/theme/Color.kt`, `Type.kt`, and each screen's `.kt`. |
| Context7 | ✅ connected (`mcp__context7__*`) | **Library documentation lookup** (current `flutter_animate`/`rive`/`fl_chart` APIs). It does not convert Compose ASTs to widgets. |
| Dart / Flutter language server MCP | ❌ not configured | `flutter analyze` is the check, run after every change (see [[FLUTTER_MIGRATION]] §1). |
| File-system context MCP | Not needed | `Read`/`Grep` on `app/src/main/...` already read the Compose source line by line. |
| Copilot / Cline LSP skills | Not applicable | Different agents. |

## Pixel-matching a Compose screen

1. Read the Kotlin screen and its components first, then write the widget.
2. Map colours through the tokens in `zad_flutter/lib/design/tokens/`. Add a
   missing token there, never a raw hex in a screen (except illustrative UI such
   as Kids Mode, per [[CLAUDE]]).
3. Spacing stays on the 4/8 grid, tap targets ≥ 44dp, and every list gets a real
   empty state (`ZadEmptyState`).
4. Motion comes from `zad_motion.dart` via `flutter_animate`. Loading uses a
   skeleton, not a spinner.

> [!example] The one-line brief
> Soft entrances with `flutter_animate`; rounded or squircle surfaces with a soft,
> blurred `BoxShadow`; `fl_chart` curves for spending; a shimmer skeleton while
> loading, all through Zad's own tokens and components.

## Skills to pair with

`mobile-app-ui-design`, `dataviz` (charts), `motion-design` (principles),
`design:accessibility-review` (contrast, `Semantics`), `design:ux-copy` (Arabic
strings), and `zad-cupertino-heritage` / `zad-compose-depth` for Zad's visual
language (written for Compose, but the principles carry over). The full routing
table is in [[SKILLS_INDEX]].

## Related

- [[SKILLS_INDEX]]
- [[FLUTTER_MIGRATION]]
- [[CLAUDE]]
