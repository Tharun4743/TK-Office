import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_settings.dart';

class SettingsController extends ChangeNotifier {
  late OfficeSettings _settings;
  bool _isLoaded = false;

  OfficeSettings get settings => _settings;
  bool get isLoaded => _isLoaded;

  SettingsController() {
    _settings = OfficeSettings();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final themeIndex = prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    final fontFamily = prefs.getString('font_family') ?? 'Roboto';
    final fontSize = prefs.getDouble('font_size') ?? 14.0;
    final autosaveInterval = prefs.getInt('autosave_interval') ?? 30;
    final autosaveEnabled = prefs.getBool('autosave_enabled') ?? true;
    final customFolder = prefs.getString('custom_folder');

    _settings = OfficeSettings(
      themeMode: ThemeMode.values[themeIndex],
      defaultFontFamily: fontFamily,
      defaultFontSize: fontSize,
      autosaveIntervalSeconds: autosaveInterval,
      autosaveEnabled: autosaveEnabled,
      customDocumentsFolder: customFolder,
    );

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  Future<void> updateFontFamily(String family) async {
    _settings = _settings.copyWith(defaultFontFamily: family);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_family', family);
  }

  Future<void> updateFontSize(double size) async {
    _settings = _settings.copyWith(defaultFontSize: size);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', size);
  }

  Future<void> updateAutosaveInterval(int seconds) async {
    _settings = _settings.copyWith(autosaveIntervalSeconds: seconds);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autosave_interval', seconds);
  }

  Future<void> toggleAutosave(bool enabled) async {
    _settings = _settings.copyWith(autosaveEnabled: enabled);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autosave_enabled', enabled);
  }
}
