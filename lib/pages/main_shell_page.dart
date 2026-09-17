import 'package:flutter/material.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/pages/auth_page.dart';
import 'package:my_app/pages/first_page.dart';
import 'package:my_app/pages/home_page.dart';
import 'package:my_app/pages/home_timer_page.dart';
import 'package:my_app/pages/notifications_page.dart';
import 'package:my_app/pages/onboarding_sheet.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/notification_service.dart';
import 'package:my_app/services/reminder_service.dart';
import 'package:my_app/services/settings_service.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _selectedIndex = 0;
  WorkoutConfig? _pendingWorkoutConfig;
  int _homeTimerKey = 0;
  final AuthService _authService = AuthService();
  final NotificationService _notifService = NotificationService.instance;
  int _badgeCount = 0;

  @override
  void initState() {
    super.initState();
    _rescheduleWorkoutReminders();
    _notifService.addListener(_onNotificationsChanged);
    _notifService.load();
    OnboardingSheet.showIfNeeded(context, _authService);
  }

  @override
  void dispose() {
    _notifService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) {
      setState(() => _badgeCount = _notifService.unreadCount);
    }
  }

  Future<void> _rescheduleWorkoutReminders() async {
    try {
      final schedule = await SettingsService().loadWorkoutSchedule();
      await ReminderService.instance.scheduleWeeklyNotifications(schedule);
    } catch (_) {}
  }

  void _switchToTimerWithConfig(WorkoutConfig config) {
    setState(() {
      _pendingWorkoutConfig = config;
      _selectedIndex = 0;
    });
  }

  Future<void> _onTabSelected(int index) async {
    if (index == 3) {
      if (!_authService.hasFirebaseSession) {
        final signedIn = await AuthPage.showAsSheet(context);
        if (signedIn != true || !mounted) return;
        OnboardingSheet.showIfNeeded(context, _authService);
      }
    }
    setState(() {
      if (index == 0) {
        _homeTimerKey++;
        _pendingWorkoutConfig = null;
      }
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeTimerPage(key: ValueKey(_homeTimerKey), pendingConfig: _pendingWorkoutConfig),
      HomePage(
        onStartTraining: _switchToTimerWithConfig,
      ),
      const NotificationsPage(),
      FirstPage(
        onBackPressed: () {
          setState(() {
            _selectedIndex = 0;
          });
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF141B2D),
        surfaceTintColor: Colors.transparent,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onTabSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Mods',
          ),
          NavigationDestination(
            icon: _badgeCount > 0
                ? Badge(
                    label: Text('$_badgeCount'),
                    child: const Icon(Icons.notifications_outlined),
                  )
                : const Icon(Icons.notifications_outlined),
            selectedIcon: _badgeCount > 0
                ? Badge(
                    label: Text('$_badgeCount'),
                    child: const Icon(Icons.notifications_rounded),
                  )
                : const Icon(Icons.notifications_rounded),
            label: 'Activity',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
