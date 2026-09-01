import 'package:flutter/material.dart';

class OfficeSettings {
  final ThemeMode themeMode;
  final String defaultFontFamily;
  final double defaultFontSize;
  final int autosaveIntervalSeconds;
  final bool autosaveEnabled;
  final String? customDocumentsFolder;

  OfficeSettings({
    this.themeMode = ThemeMode.system,
    this.defaultFontFamily = 'Roboto',
    this.defaultFontSize = 14.0,
    this.autosaveIntervalSeconds = 30,
    this.autosaveEnabled = true,
    this.customDocumentsFolder,
  });

  OfficeSettings copyWith({
    ThemeMode? themeMode,
    String? defaultFontFamily,
    double? defaultFontSize,
    int? autosaveIntervalSeconds,
    bool? autosaveEnabled,
    String? customDocumentsFolder,
  }) {
    return OfficeSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultFontFamily: defaultFontFamily ?? this.defaultFontFamily,
      defaultFontSize: defaultFontSize ?? this.defaultFontSize,
      autosaveIntervalSeconds: autosaveIntervalSeconds ?? this.autosaveIntervalSeconds,
      autosaveEnabled: autosaveEnabled ?? this.autosaveEnabled,
      customDocumentsFolder: customDocumentsFolder ?? this.customDocumentsFolder,
    );
  }
}
