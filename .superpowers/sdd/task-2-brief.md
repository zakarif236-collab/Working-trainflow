### Task 2: Update production banner IDs in AdHelper

**Files:**
- Modify: `lib/add/ad_helper.dart:61-68`

**Interfaces:**
- Consumes: nothing from Task 1 (independent).
- Produces: `adUnitIdFor(AdPlatform.android, AdType.banner, production: true)` returns `ca-app-pub-3222893031015336/8843106337`, and `adUnitIdFor(AdPlatform.ios, AdType.banner, production: true)` returns the same. Existing getters `bannerAdUnitId` / `interstitialAdUnitId` / `rewardedAdUnitId` keep their signatures.

- [ ] **Step 1: Update the banner production values**

Edit `lib/add/ad_helper.dart` lines 61-68 (the two banner cases). Change only the `production` branch of each:

```dart
      case (AdPlatform.android, AdType.banner):
        return production
            ? 'ca-app-pub-3222893031015336/8843106337'
            : 'ca-app-pub-3940256099942544/6300978111';
      case (AdPlatform.ios, AdType.banner):
        return production
            ? 'ca-app-pub-3222893031015336/8843106337'
            : 'ca-app-pub-3940256099942544/2934735716';
```

Leave interstitial cases (lines 69-74) and rewarded cases (lines 75-82) exactly as they are.

- [ ] **Step 2: Verify the diff is banner-only**

Run: `git diff lib/add/ad_helper.dart`
Expected: only the two banner `production` string literals changed. Interstitial TODOs and rewarded IDs unchanged.

- [ ] **Step 3: Commit**

```bash
git add lib/add/ad_helper.dart
git commit -m "feat(ads): use new production banner ad unit IDs"
```

---
