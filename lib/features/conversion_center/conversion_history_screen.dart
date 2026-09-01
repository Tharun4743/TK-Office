import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/file_service/file_service.dart';
import '../../services/routing/document_router.dart';
import '../../storage/conversion_history_dao.dart';
import '../../utils/file_utils.dart';

class ConversionHistoryScreen extends StatefulWidget {
  const ConversionHistoryScreen({super.key});

  @override
  State<ConversionHistoryScreen> createState() => _ConversionHistoryScreenState();
}

class _ConversionHistoryScreenState extends State<ConversionHistoryScreen> {
  final _dao = ConversionHistoryDao();
  List<ConversionHistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final items = await _dao.getAllHistory();
    if (mounted) {
      setState(() {
        _history = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversion History', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear History',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear History?'),
                    content: const Text('This will clear the history logs. Converted files on disk will NOT be deleted.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _dao.clearHistory();
                  _loadHistory();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 72, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No conversion history yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      const Text('Converted files will appear here', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final fileExists = File(item.targetPath).existsSync();

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: item.isSuccess ? AppTheme.primaryBlue.withAlpha(30) : Colors.red.withAlpha(30),
                        child: Icon(
                          item.isSuccess ? Icons.swap_horiz_rounded : Icons.error_outline_rounded,
                          color: item.isSuccess ? AppTheme.primaryBlue : Colors.red,
                        ),
                      ),
                      title: Text(
                        '${item.sourceName} → ${item.targetName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${item.conversionType} • ${item.isSuccess ? (fileExists ? FileUtils.formatFileSize(item.fileSize) : "File moved/deleted") : "Failed"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: item.isSuccess ? Colors.grey : Colors.red,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (fileExists) ...[
                            IconButton(
                              icon: const Icon(Icons.share_outlined, size: 20),
                              onPressed: () => FileService().shareFile(item.targetPath),
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_new_rounded, size: 20, color: AppTheme.primaryBlue),
                              onPressed: () => DocumentRouter.routeDocument(context, item.targetPath),
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                            onPressed: () async {
                              if (item.id != null) {
                                await _dao.deleteHistoryItem(item.id!);
                                _loadHistory();
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
