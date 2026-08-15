# Task 2 Report: Update production banner IDs in AdHelper

## Status: DONE

## What I implemented
Edited `lib/add/ad_helper.dart` — changed ONLY the two `production` branches of the banner cases in `adUnitIdFor`:

- `case (AdPlatform.android, AdType.banner)`: `'ca-app-pub-6138624088986178/4990989256'` → `'ca-app-pub-3222893031015336/8843106337'`
- `case (AdPlatform.ios, AdType.banner)`: `'ca-app-pub-6138624088986178/1269723322'` → `'ca-app-pub-3222893031015336/8843106337'`

The banner test IDs, all interstitial cases (with their TODOs), and all rewarded cases are untouched.

## What I tested and test results
- `git diff lib/add/ad_helper.dart` shows exactly 2 insertions / 2 deletions, both the banner production string literals. Interstitial TODOs and rewarded IDs unchanged. Diff is banner-only.
- `git grep -n "6138624088986178" -- lib/add/ad_helper.dart` — the only remaining hits are the rewarded production IDs (lines 77, 81: `.../2840036851` and `.../7209425656`), which must remain. All old banner production IDs are gone.
- `git grep -n "3222893031015336/8843106337" -- lib/add/ad_helper.dart` — present in both banner cases (lines 63, 67).
- `git show --stat HEAD` — commit touches only `lib/add/ad_helper.dart` (1 file changed, 2 insertions, 2 deletions).

## Files changed
- `lib/add/ad_helper.dart` (only file in the commit)

## Self-review findings
- Exactly the two banner production values changed to `ca-app-pub-3222893031015336/8843106337`. ✓
- Banner TEST values, interstitial values + TODOs, rewarded values all untouched. ✓
- Commit diff limited to `lib/add/ad_helper.dart`. ✓
- No unrelated files staged or committed; other worktree modifications (linux/macos/windows generated registrants, `.superpowers` scratch) remain uncommitted as instructed.
- Did not modify `test/ad_helper_test.dart` (Task 3) and did not run the full test suite, per instructions.

## Issues or concerns
None.
