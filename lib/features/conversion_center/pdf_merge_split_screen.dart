import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../services/conversion_service/conversion_service.dart';
import '../../services/pdf_service/pdf_tools_service.dart';
import '../../services/save_manager/universal_save_manager.dart';
import '../../shared/widgets/save_file_dialog.dart';
import '../../storage/conversion_history_dao.dart';
import '../../utils/file_utils.dart';

class PdfMergeSplitScreen extends StatefulWidget {
  final bool isMergeMode; // true = Merge, false = Split

  const PdfMergeSplitScreen({
    super.key,
    this.isMergeMode = true,
  });

  @override
  State<PdfMergeSplitScreen> createState() => _PdfMergeSplitScreenState();
}

class _PdfMergeSplitScreenState extends State<PdfMergeSplitScreen> {
  final List<String> _selectedPdfs = [];
  String? _singlePdfPath;
  final TextEditingController _rangesController = TextEditingController(text: '1-3, 4-6');
  bool _isProcessing = false;

  Future<void> _pickPdfsForMerge() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result.isNotEmpty) {
      setState(() {
        for (final f in result) {
          if (f.path != null && !_selectedPdfs.contains(f.path!)) {
            _selectedPdfs.add(f.path!);
          }
        }
      });
    }
  }

  Future<void> _pickSinglePdfForSplit() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result.isNotEmpty && result.first.path != null) {
      setState(() {
        _singlePdfPath = result.first.path!;
      });
    }
  }

  Future<void> _mergePdfs() async {
    if (_selectedPdfs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 2 PDF files to merge.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final tempOut = await ConversionService.getTempOutputFile('merged', '.pdf');

      await PdfToolsService.mergePdfs(_selectedPdfs, tempOut.path);
      ConversionService.validateOutputFile(tempOut, 'PDF');

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final defaultName = 'Merged_${p.basenameWithoutExtension(_selectedPdfs.first)}';
      final savedPath = await SaveFileDialog.show(
        context: context,
        defaultFileName: defaultName,
        targetExtension: '.pdf',
        category: DocumentCategory.pdf,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        final stat = File(savedPath).statSync();
        await ConversionHistoryDao().recordConversion(
          ConversionHistoryItem(
            sourceName: '${_selectedPdfs.length} PDFs',
            targetName: p.basename(savedPath),
            targetPath: savedPath,
            conversionType: 'Merge PDFs',
            timestamp: DateTime.now(),
            isSuccess: true,
            fileSize: stat.size,
          ),
        );
        if (!mounted) return;
        Navigator.pop(context);
        SaveSuccessDialog.show(context: context, filePath: savedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merge error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _splitPdf() async {
    if (_singlePdfPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file to split.')),
      );
      return;
    }

    final rangesStr = _rangesController.text.trim();
    if (rangesStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify page ranges (e.g. 1-2, 3-5).')),
      );
      return;
    }

    final ranges = rangesStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    setState(() => _isProcessing = true);
    try {
      final tempDir = await ConversionService.getTempOutputDir('split_pdf');
      final tempOutputPaths = await PdfToolsService.splitPdfByRanges(
        inputPath: _singlePdfPath!,
        ranges: ranges,
        outputDir: tempDir.path,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final savedPaths = await UniversalSaveManager.saveMultipleConvertedFiles(
        context: context,
        tempFilePaths: tempOutputPaths,
        defaultBaseName: '${p.basenameWithoutExtension(_singlePdfPath!)}_part',
        targetExtension: '.pdf',
        category: DocumentCategory.pdf,
        conversionType: 'Split PDF (${ranges.length} Ranges)',
        sourceFileName: p.basename(_singlePdfPath!),
      );

      if (savedPaths != null && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Split error: $e'), backgroundColor: Colors.red),
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
        title: Text(widget.isMergeMode ? 'Merge PDFs' : 'Split PDF', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          widget.isMergeMode ? _buildMergeBody(theme, isDark) : _buildSplitBody(theme, isDark),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 14),
                    Text(
                      widget.isMergeMode ? 'Merging PDF Files...' : 'Splitting PDF Pages...',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMergeBody(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_selectedPdfs.length} PDFs selected', style: const TextStyle(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add PDF'),
                onPressed: _pickPdfsForMerge,
              ),
            ],
          ),
        ),
        Expanded(
          child: _selectedPdfs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, size: 64, color: theme.colorScheme.onSurface.withAlpha(80)),
                      const SizedBox(height: 12),
                      const Text('Select PDFs to merge in sequence'),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _selectedPdfs.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _selectedPdfs.removeAt(oldIndex);
                      _selectedPdfs.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final path = _selectedPdfs[index];
                    return Card(
                      key: ValueKey(path),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${index + 1}'),
                        ),
                        title: Text(p.basename(path), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.red),
                          onPressed: () => setState(() => _selectedPdfs.removeAt(index)),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.merge_type_rounded),
            label: const Text('Merge PDFs Now'),
            onPressed: _selectedPdfs.length >= 2 ? _mergePdfs : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSplitBody(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Select PDF Button
          Card(
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
              title: Text(_singlePdfPath != null ? p.basename(_singlePdfPath!) : 'Choose PDF to split'),
              trailing: TextButton(
                onPressed: _pickSinglePdfForSplit,
                child: Text(_singlePdfPath != null ? 'Change' : 'Select'),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Range input
          const Text('Page Ranges (e.g. 1-3, 4-8):', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _rangesController,
            decoration: const InputDecoration(
              hintText: 'e.g. 1-2, 3-5, 6-10',
              border: OutlineInputBorder(),
              helperText: 'Separate parts with commas. Each range becomes a new PDF file.',
            ),
          ),
          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.call_split_rounded),
              label: const Text('Split PDF Now'),
              onPressed: _singlePdfPath != null ? _splitPdf : null,
            ),
          ),
        ],
      ),
    );
  }
}
