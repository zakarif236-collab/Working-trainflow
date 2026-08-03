import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _storageKey = '_app_notifications';

  List<AppNotification> _notifications = const [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        _notifications = [];
      } else {
        final list = jsonDecode(raw) as List;
        _notifications = list
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
      }
    } catch (e) {
      _notifications = [];
      debugPrint('NotificationService: failed to load notifications: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_notifications.map((n) => n.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  Future<void> addNotification(AppNotification notification) async {
    _notifications = [notification, ..._notifications];
    await _save();
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;
    _notifications = [
      for (int i = 0; i < _notifications.length; i++)
        if (i == index) _notifications[i].copyWith(isRead: true) else _notifications[i],
    ];
    await _save();
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _notifications = [];
    await _save();
    notifyListeners();
  }

  Widget? buildNotificationIcon(IconData icon, Color color) {
    return Icon(icon, color: color, size: 20);
  }
}
