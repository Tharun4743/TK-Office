import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class WriterToolbar extends StatelessWidget {
  final QuillController controller;

  const WriterToolbar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 50 : 15),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Bold
              _buildFormatButton(
                icon: Icons.format_bold_rounded,
                tooltip: 'Bold',
                onPressed: () {
                  final isToggled = controller.getSelectionStyle().attributes.containsKey('bold');
                  controller.formatSelection(
                    isToggled ? Attribute.clone(Attribute.bold, null) : Attribute.bold,
                  );
                },
              ),
              // Italic
              _buildFormatButton(
                icon: Icons.format_italic_rounded,
                tooltip: 'Italic',
                onPressed: () {
                  final isToggled = controller.getSelectionStyle().attributes.containsKey('italic');
                  controller.formatSelection(
                    isToggled ? Attribute.clone(Attribute.italic, null) : Attribute.italic,
                  );
                },
              ),
              // Underline
              _buildFormatButton(
                icon: Icons.format_underlined_rounded,
                tooltip: 'Underline',
                onPressed: () {
                  final isToggled = controller.getSelectionStyle().attributes.containsKey('underline');
                  controller.formatSelection(
                    isToggled ? Attribute.clone(Attribute.underline, null) : Attribute.underline,
                  );
                },
              ),
              // Strike
              _buildFormatButton(
                icon: Icons.format_strikethrough_rounded,
                tooltip: 'Strikethrough',
                onPressed: () {
                  final isToggled = controller.getSelectionStyle().attributes.containsKey('strike');
                  controller.formatSelection(
                    isToggled ? Attribute.clone(Attribute.strikeThrough, null) : Attribute.strikeThrough,
                  );
                },
              ),
              _buildDivider(isDark),

              // Align Left
              _buildFormatButton(
                icon: Icons.format_align_left_rounded,
                tooltip: 'Align Left',
                onPressed: () => controller.formatSelection(Attribute.leftAlignment),
              ),
              // Align Center
              _buildFormatButton(
                icon: Icons.format_align_center_rounded,
                tooltip: 'Align Center',
                onPressed: () => controller.formatSelection(Attribute.centerAlignment),
              ),
              // Align Right
              _buildFormatButton(
                icon: Icons.format_align_right_rounded,
                tooltip: 'Align Right',
                onPressed: () => controller.formatSelection(Attribute.rightAlignment),
              ),
              // Align Justify
              _buildFormatButton(
                icon: Icons.format_align_justify_rounded,
                tooltip: 'Justify',
                onPressed: () => controller.formatSelection(Attribute.justifyAlignment),
              ),
              _buildDivider(isDark),

              // Heading 1
              _buildTextFormatButton(
                label: 'H1',
                tooltip: 'Heading 1',
                onPressed: () {
                  final isH1 = controller.getSelectionStyle().attributes['header']?.value == 1;
                  controller.formatSelection(isH1 ? Attribute.header : Attribute.h1);
                },
              ),
              // Heading 2
              _buildTextFormatButton(
                label: 'H2',
                tooltip: 'Heading 2',
                onPressed: () {
                  final isH2 = controller.getSelectionStyle().attributes['header']?.value == 2;
                  controller.formatSelection(isH2 ? Attribute.header : Attribute.h2);
                },
              ),
              // Heading 3
              _buildTextFormatButton(
                label: 'H3',
                tooltip: 'Heading 3',
                onPressed: () {
                  final isH3 = controller.getSelectionStyle().attributes['header']?.value == 3;
                  controller.formatSelection(isH3 ? Attribute.header : Attribute.h3);
                },
              ),
              _buildDivider(isDark),

              // Bullet List
              _buildFormatButton(
                icon: Icons.format_list_bulleted_rounded,
                tooltip: 'Bullet List',
                onPressed: () {
                  final isBullet = controller.getSelectionStyle().attributes['list']?.value == 'bullet';
                  controller.formatSelection(isBullet ? Attribute.clone(Attribute.ul, null) : Attribute.ul);
                },
              ),
              // Number List
              _buildFormatButton(
                icon: Icons.format_list_numbered_rounded,
                tooltip: 'Number List',
                onPressed: () {
                  final isNumber = controller.getSelectionStyle().attributes['list']?.value == 'ordered';
                  controller.formatSelection(isNumber ? Attribute.clone(Attribute.ol, null) : Attribute.ol);
                },
              ),
              // Blockquote
              _buildFormatButton(
                icon: Icons.format_quote_rounded,
                tooltip: 'Quote',
                onPressed: () {
                  final isQuote = controller.getSelectionStyle().attributes.containsKey('blockquote');
                  controller.formatSelection(isQuote ? Attribute.clone(Attribute.blockQuote, null) : Attribute.blockQuote);
                },
              ),
              // Indent
              _buildFormatButton(
                icon: Icons.format_indent_increase_rounded,
                tooltip: 'Indent',
                onPressed: () => controller.formatSelection(Attribute.indentL1),
              ),
              // Outdent
              _buildFormatButton(
                icon: Icons.format_indent_decrease_rounded,
                tooltip: 'Outdent',
                onPressed: () => controller.formatSelection(Attribute.clone(Attribute.indentL1, null)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  Widget _buildTextFormatButton({
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
