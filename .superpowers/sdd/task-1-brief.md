### Task 1: Gate companion notification on foreground state

**Files:**
- Modify: `lib/services/workout_foreground_service.dart` (fields ~31-32, `start` ~72-74, `promoteToForeground` ~114-122, `demoteToBackground` ~125-131, `stop` ~134-144, `update` ~162-167)

**Interfaces:**
- Consumes: existing public API (`start`, `promoteToForeground`, `demoteToBackground`, `update`, `stop`) â€” signatures unchanged.
- Produces: internal `bool _isForegrounded` that is true only while the companion notification is visible.

- [ ] **Step 1: Add the `_isForegrounded` field**

Locate the fields block (~lines 31-34):

```dart
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  bool _actionForwarderAttached = false;
```

Replace it with:

```dart
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// True only while the companion notification is visible (i.e. the app is
  /// backgrounded/locked). Guards `_showActionNotification` in [update] so no
  /// notification is posted while the user is inside the app.
  bool _isForegrounded = false;

  bool _actionForwarderAttached = false;
```

- [ ] **Step 2: Reset the flag in `start`**

In `start()` (~lines 67-74), find:

```dart
    _isPaused = false;
    _isMusicPlaying = isMusicPlaying;
    _lastActionContent = '';
```

Replace with:

```dart
    _isPaused = false;
    _isMusicPlaying = isMusicPlaying;
    _isForegrounded = false;
    _lastActionContent = '';
```

- [ ] **Step 3: Set the flag in `promoteToForeground`**

Find:

```dart
  Future<void> promoteToForeground() async {
    if (!_isRunning) return;
    _updateForegroundNotificationInfo();
    _service.invoke('setAsForeground');
```

Replace with:

```dart
  Future<void> promoteToForeground() async {
    if (!_isRunning) return;
    _isForegrounded = true;
    _updateForegroundNotificationInfo();
    _service.invoke('setAsForeground');
```

- [ ] **Step 4: Clear the flag in `demoteToBackground`**

Find:

```dart
  Future<void> demoteToBackground() async {
    if (!_isRunning) return;
    _service.invoke('setAsBackground');
```

Replace with:

```dart
  Future<void> demoteToBackground() async {
    if (!_isRunning) return;
    _isForegrounded = false;
    _service.invoke('setAsBackground');
```

- [ ] **Step 5: Clear the flag in `stop`**

Find:

```dart
    _service.invoke('stop');
    _isRunning = false;

    if (Platform.isAndroid) {
```

Replace with:

```dart
    _service.invoke('stop');
    _isRunning = false;
    _isForegrounded = false;

    if (Platform.isAndroid) {
```

- [ ] **Step 6: Gate the companion notification in `update`**

Find:

```dart
    if (_isRunning) {
      _updateForegroundNotificationInfo();
      if (Platform.isAndroid) {
        await _showActionNotification();
      }
    }
```

Replace with:

```dart
    if (_isRunning) {
      _updateForegroundNotificationInfo();
      if (Platform.isAndroid && _isForegrounded) {
        await _showActionNotification();
      }
    }
```

- [ ] **Step 7: Analyze**

Run: `flutter analyze`
Expected: no new issues in `lib/services/workout_foreground_service.dart` (pre-existing project warnings may remain).

- [ ] **Step 8: Build debug APK**

Run: `flutter build apk --debug`
Expected: `âˆš Built build\app\outputs\flutter-apk\app-debug.apk`

- [ ] **Step 9: Manual verification checklist**

On a device/emulator:
1. Start a workout, stay in the app â‰¥ 5s â†’ no notification appears in the shade.
2. Press Home (background) â†’ companion Pause/Stop notification appears.
3. Lock the phone â†’ notification still visible on the lock screen.
4. Unlock and reopen app â†’ notification disappears.
5. Stop/reset the workout, start a new one â†’ no stale notification, and while in-app again no notification.
6. While backgrounded, verify Pause/Stop buttons still work from the notification.

- [ ] **Step 10: Commit**

```bash
git add lib/services/workout_foreground_service.dart
git commit -m "fix: gate workout companion notification on foreground state"
```

---

