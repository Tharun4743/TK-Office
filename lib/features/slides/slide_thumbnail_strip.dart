import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/tk_dialogs.dart';
import 'slides_controller.dart';

class SlideThumbnailStrip extends StatelessWidget {
  final SlidesController controller;

  const SlideThumbnailStrip({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pres = controller.presentation;

    if (pres == null) return const SizedBox.shrink();

    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: pres.slides.length + 1,
        itemBuilder: (ctx, index) {
          if (index == pres.slides.length) {
            // Add slide button
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Add Slide'),
                  onPressed: () => controller.addSlide(),
                ),
              ),
            );
          }

          final slide = pres.slides[index];
          final isActive = index == controller.activeSlideIndex;

          return GestureDetector(
            onTap: () => controller.selectSlide(index),
            onLongPress: () => _showSlideMenu(context, controller, index),
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: slide.backgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? AppTheme.slideOrange : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  width: isActive ? 2.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 40 : 10),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Slide miniature content
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slide.title,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 40,
                          height: 3,
                          color: AppTheme.slideOrange.withAlpha(100),
                        ),
                      ],
                    ),
                  ),
                  // Slide number badge
                  Positioned(
                    bottom: 4,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(120),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSlideMenu(BuildContext context, SlidesController controller, int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                'Slide ${index + 1} Options',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Duplicate Slide'),
              onTap: () {
                Navigator.pop(ctx);
                controller.duplicateSlide(index);
              },
            ),
            if (controller.presentation != null && controller.presentation!.slides.length > 1)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Delete Slide', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await TKDialogs.confirmDelete(
                    context: context,
                    itemName: 'Slide ${index + 1}',
                  );
                  if (confirm) {
                    controller.deleteSlide(index);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
