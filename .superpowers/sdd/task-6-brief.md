### Task 6: Profile page uses `mergeRemoteInsights`

**Files:**
- Modify: `lib/pages/first_page.dart` (online branch of `_loadInsights`)

**Interfaces:**
- Consumes: `SettingsService.mergeRemoteInsights(String uid)` → `InsightsMergeResult` (Task 5).
- Produces: Profile page renders and persists the merged union.

- [ ] **Step 1: Update the online branch**

In `lib/pages/first_page.dart`, replace the entire body of the online `if (ConnectivityService.instance.isOnline)` block (which currently reads remote insights and sessions separately) with:

```dart
      if (ConnectivityService.instance.isOnline) {
        try {
          final result = await _settingsService
              .mergeRemoteInsights(uid)
              .timeout(_kInsightsNetworkTimeout);
          if (!mounted) {
            return;
          }
          setState(() {
            _insights = result.insights;
            _recentSessions = result.sessions;
          });
        } catch (_) {
          // Offline or slow network: keep the local data already shown.
        }
      }
```

- [ ] **Step 2: Run analyze and tests**

Run: `flutter analyze` then `flutter test test/workout_progress_sync_test.dart`
Expected: no new issues; ALL PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/pages/first_page.dart
git commit -m "feat: profile page renders and persists the merged sync union"
```

---

