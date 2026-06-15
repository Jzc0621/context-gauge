import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../models/status_data.dart';

class StatusService extends ChangeNotifier {
  final String statusFilePath;
  StatusData? _currentStatus;
  StreamSubscription? _watcher;
  Timer? _pollTimer;
  DateTime? _lastLoad;
  bool _usePolling = false;

  StatusService(this.statusFilePath);

  StatusData? get currentStatus => _currentStatus;

  Future<void> start() async {
    await _loadStatus();
    _startWatching();
  }

  Future<void> _loadStatus() async {
    final file = File(statusFilePath);
    if (!await file.exists()) return;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return;
      final json = jsonDecode(content) as Map<String, dynamic>;
      _currentStatus = StatusData.fromJson(json);
      notifyListeners();
    } catch (_) {
      // Keep last valid state on parse error
    }
  }

  void _debounceLoad() {
    final now = DateTime.now();
    if (_lastLoad != null &&
        now.difference(_lastLoad!).inMilliseconds < 100) {
      return;
    }
    _lastLoad = now;
    _loadStatus();
  }

  void _startWatching() {
    if (_usePolling) {
      _startPolling();
      return;
    }
    try {
      final dir = Directory(File(statusFilePath).parent.path);
      _watcher = dir.watch().listen((event) {
        if (event.path == statusFilePath) {
          _debounceLoad();
        }
      });
    } catch (_) {
      _usePolling = true;
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _debounceLoad(),
    );
  }

  @override
  void dispose() {
    _watcher?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}
