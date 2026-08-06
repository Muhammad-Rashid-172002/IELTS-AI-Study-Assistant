import 'dart:async';

import 'package:flutter/widgets.dart';

class MockTimerController with WidgetsBindingObserver {
  MockTimerController({
    required this.initialSeconds,
    required this.onTick,
    required this.onTimeExpired,
  });

  final int initialSeconds;
  final ValueChanged<int> onTick;
  final VoidCallback onTimeExpired;

  Timer? _timer;
  DateTime? _deadline;
  int _remainingSeconds = 0;
  bool _running = false;

  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _running;

  void start() {
    if (_running) return;

    WidgetsBinding.instance.addObserver(this);
    _remainingSeconds = _remainingSeconds > 0
        ? _remainingSeconds
        : initialSeconds;
    _deadline = DateTime.now().add(Duration(seconds: _remainingSeconds));
    _running = true;
    _schedule();
  }

  void restore(int remainingSeconds) {
    _remainingSeconds = remainingSeconds;
  }

  void pause() {
    _timer?.cancel();
    _syncFromDeadline();
    _running = false;
  }

  void resume() {
    if (_remainingSeconds <= 0) return;
    _deadline = DateTime.now().add(Duration(seconds: _remainingSeconds));
    _running = true;
    _schedule();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
  }

  void _schedule() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncFromDeadline();

      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        _running = false;
        onTimeExpired();
      }
    });
  }

  void _syncFromDeadline() {
    final deadline = _deadline;
    if (deadline == null) return;

    _remainingSeconds = deadline
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, initialSeconds);

    onTick(_remainingSeconds);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _syncFromDeadline();
      _timer?.cancel();
      return;
    }

    if (state == AppLifecycleState.resumed && _running) {
      _syncFromDeadline();

      if (_remainingSeconds <= 0) {
        _running = false;
        onTimeExpired();
      } else {
        _deadline = DateTime.now().add(Duration(seconds: _remainingSeconds));
        _schedule();
      }
    }
  }
}
