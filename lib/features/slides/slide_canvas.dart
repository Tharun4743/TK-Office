import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/presentation_model.dart';
import '../../shared/widgets/tk_dialogs.dart';
import 'slides_controller.dart';

class SlideCanvas extends StatelessWidget {
  final SlidesController controller;

  const SlideCanvas({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final slide = controller.activeSlide;

    if (slide == null) {
      return const Center(child: Text('No slide selected'));
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: GestureDetector(
            onTap: () => controller.selectElement(null),
            child: Container(
              decoration: BoxDecoration(
                color: slide.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 60 : 20),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: slide.elements.map((elem) {
                    final isSelected = elem.id == controller.selectedElementId;
                    return Positioned(
                      left: elem.x,
                      top: elem.y,
                      child: GestureDetector(
                        onTap: () => controller.selectElement(elem.id),
                        onDoubleTap: () async {
                          if (elem.type == SlideElementType.text) {
                            final newText = await TKDialogs.showNameInputDialog(
                              context: context,
                              title: 'Edit Text Box',
                              initialValue: elem.content,
                              actionLabel: 'Update',
                            );
                            if (newText != null) {
                              controller.updateElementText(elem.id, newText);
                            }
                          }
                        },
                        onPanUpdate: (details) {
                          controller.updateElementPosition(
                            elem.id,
                            elem.x + details.delta.dx,
                            elem.y + details.delta.dy,
                          );
                        },
                        child: Container(
                          width: elem.width,
                          height: elem.height,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: elem.fillColor,
                            border: Border.all(
                              color: isSelected ? AppTheme.slideOrange : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(
                              elem.shapeType == SlideShapeType.roundedRectangle
                                  ? 12
                                  : elem.shapeType == SlideShapeType.circle
                                      ? elem.width / 2
                                      : 4,
                            ),
                          ),
                          child: elem.type == SlideElementType.text
                              ? Text(
                                  elem.content,
                                  style: TextStyle(
                                    fontSize: elem.fontSize,
                                    fontWeight: elem.isBold ? FontWeight.bold : FontWeight.normal,
                                    fontStyle: elem.isItalic ? FontStyle.italic : FontStyle.normal,
                                    color: elem.textColor,
                                  ),
                                  textAlign: elem.align,
                                )
                              : _buildShapeWidget(elem),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShapeWidget(SlideElement elem) {
    switch (elem.shapeType) {
      case SlideShapeType.circle:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: elem.fillColor ?? AppTheme.slideOrange.withAlpha(50),
          ),
        );
      case SlideShapeType.arrow:
        return const Icon(Icons.arrow_forward_rounded, size: 36, color: AppTheme.slideOrange);
      case SlideShapeType.rectangle:
      case SlideShapeType.roundedRectangle:
        return Container(
          decoration: BoxDecoration(
            color: elem.fillColor ?? AppTheme.slideOrange.withAlpha(50),
            borderRadius: BorderRadius.circular(elem.shapeType == SlideShapeType.roundedRectangle ? 12 : 4),
          ),
        );
    }
  }
}
