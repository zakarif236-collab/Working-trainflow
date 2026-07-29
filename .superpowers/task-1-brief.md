# Task 1: Add Visibility Field to CommunityWorkout Model

## Files
- Modify: `lib/models/workout_models.dart` (add `visibility` field to `CommunityWorkout`)

## Interfaces
- Produces: `CommunityWorkout.visibility` (String: 'public', 'followers', 'private'), updated `toJson()`/`fromJson()`/`copyWith()`

## Steps

### Step 1: Add visibility enum
In `workout_models.dart`, after the `WorkoutDifficulty` enum, add:
```dart
enum WorkoutVisibility { public, followers, private }
```

### Step 2: Add visibility field to CommunityWorkout
In the `CommunityWorkout` class constructor, add after `isFollowingCreator`:
```dart
    this.visibility = 'public',
```
Add the field declaration after `isFollowingCreator`:
```dart
  final String visibility;
```

### Step 3: Update copyWith
Add to `copyWith` parameter list:
```dart
    String? visibility,
```
Add to the return statement:
```dart
      visibility: visibility ?? this.visibility,
```

### Step 4: Update toJson
Add to the `toJson()` map:
```dart
      'visibility': visibility,
```

### Step 5: Update fromJson
Add to `fromJson` factory:
```dart
      visibility: json['visibility'] as String? ?? 'public',
```

### Step 6: Verify analysis
Run: `flutter analyze lib/models/workout_models.dart`
Expected: No errors

### Step 7: Commit
```bash
git add lib/models/workout_models.dart
git commit -m "feat: add visibility field to CommunityWorkout model"
```
