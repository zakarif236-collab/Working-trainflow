### Task 5: HomePage — Disable Community Card When Offline

**Files:**
- Modify: `lib/pages/home_page.dart`

**Interfaces:**
- Consumes: `ConnectivityService.instance.isOnline`
- Produces: Community card visually disabled when offline

**Changes:**

1. Add import at top:

```dart
import 'package:my_app/services/connectivity_service.dart';
```

2. Replace the Community `_ModCard` to use dynamic subtitle and null onTap when offline:

```dart
_ModCard(
  title: 'Community',
  subtitle: ConnectivityService.instance.isOnline
      ? 'Share & discover'
      : 'Sign in when online',
  icon: Icons.public_rounded,
  gradient: const [Color(0xFFF97316), Color(0xFFF5A97D)],
  onTap: ConnectivityService.instance.isOnline
      ? () => _openCommunity(context)
      : null,
),
```

Run `dart analyze lib/pages/home_page.dart`
Commit: `feat: disable Community card when offline`
