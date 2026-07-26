# Task 2 Report: Create CommunityFirestoreService

## What You Implemented

Created `lib/services/community_firestore_service.dart` — a singleton service wrapping all Firestore operations for the global community feed:

- **publishWorkout()** — creates a new community workout document
- **loadWorkouts()** — fetches public workouts (one-shot)
- **streamWorkouts()** — real-time stream of public workouts
- **toggleLike()** / **toggleFavorite()** — user interaction tracking with per-user subcollections
- **addComment()** — adds a comment sub-document under a workout
- **rateWorkout()** — stores user rating and increments aggregate counts
- **toggleFollow()** — follow/unfollow a creator via per-user subcollection
- **incrementShare()** — increments share counter
- **loadCreatorStats()** — aggregates downloads/likes/shares for a creator

## What You Tested and Test Results

- Ran `flutter analyze lib/services/community_firestore_service.dart`
- **Result:** 0 errors, 3 info-level lint warnings (`avoid_types_as_parameter_names` — cosmetic only)

## Files Changed

| File | Action |
|------|--------|
| `lib/services/community_firestore_service.dart` | Created |

## Self-Review Findings

1. **Bugs fixed from brief:** The task brief contained 3 compile errors:
   - Line 55 (brief): `exercises: input.routine.exercises.map((e) => e.name).toList()` passed `List<String>` but the model expects `List<WorkoutBuilderExercise>`. Fixed to `exercises: input.routine.exercises`.
   - Lines 210-222 (brief): The catch-block `CreatorCommunityStats` constructor was missing required parameters `bio`, `profileImagePath`, and `badges`. All three were added.
2. **Lint warnings:** 3x `avoid_types_as_parameter_names` for the `sum` parameter in `fold` closures. These are cosmetic infos from the brief's original code; no functional impact.

## Issues or Concerns

None. The service compiles cleanly and follows the existing codebase patterns (singleton, try/catch, Firebase integration).