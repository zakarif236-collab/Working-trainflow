# QA Checklist — Pre-Release Verification

Run this checklist before shipping a release build (APK/AAB). The goal is to
catch regressions across the app's core flows on a real device.

## 1. Preflight

- [ ] `pubspec.yaml` version bumped for the release (`flutter build` reads `versionCode`/`versionName` from here).
- [ ] `android/key.properties` present and contains the release keystore credentials.
- [ ] Release build is signed with the release config (`android/app/build.gradle.kts`).
- [ ] `--dart-define=GEMINI_API_KEY=<key>` passed to the build if voice-over features should be enabled.
      Without it, voice features silently disable (`GeminiConfig.isConfigured` is false).
- [ ] No secrets (API keys, service account credentials) are committed to the repo.

## 2. Build Commands

```sh
# APK (universal + per-ABI splits under build/app/outputs/flutter-apk/)
flutter build apk --release --dart-define=GEMINI_API_KEY=<key>

# AAB for Play Console (build/app/outputs/bundle/release/app-release.aab)
flutter build appbundle --release --dart-define=GEMINI_API_KEY=<key>
```

Artifacts:
- Universal APK — quick installs and manual device checks.
- Split APKs (arm64-v8a, armeabi-v7a, x86, x86_64) — smaller per-architecture footprint; Play Store serves the right one.
- AAB — uploaded to Play Console; Google generates optimized APKs from it.

## 3. Automated Tests

```sh
flutter analyze
flutter test
```

Known automated coverage:
- `test/community_save_test.dart` — community save/unsave persistence and dedupe.
- `test/community_display_name_test.dart` — comment author display-name resolution.

Note: some pre-existing `widget_test.dart` failures exist on clean `master`
(quick-start flows, home timer) and are tracked separately, not release-blocking
unless they regress.

## 4. Manual Device Checklist

Install the universal release APK on a physical device and verify each area.

### Community
- [ ] Feed loads published workouts (Firestore stream), newest first.
- [ ] Save a community workout to My Workouts; confirm it appears and does not duplicate on re-save.
- [ ] Unsave removes it from My Workouts; unsaving an unsaved workout is a safe no-op.
- [ ] Comment on a workout — author shows the real Google display name (not a UID/serial), and the comment stays visible after the stream refreshes.
- [ ] Like / favorite / rate a workout; counts update on refresh.
- [ ] Publish a workout — creator name is the display name, workout appears in the feed.
- [ ] Offline: comment/like are queued (sync queue) and replay when back online.

### Voice-Over Notifications
- [ ] Timer prompts fire correctly in the foreground.
- [ ] Voice prompts fire in the background (if supported) — verify gating behavior.
- [ ] Voice works with Gemini API key baked in; no errors when disabled.

### Firebase (Firestore / Storage)
- [ ] Upload and download work (workout covers/images, shared routines).
- [ ] Offline cache renders cached data on cold start.
- [ ] Firestore permissions: users can only mutate their own data.
- [ ] Multi-device sync: progress/stats converge (see `docs/superpowers/specs/2026-08-03-multi-device-sync-convergence-design.md`).

### Ads
- [ ] Banners load on the expected screens.
- [ ] Interstitials load and reward flow (ad earn points) works.
- [ ] Ads tear down cleanly (no leaks/errors) after closing the app.
- [ ] No ad crashes on flaky/offline networks.

### Workout Builder
- [ ] Routines save locally (My Workouts).
- [ ] Routines sync to Firestore and reload from another device.
- [ ] Community routines import back into the builder.
- [ ] Timer / player screen runs the routine correctly (start/pause/rest, exercise transitions).

### Offline Mode
- [ ] App cold-starts and renders the first frame without network.
- [ ] Cached community feed and workouts are shown while offline.
- [ ] Sync queue drains and converges when connectivity returns.

### Recent Items / Feed Order
- [ ] Recent workouts/items order is correct (newest first).
- [ ] Updates to existing items propagate live via the stream.

## 5. Sign-off

- [ ] All release-blocking items above pass on a physical device.
- [ ] Release build artifacts generated from the final commit (`git log --oneline -1` matches).
- [ ] Tag the release commit (e.g., `v1.0.0+1`) for traceability.
