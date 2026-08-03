import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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
  // ✅ Initialize AdMob only on Android/iOS
  if (Platform.isAndroid || Platform.isIOS) {
    await MobileAds.instance.initialize();
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

  await ConnectivityService.instance.initialize();

  if (!authService.hasFirebaseSession) {
    if (ConnectivityService.instance.isOnline) {
      try {
        await authService.signInAnonymously();
      } catch (_) {
        debugPrint('[main] Firebase Auth unavailable, using local UID fallback');
      }
    } else {
      debugPrint('[main] Offline — skipping anonymous sign-in, using local UID fallback');
    }
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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

  assert(() {
    if (GeminiConfig.isConfigured) {
      debugPrint('Gemini voice-over key is configured.');
    } else {
      debugPrint('Gemini voice-over key is missing.');
    }
    return true;
  }());

  runApp(MyApp(authService: authService));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    DeepLinkService.instance.init(navigatorKey);
  });
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
