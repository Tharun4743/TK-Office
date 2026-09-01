import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../core/app_constants.dart';
import '../../core/app_theme.dart';
import '../../models/file_info.dart';
import '../../services/autosave_service/recovery_service.dart';
import '../../services/file_service/file_service.dart';
import '../../services/routing/document_router.dart';
import '../../services/storage_scanner_service/storage_scanner_service.dart';
import '../../services/thumbnail_service/pdf_thumbnail_service.dart';
import '../../shared/widgets/tk_dialogs.dart';
import '../../storage/indexed_files_dao.dart';
import '../../utils/date_utils.dart';
import '../../utils/file_utils.dart';
import '../conversion_center/conversion_center_screen.dart';
import '../file_manager/folder_browser_screen.dart';
import '../settings/settings_screen.dart';
import '../vault/vault_screen.dart';
import 'home_controller.dart';
import 'widgets/starred_documents_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final IndexedFilesDao _indexedFilesDao = IndexedFilesDao();
  final StorageScannerService _scannerService = StorageScannerService();
  final TextEditingController _searchController = TextEditingController();

  List<LocalFileInfo> _discoveredFiles = [];
  List<LocalFileInfo> _starredFiles = [];
  List<Map<String, String>> _accessibleFolders = [];

  bool _isLoadingFiles = true;
  bool _isRescanning = false;
  bool _isGridView = false;
  bool _isMultiSelectMode = false;
  final Set<String> _selectedFilePaths = {};

  DocumentCategory? _selectedCategory;
  String? _selectedTag;
  String _searchQuery = '';

  // ── Sort
  _SortOption _currentSort = _SortOption.nameAZ;

  static const List<String> availableTags = ['Work', 'Personal', 'Finance', 'College', 'Invoices', 'Important'];

  @override
  void initState() {
    super.initState();
    _checkRecoveredFiles();
    _loadDiscoveredFiles();
    _loadStarredFiles();
    _loadAccessibleFolders();
  }

  Future<void> _checkRecoveredFiles() async {
    // Recovery check retained for future use; currently no UI action triggered
    await RecoveryService.checkRecoveredDocuments();
  }

  Future<void> _loadAccessibleFolders() async {
    final folders = await StorageScannerService.getAccessibleFolders();
    if (mounted) {
      setState(() => _accessibleFolders = folders);
    }
  }

  Future<void> _loadStarredFiles() async {
    final starred = await _indexedFilesDao.getStarredFiles();
    if (mounted) {
      setState(() => _starredFiles = starred);
    }
  }

  /// Returns _discoveredFiles filtered and sorted by _currentSort (documents only).
  List<LocalFileInfo> get _sortedFiles {
    final list = _discoveredFiles.where((f) {
      if (FileUtils.isTrashedFile(f.path) || f.name.startsWith('.')) {
        return false;
      }
      if (FileUtils.isImageFile(f.path) || f.category == DocumentCategory.other) {
        return false;
      }
      return FileUtils.isDocumentFile(f.path);
    }).toList();

    switch (_currentSort) {
      case _SortOption.nameAZ:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SortOption.nameZA:
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case _SortOption.dateNewest:
        list.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
        break;
      case _SortOption.dateOldest:
        list.sort((a, b) => a.modifiedDate.compareTo(b.modifiedDate));
        break;
      case _SortOption.sizeLargest:
        list.sort((a, b) => b.sizeInBytes.compareTo(a.sizeInBytes));
        break;
      case _SortOption.sizeSmallest:
        list.sort((a, b) => a.sizeInBytes.compareTo(b.sizeInBytes));
        break;
      case _SortOption.typeGroup:
        list.sort((a, b) => a.extension.compareTo(b.extension));
        break;
    }
    return list;
  }

  Future<void> _loadDiscoveredFiles() async {
    setState(() => _isLoadingFiles = true);
    final files = await _indexedFilesDao.getAllFiles(
      category: _selectedCategory,
      tag: _selectedTag,
      searchQuery: _searchQuery,
    );

    if (files.isEmpty && _selectedCategory == null && _selectedTag == null && _searchQuery.isEmpty) {
      await _scannerService.scanSharedStorage();
      final freshFiles = await _indexedFilesDao.getAllFiles();
      if (mounted) {
        setState(() {
          _discoveredFiles = freshFiles;
          _isLoadingFiles = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _discoveredFiles = files;
          _isLoadingFiles = false;
        });
      }
    }
  }

  Future<void> _rescanStorage() async {
    setState(() => _isRescanning = true);
    await _scannerService.scanSharedStorage();
    await _loadDiscoveredFiles();
    await _loadStarredFiles();
    await _loadAccessibleFolders();
    if (mounted) {
      setState(() => _isRescanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Storage rescan complete. Index updated.')),
      );
    }
  }

  void _onCategorySelected(DocumentCategory? category) {
    setState(() {
      _selectedCategory = category;
      _selectedTag = null;
    });
    _loadDiscoveredFiles();
  }

  void _onTagSelected(String? tag) {
    setState(() {
      _selectedTag = tag;
      _selectedCategory = null;
    });
    _loadDiscoveredFiles();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadDiscoveredFiles();
  }

  void _toggleStar(LocalFileInfo file) async {
    final newStarState = !file.isFavorite;
    await _indexedFilesDao.toggleFavorite(file.path, newStarState);
    _loadDiscoveredFiles();
    _loadStarredFiles();
  }

  void _showTagSelector(LocalFileInfo fileInfo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Assign Document Tag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('None (Remove)'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _indexedFilesDao.updateTag(fileInfo.path, null);
                        _loadDiscoveredFiles();
                      },
                    ),
                    ...availableTags.map((tag) {
                      final isSelected = fileInfo.tag == tag;
                      return ChoiceChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (_) async {
                          Navigator.pop(ctx);
                          await _indexedFilesDao.updateTag(fileInfo.path, tag);
                          _loadDiscoveredFiles();
                        },
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Multi-Select Handlers
  void _toggleMultiSelect(String path) {
    setState(() {
      if (_selectedFilePaths.contains(path)) {
        _selectedFilePaths.remove(path);
        if (_selectedFilePaths.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedFilePaths.add(path);
        _isMultiSelectMode = true;
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedFilePaths.length == _discoveredFiles.length) {
        _selectedFilePaths.clear();
        _isMultiSelectMode = false;
      } else {
        _selectedFilePaths.addAll(_discoveredFiles.map((f) => f.path));
      }
    });
  }

  Future<void> _batchDelete() async {
    final count = _selectedFilePaths.length;
    final confirm = await TKDialogs.confirmDelete(
      context: context,
      itemName: '$count selected document(s)',
    );
    if (confirm == true) {
      for (final p in _selectedFilePaths) {
        final f = File(p);
        if (await f.exists()) await f.delete();
      }
      await _indexedFilesDao.batchDelete(_selectedFilePaths.toList());
      setState(() {
        _selectedFilePaths.clear();
        _isMultiSelectMode = false;
      });
      _loadDiscoveredFiles();
      _loadStarredFiles();
    }
  }

  Future<void> _batchShare() async {
    for (final p in _selectedFilePaths) {
      await FileService().shareFile(p);
      break; // Android share sheet handles one or batch
    }
  }

  void _showFileOptions(LocalFileInfo fileInfo) {
    final file = File(fileInfo.path);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: FileUtils.getCategoryColor(fileInfo.category).withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(FileUtils.getCategoryIcon(fileInfo.category), color: FileUtils.getCategoryColor(fileInfo.category)),
                ),
                title: Text(fileInfo.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${fileInfo.folderName ?? "Storage"} • ${FileUtils.formatFileSize(fileInfo.sizeInBytes)} • ${DateUtilsFormatter.formatRelative(fileInfo.modifiedDate)}'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Open in Editor'),
                onTap: () {
                  Navigator.pop(ctx);
                  DocumentRouter.routeDocument(context, fileInfo.path);
                },
              ),
              ListTile(
                leading: Icon(fileInfo.isFavorite ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber),
                title: Text(fileInfo.isFavorite ? 'Unstar Document' : 'Star Document'),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleStar(fileInfo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.label_outline_rounded, color: Colors.teal),
                title: Text(fileInfo.tag != null ? 'Change Tag (${fileInfo.tag})' : 'Add Tag'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTagSelector(fileInfo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share File'),
                onTap: () {
                  Navigator.pop(ctx);
                  FileService().shareFile(fileInfo.path);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text('Rename'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final baseName = p.basenameWithoutExtension(fileInfo.path);
                  final newName = await TKDialogs.showNameInputDialog(
                    context: context,
                    title: 'Rename File',
                    initialValue: baseName,
                    actionLabel: 'Rename',
                  );
                  if (newName != null && newName.isNotEmpty) {
                    final newPath = p.join(p.dirname(fileInfo.path), '$newName${fileInfo.extension}');
                    if (await file.exists()) {
                      await file.rename(newPath);
                      await _indexedFilesDao.updatePath(fileInfo.path, newPath, '$newName${fileInfo.extension}');
                      _loadDiscoveredFiles();
                      _loadStarredFiles();
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('File Properties'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFileProperties(fileInfo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Delete File', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await TKDialogs.confirmDelete(context: context, itemName: fileInfo.name);
                  if (confirm == true) {
                    if (await file.exists()) {
                      await file.delete();
                    }
                    await _indexedFilesDao.deleteByPath(fileInfo.path);
                    _loadDiscoveredFiles();
                    _loadStarredFiles();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFileProperties(LocalFileInfo fileInfo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File Properties', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropRow('File Name', fileInfo.name),
            const SizedBox(height: 8),
            _buildPropRow('Category', fileInfo.category.name.toUpperCase()),
            const SizedBox(height: 8),
            if (fileInfo.tag != null) ...[
              _buildPropRow('Tag', fileInfo.tag!),
              const SizedBox(height: 8),
            ],
            _buildPropRow('Size', FileUtils.formatFileSize(fileInfo.sizeInBytes)),
            const SizedBox(height: 8),
            _buildPropRow('Modified', DateUtilsFormatter.formatFull(fileInfo.modifiedDate)),
            const SizedBox(height: 8),
            _buildPropRow('Location', fileInfo.path),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildPropRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = Provider.of<HomeController>(context);

    return Scaffold(
      // Multi-Select Top App Bar or Standard App Bar
      appBar: _isMultiSelectMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                  _isMultiSelectMode = false;
                  _selectedFilePaths.clear();
                }),
              ),
              title: Text('${_selectedFilePaths.length} selected', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              actions: [
                IconButton(
                  icon: Icon(_selectedFilePaths.length == _discoveredFiles.length ? Icons.select_all_rounded : Icons.deselect_rounded),
                  tooltip: 'Select All',
                  onPressed: _selectAll,
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'Share',
                  onPressed: _selectedFilePaths.isEmpty ? null : _batchShare,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: _selectedFilePaths.isEmpty ? null : _batchDelete,
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _rescanStorage,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Header App Bar
              if (!_isMultiSelectMode)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withAlpha(isDark ? 80 : 40),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              AppConstants.appLogoAsset,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppConstants.appName,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                AppConstants.appTagline,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.primaryBlue),
                              ),
                            ],
                          ),
                        ),
                        // Private Vault Shortcut
                        IconButton.filledTonal(
                          icon: const Icon(Icons.shield_rounded, size: 20, color: Colors.amber),
                          tooltip: 'Private Vault',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const VaultScreen()),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        // Rescan Storage Button
                        IconButton.filledTonal(
                          icon: _isRescanning
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.sync_rounded, size: 20),
                          tooltip: 'Rescan Storage',
                          onPressed: _isRescanning ? null : _rescanStorage,
                        ),
                        const SizedBox(width: 6),
                        // Conversion Center Shortcut
                        IconButton.filledTonal(
                          icon: const Icon(Icons.swap_horiz_rounded, size: 22, color: Colors.indigo),
                          tooltip: 'Conversion Center',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ConversionCenterScreen()),
                            ).then((_) => _loadDiscoveredFiles());
                          },
                        ),
                        const SizedBox(width: 6),
                        // Settings Icon
                        IconButton.filledTonal(
                          icon: const Icon(Icons.settings_outlined, size: 20),
                          tooltip: 'Settings',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SettingsScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              // 2. Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search files across phone storage...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ),

              // 3. Starred / Pinned Documents Bar (Suggestion 1)
              if (_starredFiles.isNotEmpty && _searchQuery.isEmpty)
                SliverToBoxAdapter(
                  child: StarredDocumentsBar(
                    starredFiles: _starredFiles,
                    onUnstar: _toggleStar,
                    onRefresh: _loadStarredFiles,
                  ),
                ),

              // 4. Quick Access Category Filter Chips & Document Tags
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'All Files',
                          isSelected: _selectedCategory == null && _selectedTag == null,
                          onTap: () {
                            setState(() {
                              _selectedCategory = null;
                              _selectedTag = null;
                            });
                            _loadDiscoveredFiles();
                          },
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: '📕 PDFs',
                          isSelected: _selectedCategory == DocumentCategory.pdf,
                          onTap: () => _onCategorySelected(DocumentCategory.pdf),
                          color: AppTheme.pdfRed,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: '📝 Docs',
                          isSelected: _selectedCategory == DocumentCategory.document,
                          onTap: () => _onCategorySelected(DocumentCategory.document),
                          color: AppTheme.docBlue,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: '📊 Sheets',
                          isSelected: _selectedCategory == DocumentCategory.spreadsheet,
                          onTap: () => _onCategorySelected(DocumentCategory.spreadsheet),
                          color: AppTheme.sheetGreen,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: '🎞 Slides',
                          isSelected: _selectedCategory == DocumentCategory.presentation,
                          onTap: () => _onCategorySelected(DocumentCategory.presentation),
                          color: AppTheme.slideOrange,
                        ),
                        const SizedBox(width: 8),
                        // Tags Dropdown
                        PopupMenuButton<String>(
                          initialValue: _selectedTag,
                          tooltip: 'Filter by Tag',
                          onSelected: _onTagSelected,
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: null, child: Text('Clear Tag Filter')),
                            ...availableTags.map((t) => PopupMenuItem(value: t, child: Text('🏷️ $t'))),
                          ],
                          child: Chip(
                            avatar: const Icon(Icons.label_rounded, size: 16, color: Colors.teal),
                            label: Text(_selectedTag != null ? 'Tag: $_selectedTag' : 'Tags'),
                            backgroundColor: _selectedTag != null ? Colors.teal.withAlpha(40) : null,
                            side: BorderSide(color: _selectedTag != null ? Colors.teal : Colors.grey.shade400),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Locations Section (Phone Folders)
              if (_searchQuery.isEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Locations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          icon: const Icon(Icons.folder_open_rounded, size: 16),
                          label: const Text('Browse All', style: TextStyle(fontSize: 12)),
                          onPressed: () async {
                            final root = await StorageScannerService.getRootStoragePath() ?? '/storage/emulated/0';
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FolderBrowserScreen(
                                    initialPath: root,
                                    folderTitle: 'Internal Storage',
                                  ),
                                ),
                              ).then((_) => _loadDiscoveredFiles());
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 75,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _accessibleFolders.length,
                      itemBuilder: (context, index) {
                        final folder = _accessibleFolders[index];
                        final name = folder['name'] ?? 'Folder';
                        final path = folder['path'] ?? '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FolderBrowserScreen(
                                    initialPath: path,
                                    folderTitle: name,
                                  ),
                                ),
                              ).then((_) => _loadDiscoveredFiles());
                            },
                            child: Container(
                              width: 125,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    name.contains('WhatsApp') ? Icons.mark_chat_read_rounded : Icons.folder_rounded,
                                    color: name.contains('WhatsApp') ? Colors.green : Colors.amber.shade700,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // 6. Section Header — Sort + Grid/List toggle
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'Results (${_sortedFiles.length})'
                              : 'Documents (${_sortedFiles.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      // Sort chip
                      GestureDetector(
                        onTap: _showSortSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sort_rounded, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                _currentSort.label,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Grid / List toggle
                      IconButton(
                        icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 20),
                        tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
                        onPressed: () => setState(() => _isGridView = !_isGridView),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
              ),

              // 7. Discovered Documents View (List or Visual Grid)
              _isLoadingFiles
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(36),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    )
                  : _sortedFiles.isEmpty
                      ? SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.feed_outlined, size: 54, color: theme.colorScheme.onSurface.withAlpha(70)),
                                  const SizedBox(height: 12),
                                  const Text('No documents found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text('Tap the sync button above to rescan phone storage.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        )
                      : _isGridView
                          ? SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.82,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final file = _sortedFiles[index];
                                    final isSelected = _selectedFilePaths.contains(file.path);
                                    return _buildGridCard(file, isDark, isSelected);
                                  },
                                  childCount: _sortedFiles.length,
                                ),
                              ),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final file = _sortedFiles[index];
                                    final isSelected = _selectedFilePaths.contains(file.path);
                                    return _buildListTile(file, isDark, isSelected);
                                  },
                                  childCount: _sortedFiles.length,
                                ),
                              ),
                            ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 70),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final path = await controller.pickAndOpenDocument();
          if (path != null && context.mounted) {
            DocumentRouter.routeDocument(context, path);
          }
        },
        icon: const Icon(Icons.file_open_rounded),
        label: const Text('Open File'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
    );
  }

  // Visual Grid Card with PDF Thumbnail
  Widget _buildGridCard(LocalFileInfo file, bool isDark, bool isSelected) {
    final color = FileUtils.getCategoryColor(file.category);
    final isPdf = file.category == DocumentCategory.pdf;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isSelected ? const BorderSide(color: AppTheme.primaryBlue, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (_isMultiSelectMode) {
            _toggleMultiSelect(file.path);
          } else {
            DocumentRouter.routeDocument(context, file.path);
          }
        },
        onLongPress: () => _isMultiSelectMode ? _toggleMultiSelect(file.path) : _showFileOptions(file),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withAlpha(isDark ? 50 : 25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      file.extension.toUpperCase().replaceAll('.', ''),
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_isMultiSelectMode)
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? AppTheme.primaryBlue : Colors.grey,
                      size: 20,
                    )
                  else
                    InkWell(
                      onTap: () => _toggleStar(file),
                      child: Icon(
                        file.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                        color: file.isFavorite ? Colors.amber : Colors.grey,
                        size: 20,
                      ),
                    ),
                ],
              ),
              // Thumbnail / icon area – takes all remaining vertical space
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: isPdf
                      ? _PdfThumbnailWidget(path: file.path, color: color)
                      : Center(child: Icon(FileUtils.getCategoryIcon(file.category), size: 48, color: color)),
                ),
              ),
              Text(
                file.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    file.folderName ?? 'Storage',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    FileUtils.formatFileSize(file.sizeInBytes),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Detailed List Tile
  Widget _buildListTile(LocalFileInfo file, bool isDark, bool isSelected) {
    final color = FileUtils.getCategoryColor(file.category);
    final icon = FileUtils.getCategoryIcon(file.category);

    return Card(
      elevation: isSelected ? 3 : 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? const BorderSide(color: AppTheme.primaryBlue, width: 2) : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: _isMultiSelectMode
            ? Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppTheme.primaryBlue : Colors.grey,
                size: 24,
              )
            : Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha(isDark ? 50 : 25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
        title: Text(
          file.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                file.folderName ?? 'Storage',
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
              ),
            ),
            if (file.tag != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.teal.withAlpha(isDark ? 50 : 25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  file.tag!,
                  style: const TextStyle(fontSize: 9.5, color: Colors.teal, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${FileUtils.formatFileSize(file.sizeInBytes)} • ${DateUtilsFormatter.formatRelative(file.modifiedDate)}',
                style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: _isMultiSelectMode
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      file.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                      color: file.isFavorite ? Colors.amber : Colors.grey,
                      size: 20,
                    ),
                    onPressed: () => _toggleStar(file),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onPressed: () => _showFileOptions(file),
                  ),
                ],
              ),
        onTap: () {
          if (_isMultiSelectMode) {
            _toggleMultiSelect(file.path);
          } else {
            DocumentRouter.routeDocument(context, file.path);
          }
        },
        onLongPress: () => _isMultiSelectMode ? _toggleMultiSelect(file.path) : _toggleMultiSelect(file.path),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: color.withAlpha(35),
      labelStyle: TextStyle(
        color: isSelected ? color : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.transparent,
        width: 1.2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Sort bottom sheet
  // ─────────────────────────────────────────────────────────────

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Sort Documents',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ..._SortOption.values.map((opt) {
                      final isSelected = _currentSort == opt;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() => _currentSort = opt);
                          setSheetState(() {});
                          Navigator.pop(ctx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(
                                opt.icon,
                                size: 20,
                                color: isSelected ? AppTheme.primaryBlue : Colors.grey,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  opt.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppTheme.primaryBlue : null,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_rounded, color: AppTheme.primaryBlue, size: 18),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sort option enum
// ─────────────────────────────────────────────────────────────────────────────

enum _SortOption {
  nameAZ,
  nameZA,
  dateNewest,
  dateOldest,
  sizeLargest,
  sizeSmallest,
  typeGroup,
}

extension _SortOptionExt on _SortOption {
  String get label {
    switch (this) {
      case _SortOption.nameAZ:       return 'Name: A → Z';
      case _SortOption.nameZA:       return 'Name: Z → A';
      case _SortOption.dateNewest:   return 'Date: Newest first';
      case _SortOption.dateOldest:   return 'Date: Oldest first';
      case _SortOption.sizeLargest:  return 'Size: Largest first';
      case _SortOption.sizeSmallest: return 'Size: Smallest first';
      case _SortOption.typeGroup:    return 'File type';
    }
  }

  IconData get icon {
    switch (this) {
      case _SortOption.nameAZ:       return Icons.sort_by_alpha_rounded;
      case _SortOption.nameZA:       return Icons.sort_by_alpha_rounded;
      case _SortOption.dateNewest:   return Icons.calendar_today_rounded;
      case _SortOption.dateOldest:   return Icons.calendar_today_rounded;
      case _SortOption.sizeLargest:  return Icons.data_usage_rounded;
      case _SortOption.sizeSmallest: return Icons.data_usage_rounded;
      case _SortOption.typeGroup:    return Icons.category_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  High-quality PDF thumbnail widget
//  • Renders async via FutureBuilder
//  • Fills available space with BoxFit.contain (no cropping)
//  • Shows fallback icon on failure
// ─────────────────────────────────────────────────────────────────────────────

class _PdfThumbnailWidget extends StatelessWidget {
  final String path;
  final Color color;

  const _PdfThumbnailWidget({required this.path, required this.color});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: PdfThumbnailService.getThumbnailPath(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final thumbFile = File(snapshot.data!);
          if (thumbFile.existsSync()) {
            return LayoutBuilder(
              builder: (ctx, constraints) {
                // Use 82 % of the available height so the page is large
                // but still leaves room for filename/size below.
                final maxH = constraints.maxHeight * 0.92;
                return Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      // Soft drop-shadow so the page edge is visible on white cards
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Image.file(
                        thumbFile,
                        height: maxH,
                        fit: BoxFit.contain,
                        cacheHeight: 600, // limit decoder memory
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.picture_as_pdf_rounded, size: 44, color: color),
                      ),
                    ),
                  ),
                );
              },
            );
          }
        }

        // Fallback icon
        return Center(child: Icon(Icons.picture_as_pdf_rounded, size: 44, color: color));
      },
    );
  }
}
