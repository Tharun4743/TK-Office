import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_constants.dart';
import '../../core/app_theme.dart';
import '../../services/intent_service/intent_service.dart';
import '../../services/storage_scanner_service/storage_scanner_service.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final StorageScannerService _scannerService = StorageScannerService();

  int _currentStep = 0;
  bool _isStorageGranted = false;
  bool _isScanning = false;
  ScanProgress _scanProgress = ScanProgress();
  StreamSubscription<ScanProgress>? _scanSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentStep == 1) {
      _verifyPermissionAndScan();
    }
  }

  Future<void> _checkInitialPermission() async {
    final granted = await StorageScannerService.checkStoragePermission();
    if (mounted) setState(() => _isStorageGranted = granted);
  }

  Future<void> _requestStoragePermission() async {
    await StorageScannerService.requestStoragePermission();
    // After returning from Android settings, didChangeAppLifecycleState triggers verification
  }

  Future<void> _verifyPermissionAndScan() async {
    final granted = await StorageScannerService.checkStoragePermission();
    setState(() => _isStorageGranted = granted);

    if (granted && !_isScanning) {
      _startBackgroundScan();
    }
  }

  void _startBackgroundScan() {
    setState(() => _isScanning = true);

    _scanSub?.cancel();
    _scanSub = _scannerService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _scanProgress = progress;
          if (progress.isFinished) {
            _isScanning = false;
          }
        });
      }
    });

    _scannerService.scanSharedStorage();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setupCompleted', true);
    await prefs.setBool('storageAccessGranted', _isStorageGranted);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress Dots
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isActive = index == _currentStep;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.primaryBlue : (isDark ? Colors.white24 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Onboarding Wizard Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentStep = page),
                children: [
                  _buildWelcomePage(theme, isDark),
                  _buildStoragePage(theme, isDark),
                  _buildNotificationPage(theme, isDark),
                  _buildFinishPage(theme, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Welcome Page
  Widget _buildWelcomePage(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withAlpha(isDark ? 90 : 50),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Image.asset(
                AppConstants.appLogoAsset,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppConstants.appName,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppConstants.appTagline,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 18),
          const Text(
            'Work with documents, spreadsheets, presentations, and PDFs directly on your device with complete privacy.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(isDark ? 40 : 20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade600),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.green, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Privacy First: All documents are processed 100% locally on your phone. Zero cloud uploads.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _nextPage,
              child: const Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Real Android Storage Access & Automatic Scanner Page
  Widget _buildStoragePage(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isStorageGranted ? Icons.check_circle_rounded : Icons.folder_shared_rounded,
            size: 80,
            color: _isStorageGranted ? Colors.green : AppTheme.primaryBlue,
          ),
          const SizedBox(height: 20),
          Text(
            _isStorageGranted ? 'Storage Connected' : 'Access Your Files',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _isStorageGranted
                ? 'TK Office is scanning your phone shared storage to automatically discover and index all your documents.'
                : 'TK Office needs access to files stored on your device so you can open, edit, and save documents, spreadsheets, presentations, and PDFs without manual folder selection.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Live Scan Status Box
          if (_isStorageGranted) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _isScanning ? AppTheme.primaryBlue : Colors.green),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isScanning ? 'Searching phone storage...' : '✓ Phone Storage Indexed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isScanning ? AppTheme.primaryBlue : Colors.green,
                        ),
                      ),
                      if (_isScanning)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCountBadge('📕 PDF', _scanProgress.pdfCount),
                      _buildCountBadge('📝 Docs', _scanProgress.docsCount),
                      _buildCountBadge('📊 Sheets', _scanProgress.sheetsCount),
                      _buildCountBadge('🎞 Slides', _scanProgress.slidesCount),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Discovered: ${_scanProgress.totalFiles} files',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),
          if (!_isStorageGranted) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Allow Storage Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: _requestStoragePermission,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _nextPage,
              child: const Text('Continue Without Storage'),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _nextPage,
                child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCountBadge(String label, int count) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text('$count', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // 3. Notification Permission Page
  Widget _buildNotificationPage(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_active_outlined, size: 80, color: Colors.amber.shade700),
          const SizedBox(height: 20),
          const Text(
            'Allow Notifications?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'TK Office can notify you when long-running document conversions, large PDF exports, or file operations are completed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Notifications are strictly local for export alerts. No marketing notifications are ever sent.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () async {
                await IntentService.requestNotificationPermission();
                _nextPage();
              },
              child: const Text('Allow Notifications'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _nextPage,
            child: const Text('Not Now'),
          ),
        ],
      ),
    );
  }

  // 4. Finish Page
  Widget _buildFinishPage(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 84, color: Colors.green),
          const SizedBox(height: 20),
          const Text(
            'You are All Set!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'TK Office is configured and ready for 100% offline document editing and processing.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCheckRow('Phone Storage Documents Auto-Indexed'),
                const SizedBox(height: 8),
                _buildCheckRow('Writer, Sheets & Slides ready'),
                const SizedBox(height: 8),
                _buildCheckRow('Real PDF Editor & Page Manager ready'),
                const SizedBox(height: 8),
                _buildCheckRow('Conversion Center & Offline Utilities ready'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Author Signature & Links
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () => IntentService.openUrl(AppConstants.authorWebsite),
                child: const Text(
                  'Portfolio',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const Text(' • ', style: TextStyle(color: Colors.grey)),
              InkWell(
                onTap: () => IntentService.openUrl('mailto:${AppConstants.authorEmail}'),
                child: const Text(
                  'Contact Developer',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _completeSetup,
              child: const Text('Start Using TK Office', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(String text) {
    return Row(
      children: [
        const Icon(Icons.task_alt_rounded, size: 18, color: Colors.green),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ],
    );
  }
}
