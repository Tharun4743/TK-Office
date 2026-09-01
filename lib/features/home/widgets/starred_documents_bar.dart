import 'package:flutter/material.dart';
import '../../../models/file_info.dart';
import '../../../services/routing/document_router.dart';
import '../../../utils/file_utils.dart';

class StarredDocumentsBar extends StatelessWidget {
  final List<LocalFileInfo> starredFiles;
  final Function(LocalFileInfo) onUnstar;
  final VoidCallback onRefresh;

  const StarredDocumentsBar({
    super.key,
    required this.starredFiles,
    required this.onUnstar,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (starredFiles.isEmpty) return const SizedBox();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 6),
              const Text(
                'Starred Documents',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(isDark ? 50 : 25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${starredFiles.length}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 105,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: starredFiles.length,
            itemBuilder: (context, index) {
              final file = starredFiles[index];
              final color = FileUtils.getCategoryColor(file.category);
              final icon = FileUtils.getCategoryIcon(file.category);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => DocumentRouter.routeDocument(context, file.path),
                  child: Container(
                    width: 145,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color.withAlpha(isDark ? 50 : 25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, color: color, size: 18),
                            ),
                            InkWell(
                              onTap: () => onUnstar(file),
                              child: const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          file.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          FileUtils.formatFileSize(file.sizeInBytes),
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withAlpha(140)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
