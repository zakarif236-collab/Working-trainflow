import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/services/connectivity_service.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isOffline = false;
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    _isOffline = !ConnectivityService.instance.isOnline;
    _subscription = ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (mounted) setState(() => _isOffline = !online);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFB33A3A),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'You\'re offline. Changes will sync when you\'re back online.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isOffline = false),
            child: const Icon(Icons.close, color: Colors.white54, size: 18),
          ),
        ],
      ),
    );
  }
}
