import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsProvider extends ChangeNotifier {
  static const _key = 'app_settings';
  AppSettings _settings = AppSettings();

  AppSettings get settings => _settings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json != null) {
      try {
        _settings = AppSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
      } catch (_) {
        _settings = AppSettings();
      }
    }
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    await updateSettings(AppSettings());
  }
}
