### Task 4: Full verification — analyze, tests, release config sanity

**Files:**
- Test: `test/ad_helper_test.dart` (already updated in Task 3)

**Interfaces:**
- Consumes: all changes from Tasks 1-3.
- Produces: evidence that nothing is broken and release builds resolve the new IDs.

- [ ] **Step 1: Run the analyzer**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: ALL PASS. Pay attention to `test/ad_helper_test.dart`, `test/header_banner_ad_test.dart`, `test/scaled_banner_ad_test.dart`, `test/builder_ad_watches_test.dart` — banner tests run on the host VM where `bannerAdUnitId` throws inside existing try/catch, so widgets still render with no ad.

- [ ] **Step 3: Confirm release-mode ID resolution**

The `production` branch cannot be exercised under `flutter test` because `kReleaseMode` is `false` on the host VM. Instead, verify by inspection: `rg "3222893031015336" lib test android ios` should show the App ID (2 config matches), the banner production ID (2 in `ad_helper.dart`, 2 in `ad_helper_test.dart`), and no other files.

- [ ] **Step 4: Commit any plan/bookkeeping changes if needed**

No code changes expected in this task. If `flutter analyze` or the full test suite surfaced no issues, nothing to commit here.

## Self-Review

- **Spec coverage:** App ID in Android manifest (Task 1 Step 1) ✓; App ID in Info.plist (Task 1 Step 2) ✓; banner production IDs both platforms (Task 2) ✓; test IDs kept for debug/profile (Task 2 code shows unchanged test branch) ✓; interstitial/rewarded untouched (Task 2 Step 2 verification) ✓; test updates (Task 3) ✓; analyze + tests (Task 4) ✓; SDK init and release ad loading (Task 4 Step 3 + Global Constraints; init flow in `AdHelper.ensureInitialized` is untouched) ✓.
- **Placeholder scan:** No TBD/TODO placeholders; the only TODOs referenced are the pre-existing intentional interstitial ones that must remain.
- **Type consistency:** `adUnitIdFor` signature matches between Task 2 (implementation) and Task 3 (test). Getter names unchanged throughout.

## Non-Code Follow-up (out of scope)

- Confirm fill status in the AdMob dashboard for the new account's banner unit.
- Verify `app-ads.txt` for the new account domain.
- If AdMob requires distinct iOS banner units, add an iOS-specific production banner ID later.