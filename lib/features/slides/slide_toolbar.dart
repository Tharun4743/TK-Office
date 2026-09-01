import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/presentation_model.dart';
import 'slides_controller.dart';

class SlideToolbar extends StatelessWidget {
  final SlidesController controller;

  const SlideToolbar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasSelectedElement = controller.selectedElementId != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Add Text Box
              TextButton.icon(
                icon: const Icon(Icons.text_fields_rounded, color: AppTheme.slideOrange, size: 18),
                label: const Text('Text', style: TextStyle(color: AppTheme.slideOrange, fontWeight: FontWeight.bold)),
                onPressed: controller.addTextBox,
              ),

              // Add Rectangle Shape
              IconButton(
                icon: const Icon(Icons.crop_square_rounded),
                tooltip: 'Rectangle',
                onPressed: () => controller.addShape(SlideShapeType.roundedRectangle),
              ),

              // Add Circle Shape
              IconButton(
                icon: const Icon(Icons.circle_outlined),
                tooltip: 'Circle',
                onPressed: () => controller.addShape(SlideShapeType.circle),
              ),

              // Add Arrow Shape
              IconButton(
                icon: const Icon(Icons.arrow_forward_rounded),
                tooltip: 'Arrow',
                onPressed: () => controller.addShape(SlideShapeType.arrow),
              ),

              if (hasSelectedElement) ...[
                _buildDivider(isDark),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  tooltip: 'Delete Element',
                  onPressed: controller.deleteSelectedElement,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    );
  }
}
