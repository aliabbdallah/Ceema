import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum HapticIntensity {
  light,
  medium,
  heavy,
  selection,
  success,
  warning,
  error,
}

class HapticService {
  static final HapticService _instance = HapticService._internal();
  bool _isEnabled = true;

  factory HapticService() {
    return _instance;
  }

  HapticService._internal();

  bool get isEnabled => _isEnabled;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  Future<void> vibrate(HapticIntensity intensity) async {
    if (!_isEnabled) return;

    try {
      switch (intensity) {
        case HapticIntensity.light:
          await HapticFeedback.lightImpact();
          break;
        case HapticIntensity.medium:
          await HapticFeedback.mediumImpact();
          break;
        case HapticIntensity.heavy:
          await HapticFeedback.heavyImpact();
          break;
        case HapticIntensity.selection:
          await HapticFeedback.selectionClick();
          break;
        case HapticIntensity.success:
          await HapticFeedback.vibrate();
          break;
        case HapticIntensity.warning:
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.mediumImpact();
          break;
        case HapticIntensity.error:
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.heavyImpact();
          break;
      }
    } catch (e) {
      debugPrint('Haptic feedback error: $e');
    }
  }

  // Convenience methods for common haptic patterns
  Future<void> success() => vibrate(HapticIntensity.success);
  Future<void> warning() => vibrate(HapticIntensity.warning);
  Future<void> error() => vibrate(HapticIntensity.error);
  Future<void> selection() => vibrate(HapticIntensity.selection);
  Future<void> light() => vibrate(HapticIntensity.light);
  Future<void> medium() => vibrate(HapticIntensity.medium);
  Future<void> heavy() => vibrate(HapticIntensity.heavy);
}
