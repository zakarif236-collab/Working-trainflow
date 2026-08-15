# Task 1 Report: Swap App ID in Android manifest and iOS Info.plist

## What I implemented

Replaced the AdMob App ID `ca-app-pub-6138624088986178~6997939566` with the new one `ca-app-pub-3222893031015336~9049517717` in exactly two platform config files:

- `android/app/src/main/AndroidManifest.xml` line 20 — `android:value` of the `com.google.android.gms.ads.APPLICATION_ID` meta-data
- `ios/Runner/Info.plist` line 8 — string value of the `GADApplicationIdentifier` key

Both values match the brief verbatim.

## What I tested and test results

Ran `git grep -n "ca-app-pub-3222893031015336" -- android ios` (substituted for `rg` per task instructions — `rg` is not installed on this Windows machine). Result: exactly 2 matches, one per file:

```
android/app/src/main/AndroidManifest.xml:20:            android:value="ca-app-pub-3222893031015336~9049517717"/>
ios/Runner/Info.plist:8:	<string>ca-app-pub-3222893031015336~9049517717</string>
```

`git diff -- android ios` confirmed the diff touches only these two lines (2 insertions, 2 deletions, no other changes). No `flutter analyze`/test suite run per task instructions (config-only change; later tasks do full verification).

## Files changed

- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

## Commit

- `d76d71f` `feat(ads): point App ID to new AdMob account` (2 files changed, 2 insertions(+), 2 deletions(-))

Staged only the two intended files. Unrelated modified files (`.superpowers/sdd/*.md`, linux/macos/windows generated plugin registrant files) were left unstaged.

## Self-review findings

- Changed exactly the two values specified, nothing else. PASS
- Diff limited to `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`. PASS
- Both new values identical to the App ID in the brief (`ca-app-pub-3222893031015336~9049517717`). PASS

## Issues or concerns

None.
