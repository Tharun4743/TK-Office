import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/file_info.dart';
import '../../shared/widgets/tk_dialogs.dart';
import '../../utils/date_utils.dart';
import '../../utils/file_utils.dart';
import '../pdf/pdf_viewer_screen.dart';
import '../sheets/sheets_screen.dart';
import '../slides/slides_screen.dart';
import '../writer/writer_screen.dart';
import 'file_manager_controller.dart';

class FileManagerScreen extends StatelessWidget {
  const FileManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FileManagerController(),
      child: const _FileManagerView(),
    );
  }
}

class _FileManagerView extends StatefulWidget {
  const _FileManagerView();

  @override
  State<_FileManagerView> createState() => _FileManagerViewState();
}

class _FileManagerViewState extends State<_FileManagerView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFile(BuildContext context, LocalFileInfo file) {
    switch (file.category) {
      case DocumentCategory.document:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WriterScreen(filePath: file.path),
          ),
        );
        break;
      case DocumentCategory.spreadsheet:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SheetsScreen(filePath: file.path),
          ),
        );
        break;
      case DocumentCategory.presentation:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SlidesScreen(filePath: file.path),
          ),
        );
        break;
      case DocumentCategory.pdf:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(filePath: file.path),
          ),
        );
        break;
      case DocumentCategory.other:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open ${file.name}: Unsupported format')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<FileManagerController>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'File Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort Files',
            onPressed: () => _showSortModal(context, controller),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: controller.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search files...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          controller.setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildCategoryChip(
                  context,
                  label: 'All Files',
                  isSelected: controller.selectedCategory == null,
                  onTap: () => controller.filterByCategory(null),
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  context,
                  label: 'Documents',
                  isSelected: controller.selectedCategory == DocumentCategory.document,
                  onTap: () => controller.filterByCategory(DocumentCategory.document),
                  color: AppTheme.docBlue,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  context,
                  label: 'Spreadsheets',
                  isSelected: controller.selectedCategory == DocumentCategory.spreadsheet,
                  onTap: () => controller.filterByCategory(DocumentCategory.spreadsheet),
                  color: AppTheme.sheetGreen,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  context,
                  label: 'Presentations',
                  isSelected: controller.selectedCategory == DocumentCategory.presentation,
                  onTap: () => controller.filterByCategory(DocumentCategory.presentation),
                  color: AppTheme.slideOrange,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  context,
                  label: 'PDFs',
                  isSelected: controller.selectedCategory == DocumentCategory.pdf,
                  onTap: () => controller.filterByCategory(DocumentCategory.pdf),
                  color: AppTheme.pdfRed,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // File List
          Expanded(
            child: controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : controller.files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open_rounded,
                              size: 72,
                              color: theme.colorScheme.onSurface.withAlpha(80),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              controller.searchQuery.isNotEmpty
                                  ? 'No matching files found'
                                  : 'No files in this folder yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: theme.colorScheme.onSurface.withAlpha(150),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: controller.loadFiles,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: controller.files.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final file = controller.files[index];
                            final color = FileUtils.getCategoryColor(file.category);
                            final icon = FileUtils.getCategoryIcon(file.category);

                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(isDark ? 50 : 25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(icon, color: color, size: 24),
                                ),
                                title: Text(
                                  file.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${FileUtils.formatFileSize(file.sizeInBytes)} • ${DateUtilsFormatter.formatRelative(file.modifiedDate)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textTheme.bodySmall?.color?.withAlpha(180),
                                  ),
                                ),
                                onTap: () => _openFile(context, file),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  onSelected: (action) async {
                                    if (action == 'open') {
                                      _openFile(context, file);
                                    } else if (action == 'rename') {
                                      final newName = await TKDialogs.showNameInputDialog(
                                        context: context,
                                        title: 'Rename File',
                                        initialValue: FileUtils.getFileNameWithoutExtension(file.name),
                                        actionLabel: 'Rename',
                                      );
                                      if (newName != null && context.mounted) {
                                        final ok = await controller.renameFile(file.path, newName);
                                        if (!ok && context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Failed to rename file')),
                                          );
                                        }
                                      }
                                    } else if (action == 'duplicate') {
                                      await controller.duplicateFile(file.path);
                                    } else if (action == 'share') {
                                      await controller.shareFile(file.path);
                                    } else if (action == 'delete') {
                                      final confirm = await TKDialogs.confirmDelete(
                                        context: context,
                                        itemName: file.name,
                                      );
                                      if (confirm && context.mounted) {
                                        await controller.deleteFile(file.path);
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'open',
                                      child: Row(
                                        children: [
                                          Icon(Icons.open_in_new_rounded, size: 20),
                                          SizedBox(width: 12),
                                          Text('Open'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'rename',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 20),
                                          SizedBox(width: 12),
                                          Text('Rename'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'duplicate',
                                      child: Row(
                                        children: [
                                          Icon(Icons.copy_rounded, size: 20),
                                          SizedBox(width: 12),
                                          Text('Duplicate'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'share',
                                      child: Row(
                                        children: [
                                          Icon(Icons.share_outlined, size: 20),
                                          SizedBox(width: 12),
                                          Text('Share'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                                          SizedBox(width: 12),
                                          Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: color.withAlpha(40),
      labelStyle: TextStyle(
        color: isSelected ? color : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.transparent,
        width: 1.2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  void _showSortModal(BuildContext context, FileManagerController controller) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.sort_rounded),
                    SizedBox(width: 8),
                    Text(
                      'Sort Files By',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
              const Divider(),
              RadioGroup<FileSortOption>(
                groupValue: controller.sortOption,
                onChanged: (val) {
                  if (val != null) controller.setSortOption(val);
                  Navigator.pop(ctx);
                },
                child: Column(
                  children: [
                    RadioListTile<FileSortOption>(
                      title: const Text('Date Modified (Newest First)'),
                      value: FileSortOption.dateDesc,
                    ),
                    RadioListTile<FileSortOption>(
                      title: const Text('Date Modified (Oldest First)'),
                      value: FileSortOption.dateAsc,
                    ),
                    RadioListTile<FileSortOption>(
                      title: const Text('File Name (A to Z)'),
                      value: FileSortOption.nameAsc,
                    ),
                    RadioListTile<FileSortOption>(
                      title: const Text('File Size (Largest First)'),
                      value: FileSortOption.sizeDesc,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
