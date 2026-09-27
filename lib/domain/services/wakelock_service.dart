import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../data/providers.dart';

final keepScreenAwakeProvider = StateNotifierProvider<KeepScreenAwakeNotifier, bool>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return KeepScreenAwakeNotifier(repo);
});

class KeepScreenAwakeNotifier extends StateNotifier<bool> {
  final dynamic _settingsRepo;

  KeepScreenAwakeNotifier(this._settingsRepo) : super(true) {
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await _settingsRepo.getKeepScreenAwake();
      state = enabled;
    } catch (_) {
      state = true;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      await _settingsRepo.setKeepScreenAwake(enabled);
    } catch (e) {
      debugPrint('Failed to save keep_screen_awake setting: $e');
    }
  }
}

class WakelockService {
  static bool _isEnabled = false;

  static Future<void> syncWithWorkout({
    required bool isWorkoutActive,
    required bool keepAwakeEnabled,
  }) async {
    final shouldWake = isWorkoutActive && keepAwakeEnabled;
    if (_isEnabled == shouldWake) return;

    try {
      if (shouldWake) {
        await WakelockPlus.enable();
        _isEnabled = true;
        debugPrint('[WakelockService] Screen wakelock ENABLED for active workout');
      } else {
        await WakelockPlus.disable();
        _isEnabled = false;
        debugPrint('[WakelockService] Screen wakelock DISABLED');
      }
    } catch (e) {
      debugPrint('[WakelockService] Error updating wakelock state: $e');
    }
  }

  static Future<void> disable() async {
    if (!_isEnabled) return;
    try {
      await WakelockPlus.disable();
      _isEnabled = false;
    } catch (_) {}
  }
}
