import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../services/conversion_service/conversion_service.dart';
import '../../services/pdf_service/pdf_tools_service.dart';
import '../../shared/widgets/save_file_dialog.dart';
import '../../storage/conversion_history_dao.dart';
import '../../utils/date_utils.dart';
import '../../utils/file_utils.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final List<String> _imagePaths = [];
  String _pageSize = 'A4';
  String _orientation = 'portrait';
  double _margin = 10.0;
  bool _isConverting = false;

  Future<void> _pickImages() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result.isNotEmpty) {
      setState(() {
        for (final f in result) {
          if (f.path != null && !_imagePaths.contains(f.path!)) {
            _imagePaths.add(f.path!);
          }
        }
      });
    }
  }

  Future<void> _convertImagesToPdf() async {
    if (_imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image.')),
      );
      return;
    }

    setState(() => _isConverting = true);
    try {
      final tempOut = await ConversionService.getTempOutputFile('images_doc', '.pdf');

      await PdfToolsService.convertImagesToPdf(
        imagePaths: _imagePaths,
        outputPath: tempOut.path,
        pageSize: _pageSize,
        orientation: _orientation,
        margin: _margin,
      );

      ConversionService.validateOutputFile(tempOut, 'PDF');

      if (!mounted) return;
      setState(() => _isConverting = false);

      final savedPath = await SaveFileDialog.show(
        context: context,
        defaultFileName: 'Images_${DateUtilsFormatter.formatTimestampForFileName()}',
        targetExtension: '.pdf',
        category: DocumentCategory.pdf,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        final stat = File(savedPath).statSync();
        await ConversionHistoryDao().recordConversion(
          ConversionHistoryItem(
            sourceName: '${_imagePaths.length} Images',
            targetName: p.basename(savedPath),
            targetPath: savedPath,
            conversionType: 'Images → PDF',
            timestamp: DateTime.now(),
            isSuccess: true,
            fileSize: stat.size,
          ),
        );
        Navigator.pop(context);
        SaveSuccessDialog.show(context: context, filePath: savedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Images to PDF', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_rounded),
            tooltip: 'Add Images',
            onPressed: _pickImages,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Settings Controls Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page Size
                    DropdownButton<String>(
                      value: _pageSize,
                      underline: const SizedBox(),
                      items: ['A4', 'A3', 'Letter', 'Legal'].map((s) {
                        return DropdownMenuItem(value: s, child: Text('Size: $s'));
                      }).toList(),
                      onChanged: (val) => setState(() => _pageSize = val ?? 'A4'),
                    ),

                    // Orientation
                    DropdownButton<String>(
                      value: _orientation,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'portrait', child: Text('Portrait')),
                        DropdownMenuItem(value: 'landscape', child: Text('Landscape')),
                      ],
                      onChanged: (val) => setState(() => _orientation = val ?? 'portrait'),
                    ),

                    // Margins
                    DropdownButton<double>(
                      value: _margin,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 0.0, child: Text('No Margin')),
                        DropdownMenuItem(value: 10.0, child: Text('Normal (10pt)')),
                        DropdownMenuItem(value: 20.0, child: Text('Wide (20pt)')),
                      ],
                      onChanged: (val) => setState(() => _margin = val ?? 10.0),
                    ),
                  ],
                ),
              ),

              // Image Reorderable Grid
              Expanded(
                child: _imagePaths.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_outlined, size: 64, color: theme.colorScheme.onSurface.withAlpha(80)),
                            const SizedBox(height: 12),
                            const Text('No images selected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text('Tap "Add Images" to pick photos from your device.'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add_photo_alternate_rounded),
                              label: const Text('Add Images'),
                              onPressed: _pickImages,
                            ),
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _imagePaths.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _imagePaths.removeAt(oldIndex);
                            _imagePaths.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final path = _imagePaths[index];
                          return Card(
                            key: ValueKey(path),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(File(path), width: 50, height: 50, fit: BoxFit.cover),
                              ),
                              title: Text(p.basename(path), maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('Page ${index + 1}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                onPressed: () {
                                  setState(() => _imagePaths.removeAt(index));
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),

          if (_isConverting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 14),
                    Text('Creating PDF Document...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          top: false,
          child: FilledButton.icon(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: Text('Generate PDF (${_imagePaths.length} Images)'),
            onPressed: _imagePaths.isNotEmpty && !_isConverting ? _convertImagesToPdf : null,
          ),
        ),
      ),
    );
  }
}
