import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:my_app/services/sync_queue.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isOnline => _isOnline;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<void> initialize() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> result) {
    final online = !result.contains(ConnectivityResult.none);
    final wasOffline = !_isOnline;
    _isOnline = online;
    _controller.add(online);

    if (wasOffline && online) {
      _onReconnect();
    }
  }

  void _onReconnect() {
    try {
      SyncQueue.instance.processQueue();
    } catch (_) {}
    unawaited(SettingsService().syncWorkoutProgressToFirestore());
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
