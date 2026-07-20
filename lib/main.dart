import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:my_app/config/gemini_config.dart';
import 'package:my_app/pages/auth_page.dart';
import 'package:my_app/pages/community_page.dart';
import 'package:my_app/pages/first_page.dart';
import 'package:my_app/pages/main_shell_page.dart';
import 'package:my_app/pages/user_profile_page.dart';
import 'package:my_app/pages/workout_builder_page.dart';
import 'package:my_app/pages/workout_builder_player_page.dart';
import 'package:my_app/pages/workout_timer_page.dart';
import 'package:my_app/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  assert(() {
    if (GeminiConfig.isConfigured) {
      debugPrint('Gemini voice-over key is configured.');
    } else {
      debugPrint('Gemini voice-over key is missing.');
    }
    return true;
  }());

  final authService = AuthService();
  runApp(MyApp(authService: authService));
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
      debugShowCheckedModeBanner: false,
      title: 'Workout Builder',
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF090D14),
      ),
      home: StreamBuilder(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const MainShellPage();
          }
          return AuthPage(authService: authService);
        },
      ),
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
