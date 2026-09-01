import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../services/file_service/file_service.dart';
import '../../services/routing/document_router.dart';
import '../../shared/widgets/tk_dialogs.dart';
import '../../utils/date_utils.dart';
import '../../utils/file_utils.dart';

class FolderBrowserScreen extends StatefulWidget {
  final String initialPath;
  final String folderTitle;

  const FolderBrowserScreen({
    super.key,
    required this.initialPath,
    required this.folderTitle,
  });

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  late String _currentPath;
  final List<FileSystemEntity> _entities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    setState(() => _isLoading = true);
    _entities.clear();
    final dir = Directory(_currentPath);
    if (await dir.exists()) {
      try {
        final list = dir.listSync(followLinks: false);
        // Sort: directories first, then files
        list.sort((a, b) {
          final isADir = a is Directory;
          final isBDir = b is Directory;
          if (isADir && !isBDir) return -1;
          if (!isADir && isBDir) return 1;
          return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
        });
        _entities.addAll(list);
      } catch (_) {}
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _navigateTo(String path) {
    setState(() {
      _currentPath = path;
    });
    _loadDirectory();
  }

  void _navigateUp() {
    final parent = p.dirname(_currentPath);
    if (parent != _currentPath) {
      _navigateTo(parent);
    }
  }

  void _showFileOptions(File file) {
    final name = p.basename(file.path);
    final ext = p.extension(file.path);
    final stat = file.statSync();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(FileUtils.getCategoryIcon(FileUtils.getCategory(file.path)), color: FileUtils.getCategoryColor(FileUtils.getCategory(file.path))),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${FileUtils.formatFileSize(stat.size)} • ${DateUtilsFormatter.formatRelative(stat.modified)}'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Open'),
                onTap: () {
                  Navigator.pop(ctx);
                  DocumentRouter.routeDocument(context, file.path);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(ctx);
                  FileService().shareFile(file.path);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text('Rename'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final baseName = p.basenameWithoutExtension(file.path);
                  final newName = await TKDialogs.showNameInputDialog(
                    context: context,
                    title: 'Rename File',
                    initialValue: baseName,
                    actionLabel: 'Rename',
                  );
                  if (newName != null && newName.isNotEmpty) {
                    final newPath = p.join(p.dirname(file.path), '$newName$ext');
                    await file.rename(newPath);
                    _loadDirectory();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await TKDialogs.confirmDelete(context: context, itemName: name);
                  if (confirm == true) {
                    await file.delete();
                    _loadDirectory();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.folderTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              _currentPath,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadDirectory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Breadcrumb Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                  tooltip: 'Go to parent folder',
                  onPressed: _navigateUp,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.basename(_currentPath),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${_entities.length} items', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),

          // Directory Listing
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _entities.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_open_outlined, size: 64, color: theme.colorScheme.onSurface.withAlpha(80)),
                            const SizedBox(height: 12),
                            const Text('Folder is empty', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _entities.length,
                        itemBuilder: (context, index) {
                          final entity = _entities[index];
                          final isDir = entity is Directory;
                          final name = p.basename(entity.path);

                          if (isDir) {
                            return ListTile(
                              leading: const Icon(Icons.folder_rounded, color: Colors.amber, size: 36),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                              onTap: () => _navigateTo(entity.path),
                            );
                          } else if (entity is File) {
                            final cat = FileUtils.getCategory(entity.path);
                            final color = FileUtils.getCategoryColor(cat);
                            final icon = FileUtils.getCategoryIcon(cat);
                            final stat = entity.statSync();

                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withAlpha(isDark ? 50 : 25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, color: color, size: 22),
                              ),
                              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text('${FileUtils.formatFileSize(stat.size)} • ${DateUtilsFormatter.formatRelative(stat.modified)}', style: const TextStyle(fontSize: 11)),
                              onTap: () => DocumentRouter.routeDocument(context, entity.path),
                              onLongPress: () => _showFileOptions(entity),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
