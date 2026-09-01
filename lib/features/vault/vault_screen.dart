import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../services/auth_service/biometric_service.dart';
import '../../services/routing/document_router.dart';
import '../../shared/widgets/tk_dialogs.dart';
import '../../utils/date_utils.dart';
import '../../utils/file_utils.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  bool _isAuthenticated = false;
  final List<File> _vaultFiles = [];
  bool _isLoading = true;
  String? _vaultDirPath;

  @override
  void initState() {
    super.initState();
    _authenticateAndLoad();
  }

  Future<void> _authenticateAndLoad() async {
    final canBiometric = await BiometricService.canAuthenticate();
    if (canBiometric) {
      final success = await BiometricService.authenticate(
        title: 'Unlock Private Vault',
        subtitle: 'Confirm your biometric or PIN to open vault',
      );
      if (success) {
        setState(() => _isAuthenticated = true);
        await _loadVaultDirectory();
        return;
      }
    }

    // Fallback PIN if biometric fails or cancelled
    final savedPin = await BiometricService.getVaultPin();
    if (savedPin == null) {
      // First time vault setup
      if (mounted) {
        final newPin = await TKDialogs.showNameInputDialog(
          context: context,
          title: 'Create Vault PIN',
          initialValue: '',
          actionLabel: 'Set PIN',
        );
        if (newPin != null && newPin.isNotEmpty) {
          await BiometricService.setVaultPin(newPin);
          setState(() => _isAuthenticated = true);
          await _loadVaultDirectory();
          return;
        } else {
          if (mounted) Navigator.pop(context);
        }
      }
    } else {
      if (mounted) {
        final enteredPin = await TKDialogs.showNameInputDialog(
          context: context,
          title: 'Enter Vault PIN',
          initialValue: '',
          actionLabel: 'Unlock',
        );
        if (enteredPin == savedPin) {
          setState(() => _isAuthenticated = true);
          await _loadVaultDirectory();
          return;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Incorrect PIN')),
            );
            Navigator.pop(context);
          }
        }
      }
    }
  }

  Future<void> _loadVaultDirectory() async {
    setState(() => _isLoading = true);
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(appDir.path, 'tk_vault'));
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    _vaultDirPath = vaultDir.path;

    _vaultFiles.clear();
    final list = vaultDir.listSync();
    for (final e in list) {
      if (e is File) {
        _vaultFiles.add(e);
      }
    }
    _vaultFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _importFileToVault() async {
    final result = await FilePicker.pickFiles();
    if (result.isNotEmpty && result.first.path != null) {
      final sourceFile = File(result.first.path!);
      final fileName = p.basename(sourceFile.path);
      final destPath = p.join(_vaultDirPath!, fileName);
      await sourceFile.copy(destPath);
      await _loadVaultDirectory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ "$fileName" moved to Private Vault')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Private Vault')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 72, color: Colors.amber),
              const SizedBox(height: 16),
              const Text('Vault Locked', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Unlock Vault'),
                onPressed: _authenticateAndLoad,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text('Private Vault', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_moderator_rounded),
            tooltip: 'Import Document into Vault',
            onPressed: _importFileToVault,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vaultFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_open_rounded, size: 64, color: theme.colorScheme.onSurface.withAlpha(70)),
                      const SizedBox(height: 12),
                      const Text('Your Private Vault is Empty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Tap the button below to store confidential files here.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Document to Vault'),
                        onPressed: _importFileToVault,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _vaultFiles.length,
                  itemBuilder: (context, index) {
                    final file = _vaultFiles[index];
                    final cat = FileUtils.getCategory(file.path);
                    final color = FileUtils.getCategoryColor(cat);
                    final icon = FileUtils.getCategoryIcon(cat);
                    final stat = file.statSync();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withAlpha(isDark ? 50 : 25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        title: Text(p.basename(file.path), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('${FileUtils.formatFileSize(stat.size)} • ${DateUtilsFormatter.formatRelative(stat.modified)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          onPressed: () async {
                            final confirm = await TKDialogs.confirmDelete(context: context, itemName: p.basename(file.path));
                            if (confirm == true) {
                              await file.delete();
                              _loadVaultDirectory();
                            }
                          },
                        ),
                        onTap: () => DocumentRouter.routeDocument(context, file.path),
                      ),
                    );
                  },
                ),
    );
  }
}
