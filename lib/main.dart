import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_constants.dart';
import 'core/app_theme.dart';
import 'features/home/home_controller.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_controller.dart';
import 'services/auth_service/biometric_service.dart';
import 'services/intent_service/intent_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool setupCompleted = prefs.getBool('setupCompleted') ?? false;
  final bool appLockEnabled = prefs.getBool('appLockEnabled') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsController()),
        ChangeNotifierProvider(create: (_) => HomeController()),
      ],
      child: TKOfficeApp(
        setupCompleted: setupCompleted,
        appLockEnabled: appLockEnabled,
      ),
    ),
  );
}

class TKOfficeApp extends StatefulWidget {
  final bool setupCompleted;
  final bool appLockEnabled;

  const TKOfficeApp({
    super.key,
    this.setupCompleted = true,
    this.appLockEnabled = false,
  });

  @override
  State<TKOfficeApp> createState() => _TKOfficeAppState();
}

class _TKOfficeAppState extends State<TKOfficeApp> {
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    _isUnlocked = !widget.appLockEnabled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      IntentService.initialize(navigatorKey);
      if (widget.appLockEnabled && !_isUnlocked) {
        _promptBiometrics();
      }
    });
  }

  Future<void> _promptBiometrics() async {
    final success = await BiometricService.authenticate();
    if (success && mounted) {
      setState(() => _isUnlocked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsController = Provider.of<SettingsController>(context);

    Widget homeWidget;
    if (!widget.setupCompleted) {
      homeWidget = const OnboardingScreen();
    } else if (widget.appLockEnabled && !_isUnlocked) {
      homeWidget = Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fingerprint_rounded, size: 84, color: AppTheme.primaryBlue),
              const SizedBox(height: 20),
              const Text('TK Office Locked', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Authenticate with fingerprint or PIN to continue', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Unlock'),
                onPressed: _promptBiometrics,
              ),
            ],
          ),
        ),
      );
    } else {
      homeWidget = const HomeScreen();
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsController.settings.themeMode,
      home: homeWidget,
    );
  }
}
