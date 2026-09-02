import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../routing/document_router.dart';

class IntentService {
  static const MethodChannel _channel = MethodChannel('com.tk.tk_office/intent');
  static bool _initialized = false;

  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    if (_initialized) return;
    _initialized = true;

    // Handle initial intent when launched via Open With / Share
    _channel.invokeMethod<Map<dynamic, dynamic>>('getInitialIntent').then((data) {
      if (data != null) {
        _handleIntentData(data, navigatorKey);
      }
    });

    // Handle new intent while app is running in background
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onIntentReceived') {
        final data = call.arguments as Map<dynamic, dynamic>?;
        if (data != null) {
          _handleIntentData(data, navigatorKey);
        }
      }
    });
  }

  static void _handleIntentData(
    Map<dynamic, dynamic> data,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    final filePath = data['filePath'] as String?;
    final mimeType = data['mimeType'] as String?;
    final fileName = data['fileName'] as String?;
    final context = navigatorKey.currentContext;

    if (filePath != null && context != null) {
      DocumentRouter.routeDocument(
        context,
        filePath,
        displayName: fileName,
        mimeType: mimeType,
      );
    }
  }

  static Future<bool> checkNotificationPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('checkNotificationPermission');
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (_) {}
  }

  static Future<void> openUrl(String url) async {
    try {
      await _channel.invokeMethod('openUrl', {'url': url});
    } catch (_) {}
  }
}
