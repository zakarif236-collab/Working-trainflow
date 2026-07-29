### Task 4: MainShellPage — Relax Tab Auth Gates

**Files:**
- Modify: `lib/pages/main_shell_page.dart`

**Interfaces:**
- Consumes: `AuthService.currentUserId`, `AuthPage.showAsSheet(context)`
- Produces: Tabs 0, 1, 2 freely accessible; tab 3 (Profile) gated behind sign-in

**Change:**

Replace the `_onTabSelected` method body. Currently it gates tabs 1 and 2. Change it to only gate tab 3:

```dart
Future<void> _onTabSelected(int index) async {
  if (index == 3) {
    if (_authService.currentUserId == null) {
      final signedIn = await AuthPage.showAsSheet(context);
      if (signedIn != true || !mounted) return;
      OnboardingSheet.showIfNeeded(context, _authService);
    }
  }
  setState(() {
    if (index == 0) {
      _homeTimerKey++;
      _pendingWorkoutConfig = null;
    }
    _selectedIndex = index;
  });
}
```

No imports needed — everything already imported.
Run `dart analyze lib/pages/main_shell_page.dart`
Commit: `feat: only gate Profile tab behind sign-in`
