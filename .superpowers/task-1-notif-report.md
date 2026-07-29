# Task 1 Report: Add dependencies and Android permissions

**Status:** Complete
**Commit:** `e206368` — `feat: add flutter_background_service dependency and Android permissions`
**Branch:** `feat/task-4-wire-publish-firestore`

## Changes

### pubspec.yaml
Added under dependencies:
- `flutter_background_service: ^5.1.0`
- `flutter_background_service_android: ^6.3.0`

### AndroidManifest.xml
Added permissions before `<application>`:
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_SPECIAL_USE`
- `WAKE_LOCK`
- `RECEIVE_BOOT_COMPLETED`

Added `<service>` declaration inside `<application>`:
- `id.flutter.flutter_background_service.BackgroundService` with `foregroundServiceType="specialUse"`

## Verification

- `flutter pub get` — Success (4 new dependencies resolved)
- `flutter analyze lib/` — 16 pre-existing info-level issues, 0 new issues

## Files Modified
- `pubspec.yaml`
- `android/app/src/main/AndroidManifest.xml`
