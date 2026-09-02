import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_constants.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service/biometric_service.dart';
import '../../services/intent_service/intent_service.dart';
import '../../services/storage_service/local_storage_service.dart';
import '../../shared/widgets/tk_dialogs.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settingsController = Provider.of<SettingsController>(context);
    final settings = settingsController.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section: Appearance
          _buildSectionHeader(context, 'Appearance', Icons.palette_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: RadioGroup<ThemeMode>(
                groupValue: settings.themeMode,
                onChanged: (mode) {
                  if (mode != null) settingsController.updateThemeMode(mode);
                },
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: const Text('System Default'),
                      subtitle: const Text('Matches your Android device theme'),
                      value: ThemeMode.system,
                    ),
                    const Divider(indent: 16, endIndent: 16, height: 1),
                    RadioListTile<ThemeMode>(
                      title: const Text('Light Mode'),
                      value: ThemeMode.light,
                    ),
                    const Divider(indent: 16, endIndent: 16, height: 1),
                    RadioListTile<ThemeMode>(
                      title: const Text('Dark Mode'),
                      value: ThemeMode.dark,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section: Editor Defaults
          _buildSectionHeader(context, 'Editor Defaults', Icons.tune_rounded),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Default Font Size'),
                  subtitle: Text('${settings.defaultFontSize.toInt()} pt'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: settings.defaultFontSize > 10
                            ? () => settingsController.updateFontSize(settings.defaultFontSize - 1)
                            : null,
                      ),
                      Text(
                        '${settings.defaultFontSize.toInt()}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: settings.defaultFontSize < 32
                            ? () => settingsController.updateFontSize(settings.defaultFontSize + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
                const Divider(indent: 16, endIndent: 16, height: 1),
                SwitchListTile(
                  title: const Text('Automatic Local Autosave'),
                  subtitle: Text(
                    settings.autosaveEnabled
                        ? 'Saves recovery copy every ${settings.autosaveIntervalSeconds}s'
                        : 'Autosave disabled',
                  ),
                  value: settings.autosaveEnabled,
                  activeThumbColor: AppTheme.primaryBlue,
                  onChanged: (val) => settingsController.toggleAutosave(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Security & Privacy
          _buildSectionHeader(context, 'Security & Biometrics', Icons.security_rounded),
          Card(
            child: Column(
              children: [
          const _BiometricTile(),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Permissions
          _buildSectionHeader(context, 'Permissions & Storage', Icons.verified_user_outlined),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_shared_outlined, color: AppTheme.primaryBlue),
                  title: const Text('Storage & File Access'),
                  subtitle: const Text('Configured via Android Storage Access Framework (SAF)'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(isDark ? 50 : 25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '✓ Active',
                      style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const Divider(indent: 16, endIndent: 16, height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_none_rounded, color: Colors.amber),
                  title: const Text('Local Status Notifications'),
                  subtitle: const Text('File conversions & export alerts'),
                  trailing: TextButton(
                    onPressed: () => IntentService.requestNotificationPermission(),
                    child: const Text('Manage'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Local Storage
          _buildSectionHeader(context, 'Local Storage & Privacy', Icons.security_rounded),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded, color: Colors.amber),
                  title: const Text('Clear Recovery Cache'),
                  subtitle: const Text('Removes temporary recovery backups'),
                  onTap: () async {
                    final recoveryDir = await LocalStorageService.instance.getRecoveryDirectory();
                    if (await recoveryDir.exists()) {
                      for (final file in recoveryDir.listSync()) {
                        if (file is File) file.deleteSync();
                      }
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recovery cache cleared successfully')),
                      );
                    }
                  },
                ),
                const Divider(indent: 16, endIndent: 16, height: 1),
                const ListTile(
                  leading: Icon(Icons.cloud_off_rounded, color: Colors.green),
                  title: Text('100% Offline Mode Active'),
                  subtitle: Text('No network connections, zero telemetry, zero analytics'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: About
          _buildSectionHeader(context, 'About', Icons.info_outline_rounded),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          AppConstants.appLogoAsset,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConstants.appName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppConstants.appTagline,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color?.withAlpha(180),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Version ${AppConstants.appVersion}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Created by',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        AppConstants.authorName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Author Portfolio Link
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => IntentService.openUrl(AppConstants.authorWebsite),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.language_rounded, size: 18, color: AppTheme.primaryBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppConstants.authorWebsite,
                              style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.open_in_new_rounded, size: 14, color: AppTheme.primaryBlue),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Author Email Link
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => IntentService.openUrl('mailto:${AppConstants.authorEmail}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 18, color: AppTheme.primaryBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppConstants.authorEmail,
                              style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.send_rounded, size: 14, color: AppTheme.primaryBlue),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                    ),
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('Open Source Licenses'),
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: AppConstants.appName,
                        applicationVersion: AppConstants.appVersion,
                        applicationIcon: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            AppConstants.appLogoAsset,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Biometric toggle as a proper StatefulWidget to avoid
//     the illegal (context as Element).markNeedsBuild() pattern.
class _BiometricTile extends StatefulWidget {
  const _BiometricTile();

  @override
  State<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends State<_BiometricTile> {
  bool _isEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await BiometricService.isAppLockEnabled();
    if (mounted) setState(() { _isEnabled = enabled; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ListTile(
        leading: Icon(Icons.fingerprint_rounded, color: AppTheme.primaryBlue),
        title: Text('Biometric App Lock'),
        trailing: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryBlue),
          title: const Text('Biometric App Lock'),
          subtitle: const Text('Require fingerprint/face to open TK Office'),
          value: _isEnabled,
          activeThumbColor: AppTheme.primaryBlue,
          onChanged: (val) async {
            final messenger = ScaffoldMessenger.of(context);
            if (val) {
              final canAuth = await BiometricService.canAuthenticate();
              if (!mounted) return;
              if (!canAuth) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('No biometric sensor / PIN found on device')),
                );
                return;
              }
              final success = await BiometricService.authenticate(
                title: 'Enable Biometric Lock',
                subtitle: 'Confirm your identity',
              );
              if (!mounted) return;
              if (success) {
                await BiometricService.setAppLockEnabled(true);
                if (mounted) setState(() => _isEnabled = true);
              }
            } else {
              await BiometricService.setAppLockEnabled(false);
              if (mounted) setState(() => _isEnabled = false);
            }
          },
        ),
        const Divider(indent: 16, endIndent: 16, height: 1),
        ListTile(
          leading: const Icon(Icons.shield_rounded, color: Colors.amber),
          title: const Text('Private Vault PIN'),
          subtitle: const Text('Change your 4-digit vault security PIN'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final newPin = await TKDialogs.showNameInputDialog(
              context: context,
              title: 'Set Vault PIN',
              initialValue: '',
              actionLabel: 'Save PIN',
            );
            if (!mounted) return;
            if (newPin != null && newPin.isNotEmpty) {
              await BiometricService.setVaultPin(newPin);
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('✓ Private Vault PIN updated')),
              );
            }
          },
        ),
      ],
    );
  }
}
