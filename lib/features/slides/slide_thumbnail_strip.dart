import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/presentation_model.dart';
import '../../shared/widgets/tk_dialogs.dart';
import 'slides_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SlideThumbnailStrip
//  Horizontal strip of slide thumbnails at the bottom of SlidesScreen.
//  Each thumbnail faithfully reflects: background color / gradient / image,
//  and a condensed view of the first few text elements.
// ─────────────────────────────────────────────────────────────────────────────

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
            onLongPress: () => _showSlideMenu(ctx, controller, index),
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? AppTheme.slideOrange
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  children: [
                    // ── Slide background ──────────────────────────────────
                    Positioned.fill(child: _buildThumbnailBackground(slide)),

                    // ── Mini text preview ─────────────────────────────────
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: _buildThumbnailContent(slide),
                      ),
                    ),

                    // ── Slide number badge ────────────────────────────────
                    Positioned(
                      bottom: 4,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(130),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // ── Active indicator (top orange bar) ─────────────────
                    if (isActive)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(height: 3, color: AppTheme.slideOrange),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Thumbnail background
  // ─────────────────────────────────────────────────────────────

  Widget _buildThumbnailBackground(SlideModel slide) {
    // Background image
    if (slide.backgroundImageBytes != null) {
      return Image.memory(
        slide.backgroundImageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: slide.backgroundColor),
      );
    }

    // Gradient
    if (slide.backgroundGradientColors.length >= 2) {
      final angle = slide.backgroundGradientAngle * math.pi / 180.0;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: slide.backgroundGradientColors,
            begin: Alignment(
              -math.cos(angle + math.pi / 2),
              -math.sin(angle + math.pi / 2),
            ),
            end: Alignment(
              math.cos(angle + math.pi / 2),
              math.sin(angle + math.pi / 2),
            ),
          ),
        ),
      );
    }

    return Container(color: slide.backgroundColor);
  }

  // ─────────────────────────────────────────────────────────────
  //  Thumbnail content — show first 2 text elements as mini text
  // ─────────────────────────────────────────────────────────────

  Widget _buildThumbnailContent(SlideModel slide) {
    final textElems = slide.elements
        .where((e) => e.type == SlideElementType.text)
        .take(3)
        .toList();

    if (textElems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: textElems.map((elem) {
        final firstRun = elem.paragraphs.firstOrNull?.runs.firstOrNull;
        final text = elem.paragraphs.isNotEmpty
            ? elem.paragraphs.map((p) => p.plainText).join(' ').trim()
            : elem.content;
        final color = firstRun?.color ?? elem.textColor;

        // Ensure text is visible against background
        final displayColor = _ensureVisible(color, slide.backgroundColor);

        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 7,
              fontWeight: firstRun?.isBold == true ? FontWeight.bold : FontWeight.normal,
              color: displayColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  /// Ensure text color has enough contrast against the background
  Color _ensureVisible(Color textColor, Color bgColor) {
    // Compute perceived luminance difference
    final bgLum = bgColor.computeLuminance();
    final txLum = textColor.computeLuminance();
    final contrast = (math.max(bgLum, txLum) + 0.05) / (math.min(bgLum, txLum) + 0.05);
    if (contrast < 2.5) {
      // Not enough contrast — flip to black or white
      return bgLum > 0.5 ? Colors.black87 : Colors.white70;
    }
    return textColor;
  }

  // ─────────────────────────────────────────────────────────────
  //  Slide context menu (long press)
  // ─────────────────────────────────────────────────────────────

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
            if (controller.presentation != null &&
                controller.presentation!.slides.length > 1)
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
                    controller.deleteSheet(index);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

// Make the controller's delete helper usable from here
extension on SlidesController {
  void deleteSheet(int index) => deleteSlide(index);
}
