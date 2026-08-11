import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/add/ad_helper.dart';
import 'package:my_app/config/gemini_config.dart';
import 'package:my_app/pages/community_page.dart';
import 'package:my_app/pages/first_page.dart';
import 'package:my_app/pages/main_shell_page.dart';
import 'package:my_app/pages/user_profile_page.dart';
import 'package:my_app/pages/workout_builder_page.dart';
import 'package:my_app/pages/workout_builder_player_page.dart';
import 'package:my_app/pages/workout_timer_page.dart';
import 'package:my_app/firebase_options.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/connectivity_service.dart';
import 'package:my_app/services/notification_service.dart';
import 'package:my_app/services/push_notification_service.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:my_app/services/deep_link_service.dart';
import 'package:my_app/services/workout_foreground_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // ✅ Enable Firestore offline persistence so cached reads resolve without a network.
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: true);
    } catch (_) {}
  }

  try {
    await WorkoutForegroundService.cancelStaleNotifications();
  } catch (_) {}

  final authService = AuthService();
  try {
    await authService.init();
  } catch (_) {
    debugPrint('AuthService.init failed — proceeding with default state');
  }

  try {
    await ConnectivityService.instance.initialize();
  } catch (e) {
    debugPrint('[main] Connectivity init failed: $e');
  }

  // Render the first frame from cached local data immediately. Everything that
  // touches the network or waits on FirebaseAuth runs deferred in
  // _finalizeStartup so an offline cold start never shows a blank window.
  runApp(MyApp(authService: authService));
  unawaited(_finalizeStartup(authService));

  AppLifecycleListener(
    onResume: () => SettingsService().syncWorkoutProgressToFirestore(),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    DeepLinkService.instance.init(navigatorKey);
  });
}

/// Deferred startup work that must not block the first frame: session restore
/// wait (anti-clobber), conditional anonymous sign-in, AdMob, push
/// notifications, key migration, and background sync.
Future<void> _finalizeStartup(AuthService authService) async {
  if (Platform.isAndroid || Platform.isIOS) {
    await AdHelper.ensureInitialized();
  }

  if (!authService.hasFirebaseSession) {
    // Cold start: FirebaseAuth may still be restoring a cached session, so a
    // null currentUser here does not mean this device has no account. Give any
    // persisted session a chance to restore before creating a fresh anonymous
    // user — otherwise the restore can race and clobber the real account.
    if (authService.hasCachedSession) {
      try {
        await authService.waitForRestoredSession();
      } catch (_) {
        debugPrint('[main] Failed waiting for session restore');
      }
    }

    if (!authService.hasFirebaseSession) {
      if (ConnectivityService.instance.isOnline) {
        try {
          await authService
              .signInAnonymously()
              .timeout(const Duration(seconds: 8));
        } catch (_) {
          debugPrint('[main] Firebase Auth unavailable, using local UID fallback');
        }
      } else {
        debugPrint('[main] Offline — skipping anonymous sign-in, using local UID fallback');
      }
    }
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Identity is settled — move legacy per-user prefs into the account
  // namespace so local stats don't mix across accounts on this device.
  try {
    await SettingsService.migrateUserData();
  } catch (_) {
    debugPrint('[main] User-data key migration skipped');
  }

  try {
    await NotificationService.instance.load();
  } catch (_) {
    debugPrint('[main] NotificationService.load failed');
  }
  try {
    await PushNotificationService.instance.initialize().timeout(const Duration(seconds: 5));
  } catch (_) {
    debugPrint('[main] PushNotification init skipped (offline or timeout)');
  }

  // Best-effort background sync; never block anything on the network.
  unawaited(SettingsService().syncWorkoutProgressToFirestore());

  assert(() {
    if (GeminiConfig.isConfigured) {
      debugPrint('Gemini voice-over key is configured.');
    } else {
      debugPrint('Gemini voice-over key is missing.');
    }
    return true;
  }());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFFFF8A1E),
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Workout Builder',
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF090D14),
      ),
      home: const MainShellPage(),
      routes: {
        '/profile': (_) => const FirstPage(),
        '/workout': (_) => const WorkoutTimerPage(),
        '/workout-builder': (_) => const WorkoutBuilderPage(),
        '/my-workouts': (_) => const WorkoutBuilderPage(showBuilder: false),
        '/workout-builder-player': (_) => const WorkoutBuilderPlayerPage(),
        '/community': (_) => const CommunityPage(),
        '/user-profile': (_) => const UserProfilePage(creatorId: ''),
      },
    );
  }
}
