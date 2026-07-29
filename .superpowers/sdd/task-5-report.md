# Task 5 Report — Disable Community Card When Offline

**Status:** Complete

**Commits:**
- `1724ac1` feat: disable Community card when offline

**Changes:**
- `lib/pages/home_page.dart`:
  - Added import for `connectivity_service.dart`
  - Community `_ModCard` now shows "Sign in when online" subtitle and disables tap when offline
  - Made `_ModCard.onTap` nullable (`VoidCallback?`)

**Verification:** `dart analyze lib/pages/home_page.dart` — No issues found.
