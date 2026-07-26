import 'package:flutter/material.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/services/notification_service.dart';
import 'package:my_app/pages/user_profile_page.dart';
import 'package:my_app/pages/workout_schedule_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notifService = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _notifService.addListener(_onChanged);
  }

  @override
  void dispose() {
    _notifService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onNotificationTap(AppNotification notif) async {
    if (!notif.isRead) {
      await _notifService.markAsRead(notif.id);
    }
    if (!mounted) return;

    switch (notif.type) {
      case NotificationType.like:
      case NotificationType.comment:
      case NotificationType.download:
        await Navigator.of(context).pushNamed('/community');
      case NotificationType.follow:
        if (notif.targetId != null && notif.targetId!.isNotEmpty) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserProfilePage(creatorId: notif.targetId!),
            ),
          );
        }
      case NotificationType.achievement:
        await Navigator.of(context).pushNamed('/profile');
    }
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.like: return Icons.favorite_rounded;
      case NotificationType.follow: return Icons.person_add_rounded;
      case NotificationType.comment: return Icons.chat_bubble_rounded;
      case NotificationType.download: return Icons.download_rounded;
      case NotificationType.achievement: return Icons.workspace_premium_rounded;
    }
  }

  Color _colorForType(NotificationType type) {
    switch (type) {
      case NotificationType.like: return const Color(0xFFFF5A5F);
      case NotificationType.follow: return const Color(0xFF2AB7CA);
      case NotificationType.comment: return const Color(0xFFFF8A1E);
      case NotificationType.download: return const Color(0xFF6BCB77);
      case NotificationType.achievement: return const Color(0xFFFFD37A);
    }
  }

  String _actionText(NotificationType type) {
    switch (type) {
      case NotificationType.like: return 'liked your workout';
      case NotificationType.follow: return 'followed you';
      case NotificationType.comment: return 'commented on your workout';
      case NotificationType.download: return 'saved your workout';
      case NotificationType.achievement: return 'achievement unlocked';
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notifService.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        backgroundColor: const Color(0xFF101A2B),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WorkoutSchedulePage()),
              );
            },
            icon: Icon(Icons.calendar_month_rounded, size: 22),
            tooltip: 'Workout schedule',
            color: Colors.white.withValues(alpha: 0.6),
          ),
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () => _notifService.markAllAsRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF141B2D), Color(0xFF0A1020), Color(0xFF1A2439)],
          ),
        ),
        child: notifications.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 56, color: Colors.white.withValues(alpha: 0.2)),
                    const SizedBox(height: 12),
                    Text('No activity yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return _NotificationTile(
                    notification: notif,
                    icon: _iconForType(notif.type),
                    color: _colorForType(notif.type),
                    actionText: _actionText(notif.type),
                    timeAgo: _timeAgo(notif.createdAt),
                    onTap: () => _onNotificationTap(notif),
                  );
                },
              ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.icon,
    required this.color,
    required this.actionText,
    required this.timeAgo,
    required this.onTap,
  });

  final AppNotification notification;
  final IconData icon;
  final Color color;
  final String actionText;
  final String timeAgo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead
                ? Colors.white.withValues(alpha: 0.06)
                : color.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 14, color: Colors.white),
                            children: [
                              TextSpan(
                                text: notification.actorUsername,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text: ' $actionText',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeAgo,
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
