import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static const MethodChannel _channel = MethodChannel('com.tk.tk_office/auth');
  static const String _keyAppLock = 'appLockEnabled';
  static const String _keyVaultPin = 'vaultPin';

  static Future<bool> canAuthenticate() async {
    try {
      final canAuth = await _channel.invokeMethod<bool>('canAuthenticate');
      return canAuth ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate({
    String title = 'Unlock TK Office',
    String subtitle = 'Verify fingerprint or screen lock to proceed',
  }) async {
    try {
      final success = await _channel.invokeMethod<bool>('authenticate', {
        'title': title,
        'subtitle': subtitle,
      });
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isAppLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAppLock) ?? false;
  }

  static Future<void> setAppLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAppLock, enabled);
  }

  static Future<String?> getVaultPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVaultPin);
  }

  static Future<void> setVaultPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVaultPin, pin);
  }
}
