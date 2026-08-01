# Home Timer Header Banner Ad — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a small AdMob banner to the right of the "Immersive Workout Timer" title in the home timer header, scaled down to half size so it never pushes the timer content downward.

**Architecture:** Two new self-contained widgets. `ScaledBannerAd` is a pure, testable layout widget that renders any child (the ad) at half its natural size via `SizedBox` + `FittedBox`. `HeaderBannerAd` is a stateful widget that owns the AdMob `BannerAd` lifecycle (load, dispose, empty-when-unavailable) and renders `SizedBox.shrink()` until an ad loads. `HomeTimerLayout` mounts `HeaderBannerAd` inside the existing header `Row`, after the `Expanded` title column, so the banner cannot displace the timer below.

**Tech Stack:** Flutter / Dart, `google_mobile_ads: ^9.0.0`, `AdHelper.bannerAdUnitId` (test ID from `lib/add/ad_helper.dart`).

## Global Constraints

- Use `AdHelper.bannerAdUnitId` from `lib/add/ad_helper.dart` as the ad unit ID.
- Ad size is `AdSize.banner` (320x50); display scale is 0.5 (renders at 160x25).
- Title and subtitle must remain left-aligned; the banner must not push any content below the header downward.
- The `HeaderBannerAd` widget must not crash when the platform is unsupported (e.g., during host-side tests) or when the ad plugin is unavailable.
- When no ad is loaded, render `const SizedBox.shrink()` (header looks exactly as today).
- No comments in code unless the existing file style requires them.

---

### Task 1: `ScaledBannerAd` widget

**Files:**
- Create: `lib/widgets/scaled_banner_ad.dart`
- Test: `test/scaled_banner_ad_test.dart`

**Interfaces:**
- Produces: `ScaledBannerAd` — `const ScaledBannerAd({super.key, required double width, required double height, double scale = 0.5, required Widget child})`. Renders a `SizedBox` of size `(width*scale, height*scale)` containing a `FittedBox` that fits a `SizedBox` of natural size `(width, height)` holding `child`. Used by Task 2.

- [ ] **Step 1: Write the failing test**

Create `test/scaled_banner_ad_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/scaled_banner_ad.dart';

void main() {
  testWidgets('renders child scaled down by the given scale', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ScaledBannerAd(
              width: 320,
              height: 50,
              scale: 0.5,
              child: SizedBox(
                width: 320,
                height: 50,
                child: ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(ScaledBannerAd));
    expect(size.width, 160);
    expect(size.height, 25);

    final naturalBox = find.descendant(
      of: find.byType(ScaledBannerAd),
      matching: find.byWidgetPredicate(
        (widget) => widget is SizedBox &&
            widget.width == 320 &&
            widget.height == 50,
      ),
    );
    expect(naturalBox, findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/scaled_banner_ad_test.dart`
Expected: FAIL — "Could not find the file" / "Target of URI doesn't exist: 'package:my_app/widgets/scaled_banner_ad.dart'".

- [ ] **Step 3: Write minimal implementation**

Create `lib/widgets/scaled_banner_ad.dart`:

```dart
import 'package:flutter/material.dart';

class ScaledBannerAd extends StatelessWidget {
  const ScaledBannerAd({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    this.scale = 0.5,
  });

  final double width;
  final double height;
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width * scale,
      height: height * scale,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/scaled_banner_ad_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/scaled_banner_ad.dart test/scaled_banner_ad_test.dart
git commit -m "feat: add scaled banner ad layout widget"
```

---

### Task 2: `HeaderBannerAd` widget

**Files:**
- Create: `lib/widgets/header_banner_ad.dart`
- Test: `test/header_banner_ad_test.dart`

**Interfaces:**
- Consumes: `ScaledBannerAd` from Task 1 (`ScaledBannerAd(width: 320, height: 50, child: AdWidget(ad: _bannerAd!))`).
- Produces: `HeaderBannerAd` — `const HeaderBannerAd({super.key})`. A `StatefulWidget` that loads a `BannerAd` in `initState`, disposes it in `dispose`, and renders `const SizedBox.shrink()` until an ad is loaded, then a `ScaledBannerAd`. Consumed by Task 3.

- [ ] **Step 1: Write the failing test**

Create `test/header_banner_ad_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/header_banner_ad.dart';
import 'package:my_app/widgets/scaled_banner_ad.dart';

void main() {
  testWidgets('renders nothing while no ad is loaded', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: HeaderBannerAd())),
      ),
    );
    await tester.pump();

    expect(find.byType(HeaderBannerAd), findsOneWidget);
    expect(find.byType(ScaledBannerAd), findsNothing);

    final size = tester.getSize(find.byType(HeaderBannerAd));
    expect(size.width, 0);
    expect(size.height, 0);
  });
}
```

Note: `HeaderBannerAd` must gracefully tolerate the host test environment, where `AdHelper.bannerAdUnitId` throws `UnsupportedError` (tests run on the host, not Android/iOS). The implementation below catches that so the widget renders empty instead of throwing.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/header_banner_ad_test.dart`
Expected: FAIL — "Target of URI doesn't exist: 'package:my_app/widgets/header_banner_ad.dart'".

- [ ] **Step 3: Write minimal implementation**

Create `lib/widgets/header_banner_ad.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:my_app/add/ad_helper.dart';
import 'package:my_app/widgets/scaled_banner_ad.dart';

class HeaderBannerAd extends StatefulWidget {
  const HeaderBannerAd({super.key});

  @override
  State<HeaderBannerAd> createState() => _HeaderBannerAdState();
}

class _HeaderBannerAdState extends State<HeaderBannerAd> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  Future<void> _loadBannerAd() async {
    String adUnitId;
    try {
      adUnitId = AdHelper.bannerAdUnitId;
    } catch (_) {
      return;
    }

    final ad = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _bannerAd = ad;
            });
          }
        },
        onAdFailedToLoad: (failedAd, error) {
          failedAd.dispose();
        },
      ),
    );

    try {
      await ad.load();
    } catch (_) {
      ad.dispose();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (ad == null) {
      return const SizedBox.shrink();
    }
    return ScaledBannerAd(
      width: 320,
      height: 50,
      child: AdWidget(ad: ad),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/header_banner_ad_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/header_banner_ad.dart test/header_banner_ad_test.dart
git commit -m "feat: add header banner ad widget"
```

---

### Task 3: Mount banner in home timer header

**Files:**
- Modify: `lib/widgets/home_timer_layout.dart:1` (add import), `lib/widgets/home_timer_layout.dart:131` (append banner after the `Expanded` title column)

**Interfaces:**
- Consumes: `HeaderBannerAd` from Task 2.

- [ ] **Step 1: Add the import**

In `lib/widgets/home_timer_layout.dart`, add after the existing imports (line 5):

```dart
import 'package:my_app/widgets/header_banner_ad.dart';
```

- [ ] **Step 2: Add the banner to the header row**

In `lib/widgets/home_timer_layout.dart`, find the header `Row` (starts at line 73). It contains an optional back-button block and then the `Expanded` title column that closes at line 131 with `),`. Insert the banner right after that closing `),`, so the header `Row` becomes:

```dart
          Row(
            children: [
              if (canPop)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: onBackPressed,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    tooltip: 'Back to Home',
                  ),
                ),
              if (canPop) const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Immersive Workout Timer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      headerSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const HeaderBannerAd(),
            ],
          ),
```

Only the two lines `const SizedBox(width: 10),` and `const HeaderBannerAd(),` are new; the rest is the existing row unchanged.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: All tests PASS (the pre-existing `widget_test.dart` and `builder_builds_test.dart`, plus the two new test files).

- [ ] **Step 4: Run static analysis**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/home_timer_layout.dart
git commit -m "feat: show small banner ad in home timer header"
```
