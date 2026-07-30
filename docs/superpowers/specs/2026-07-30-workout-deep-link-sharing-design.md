# Workout Deep Link Sharing — Design Spec

## Overview

Add a share button to the workout builder's completion overlay that lets users share their custom workout via a deep link (`fitpulse://workout/{id}`). When a friend clicks the link in WhatsApp, Instagram, or any messaging app, the app opens and loads that workout directly.

This is an add-on to the existing community publishing flow — no backend changes needed.

---

## Scope

| Dimension | Choice | Rationale |
|-----------|--------|-----------|
| Link scope | Community-published workouts only | Reuses existing Firestore IDs. No extra backend. Private workouts can be published first. |
| Link type | Custom scheme `fitpulse://` | Already hardcoded in clipboard share. Quick setup. Works on WhatsApp/Instagram. |

---

## Feature Flow

### 1. Builder completion overlay — Share button

**File:** `workout_builder_player_page.dart`

When the user finishes a builder workout, the `_BuilderCompletionOverlay` gets a new "Share" button alongside the existing "Done" button.

**Tap "Share":**
- If workout is NOT yet published → opens the community publish bottom sheet (`_PublishWorkoutSheet` with routine pre-filled)
- After publish succeeds → copies `fitpulse://workout/{firestoreId}` to clipboard AND opens the OS share sheet (via `share_plus`)
- Shows SnackBar "Link copied to clipboard"

**Tap "Done":** — unchanged, pops the navigator.

### 2. Deep link registration

**Package:** `app_links` (handles incoming links on both platforms)

**Android:** Add intent filter in `AndroidManifest.xml` for `fitpulse://` scheme.

**iOS:** Add `CFBundleURLTypes` entry in `Info.plist` for `fitpulse` scheme.

### 3. Link listener at app startup

**File:** `main.dart`

In `initState` or after `WidgetsBinding.instance.setSecureFlag`, attach an `app_links` listener that:
- Parses incoming URI
- Extracts `workout/{id}` pattern
- Pushes the builder player page with the workout loaded from Firestore

### 4. Link receiver — load and play

When a link like `fitpulse://workout/abc123` is received:
1. Parse path — extract `abc123`
2. Fetch `CommunityWorkout` from Firestore via `CommunityFirestoreService`
3. Create a `WorkoutBuilderRoutine` from the workout's exercises
4. Navigate to `/workout-builder-player` with the routine as argument

---

## Data Flow

```
User finishes workout
        │
        ▼
[Share] button tapped
        │
        ├── Not published? ──► Publish sheet ──► Firestore save (existing)
        │                                               │
        └── Published? ──────► Copy link to clipboard
                              ► Open OS share sheet
                              ► SnackBar
                              
Friend clicks link in WhatsApp
        │
        ▼
fitpulse://workout/{id}
        │
        ▼
OS opens app → app_links listener fires
        │
        ▼
Parse ID → fetch from Firestore → build Routine → push BuilderPlayerPage
```

---

## Files to Change

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `app_links` and `share_plus` packages |
| `lib/pages/workout_builder_player_page.dart` | Add "Share" button to completion overlay |
| `lib/main.dart` | Add deep link listener on startup |
| `android/app/src/main/AndroidManifest.xml` | Add `fitpulse://` intent filter |
| `ios/Runner/Info.plist` | Add `CFBundleURLTypes` for `fitpulse` scheme |

---

## Out of Scope

- Firebase Dynamic Links / web fallback (can be added later with a domain)
- Analytics tracking for link clicks
- Link preview metadata (Open Graph tags)
