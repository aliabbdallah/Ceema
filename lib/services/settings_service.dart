import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  static const String _hapticEnabledKey = 'haptic_enabled';
  bool _hapticEnabled = true;

  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  bool get hapticEnabled => _hapticEnabled;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _hapticEnabled = prefs.getBool(_hapticEnabledKey) ?? true;
  }

  Future<void> setHapticEnabled(bool enabled) async {
    _hapticEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticEnabledKey, enabled);
  }
}
