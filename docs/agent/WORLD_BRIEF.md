# Brief for building one Zad "world" (shared by every world builder)

You are building one slice of the Zad Flutter app's owner-approved "worlds" redesign.

## The design
Every screen becomes a "world":
- one colour;
- a painted, animated scene on top with the user's companion in a pose (`CompanionState`);
- a heavy title plus one state line built from real data;
- calm white cards below;
- a «متصلة بـ» strip at the end, linking related worlds.

Every page uses `ZadWorldScaffold` (lib/shared/worlds/world_scaffold.dart) with its `ZadWorld` value (lib/shared/worlds/zad_world.dart), plus `world_card.dart`, `world_row.dart`, `world_scene.dart` and `art/art.dart` (70 drawn pictures). There is no emoji anywhere: use drawings only, and add a drawing to the art kit if one is missing.

Finished worlds to copy the pattern from (read-only):
- pantry: lib/features/inventory/presentation/pantry_view.dart, on main;
- statement, budget and transactions: /workspaces/zad-wmoney/zad_flutter/lib/features/{statement,budget,transactions};
- appointments and shopping: /workspaces/zad-whouse/zad_flutter/lib/features/{appointments,inventory};
- pharmacy: /workspaces/zad-wpharmacy/zad_flutter/lib/features/pharmacy.

The approved preview is docs/agent/previews/all_pages_2026_11_15/pages.html (with art.js), plus docs/agent/previews/merged_2026_11_15/index.html. Find your screen's section there (grep its Arabic title or `id="s-…"`) and follow it.

## The owner's rules
- Merge into the existing screen. Never delete a feature: every control and action that exists today must stay reachable. Before finishing, compare against `git show origin/main:<path>`.
- No patching. Don't put a new header on top of the old list: rebuild the body to the world design, and delete the layout code it replaces.
- User-facing strings go in app_ar.arb (Egyptian), app_ar_SA.arb (Saudi wording) and app_en.arb, then run `flutter gen-l10n`. Values that are stored in the database, matched against, or sent to a model stay Arabic literals (CLAUDE.md i18n rule). `test/architecture` includes an arabic_literals test; never raise its baseline, lower it if you can.
- Use the tokens: ZadSpacing, ZadType, ZadColors, ZadWorldColors, ZadRadii and ZadMotion.
- Tap targets are at least 44dp, and the primary action is docked in the bottom thumb zone.
- Every list gets a real empty state.
- Respect reduced motion (`MediaQuery.disableAnimations`).
- Make no LLM call on screen open.
- Respect test/architecture/feature_boundaries_test.dart: a feature imports only core/, shared/ and itself.
- Civil time is the account's market zone, money stays a Double with asMoney(), and dialogs with text fields use showFieldDialog.

## Checks (must pass; quote the real exit codes)
```
export PATH="$HOME/flutter/bin:$PATH"; cd <worktree>/zad_flutter
mkdir -p build; flutter pub get > build/p.log 2>&1; echo EXIT=$?
flutter gen-l10n
flutter analyze > build/a.log 2>&1; echo EXIT=$?; tail -3 build/a.log    # must say "No issues found!"
flutter test -j 2 test/features/<yours> test/architecture test/app/shell_walkthrough_test.dart > build/t.log 2>&1; echo EXIT=$?; tail -5 build/t.log
```
Infinite scene loops make `pumpAndSettle` time out, so set reduced motion in widget tests. Add one widget test for the world (its state line and its empty state).

Add a screenshot test that is skipped unless ZAD_SCREENS=1, in the style of test/shared/worlds/world_scaffold_test.dart: `loadZadFonts`, a 430x932 logical view at dpr 2, and `matchesGoldenFile('../../../build/screens/world_<name>.png')` with realistic Arabic sample data. Run it once with `ZAD_SCREENS=1 flutter test --update-goldens <file>`, then open the PNG and check it.

Never run the full test suite or a release build: the machine is small. Never push.

Commit with a message such as `feat(worlds): <name> as a world — …`, ending with the line
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## Report back
Report the commit hash, the files changed, the analyze and test exit codes with their last lines, the PNG path, and any feature you were unsure how to keep.
