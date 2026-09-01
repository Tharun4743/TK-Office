import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../core/app_theme.dart';
import '../../services/conversion_service/conversion_service.dart';
import '../../services/save_manager/universal_save_manager.dart';
import '../../shared/widgets/save_file_dialog.dart';
import '../../shared/widgets/tk_card.dart';
import '../../shared/widgets/tk_dialogs.dart';
import '../../storage/conversion_history_dao.dart';
import '../../utils/file_utils.dart';
import 'conversion_history_screen.dart';
import 'image_to_pdf_screen.dart';
import 'pdf_merge_split_screen.dart';

class ConversionCenterScreen extends StatefulWidget {
  const ConversionCenterScreen({super.key});

  @override
  State<ConversionCenterScreen> createState() => _ConversionCenterScreenState();
}

class _ConversionCenterScreenState extends State<ConversionCenterScreen> {
  bool _isConverting = false;
  String _statusMessage = '';
  final _historyDao = ConversionHistoryDao();

  Future<void> _recordHistory({
    required String sourcePath,
    required String targetPath,
    required String conversionType,
    required bool isSuccess,
    int fileSize = 0,
  }) async {
    try {
      await _historyDao.recordConversion(
        ConversionHistoryItem(
          sourceName: p.basename(sourcePath),
          targetName: p.basename(targetPath),
          targetPath: targetPath,
          conversionType: conversionType,
          timestamp: DateTime.now(),
          isSuccess: isSuccess,
          fileSize: fileSize,
        ),
      );
    } catch (_) {}
  }

  // 1. PDF -> Word (DOCX)
  Future<void> _handlePdfToDocx() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result.isEmpty || result.first.path == null) return;
    final inPath = result.first.path!;

    setState(() {
      _isConverting = true;
      _statusMessage = 'Extracting text & formatting OpenXML...';
    });

    try {
      final tempOut = await ConversionService.convertPdfToDocx(
        inputPath: inPath,
        onProgress: (stage) => setState(() => _statusMessage = stage),
      );

      if (!mounted) return;
      setState(() => _isConverting = false);

      final savedPath = await SaveFileDialog.show(
        context: context,
        defaultFileName: '${p.basenameWithoutExtension(inPath)}_converted',
        targetExtension: '.docx',
        category: DocumentCategory.document,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        final stat = File(savedPath).statSync();
        await _recordHistory(
          sourcePath: inPath,
          targetPath: savedPath,
          conversionType: 'PDF → Word',
          isSuccess: true,
          fileSize: stat.size,
        );
        SaveSuccessDialog.show(context: context, filePath: savedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        _showErrorDialog('PDF to Word Failed', e.toString());
      }
    }
  }

  // 2. PDF -> Excel (XLSX)
  Future<void> _handlePdfToXlsx() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result.isEmpty || result.first.path == null) return;
    final inPath = result.first.path!;

    setState(() {
      _isConverting = true;
      _statusMessage = 'Detecting tables & building Excel spreadsheet...';
    });

    try {
      final tempOut = await ConversionService.convertPdfToXlsx(
        inputPath: inPath,
        onProgress: (stage) => setState(() => _statusMessage = stage),
      );

      if (!mounted) return;
      setState(() => _isConverting = false);

      final savedPath = await SaveFileDialog.show(
        context: context,
        defaultFileName: '${p.basenameWithoutExtension(inPath)}_tables',
        targetExtension: '.xlsx',
        category: DocumentCategory.spreadsheet,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        final stat = File(savedPath).statSync();
        await _recordHistory(
          sourcePath: inPath,
          targetPath: savedPath,
          conversionType: 'PDF → Excel',
          isSuccess: true,
          fileSize: stat.size,
        );
        SaveSuccessDialog.show(context: context, filePath: savedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        _showErrorDialog('PDF to Excel Failed', e.toString());
      }
    }
  }

  // 3. PDF -> Plain Text (TXT)
  Future<void> _handlePdfToText() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result.isEmpty || result.first.path == null) return;
    final inPath = result.first.path!;

    setState(() {
      _isConverting = true;
      _statusMessage = 'Extracting plain text from PDF...';
    });

    try {
      final tempOut = await ConversionService.convertPdfToText(
        inputPath: inPath,
        onProgress: (stage) => setState(() => _statusMessage = stage),
      );

      if (!mounted) return;
      setState(() => _isConverting = false);

      final savedPath = await SaveFileDialog.show(
        context: context,
        defaultFileName: '${p.basenameWithoutExtension(inPath)}_extracted',
        targetExtension: '.txt',
        category: DocumentCategory.document,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        final stat = File(savedPath).statSync();
        await _recordHistory(
          sourcePath: inPath,
          targetPath: savedPath,
          conversionType: 'PDF → Text',
          isSuccess: true,
          fileSize: stat.size,
        );
        SaveSuccessDialog.show(context: context, filePath: savedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        _showErrorDialog('PDF to Text Failed', e.toString());
      }
    }
  }

  // 4. PDF -> Images (PNG / JPG)
  Future<void> _handlePdfToImages() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result.isEmpty || result.first.path == null) return;
    final inPath = result.first.path!;

    setState(() {
      _isConverting = true;
      _statusMessage = 'Rendering high-resolution page images...';
    });

    try {
      final tempOutPaths = await ConversionService.convertPdfToImages(
        inputPath: inPath,
        format: 'png',
        onProgress: (stage) => setState(() => _statusMessage = stage),
      );

      if (!mounted) return;
      setState(() => _isConverting = false);

      await UniversalSaveManager.saveMultipleConvertedFiles(
        context: context,
        tempFilePaths: tempOutPaths,
        defaultBaseName: '${p.basenameWithoutExtension(inPath)}_page',
        targetExtension: '.png',
        category: DocumentCategory.other,
        conversionType: 'PDF → Images (${tempOutPaths.length} pages)',
        sourceFileName: p.basename(inPath),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        _showErrorDialog('PDF to Images Failed', e.toString());
      }
    }
  }

  // 5. Word (DOCX) -> PDF
  Future<void> _handleDocxToPdf() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['docx', 'doc']);
    if (result.isEmpty || result.first.path == null) return;
    final inPath = result.first.path!;

    setState(() {
      _isConverting = true;
      _statusMessage = 'Parsing Word structure & rendering vector PDF...';
    });

    try {
      final tempOut = await ConversionService.convertDocxToPdf(
        inputPath: inPath,
        onProgress: (stage) => setState(() => _statusMessage = stage),
      );

      if (!mounted) return;
      setState(() => _isConverting = false);

      final savedPath = await SaveFileDialog.show(
        context: context,
        defaultFileName: p.basenameWithoutExtension(inPath),
        targetExtension: '.pdf',
        category: DocumentCategory.pdf,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        final stat = File(savedPath).statSync();
        await _recordHistory(
          sourcePath: inPath,
          targetPath: savedPath,
          conversionType: 'DOCX → PDF',
          isSuccess: true,
          fileSize: stat.size,
        );
        SaveSuccessDialog.show(context: context, filePath: savedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        _showErrorDialog('Word to PDF Failed', e.toString());
      }
    }
  }

  // 6. Excel (XLSX) -> PDF
  Future<void> _handleXlsxToPdf() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls', 'csv']);
    if (result.isEmpty || result.first.path == null) return;
    final inPath = result.first.path!;

    setState(() {
      _isConverting = true;
      _statusMessage = 'Parsing spreadsheet cells & building PDF tables...';
    });

    try {
      final tempOut = await ConversionService.convertXlsxToPdf(
        inputPath: inPath,
        onProgress: (stage) => setState(() => _statusMessage = stage),
      );

      if (!mounted) return;
      setState(() => _isConverting = false);

      final savedPath = await SaveFileDialog.show(
        context: context,
        defaultFileName: p.basenameWithoutExtension(inPath),
        targetExtension: '.pdf',
        category: DocumentCategory.pdf,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        final stat = File(savedPath).statSync();
        await _recordHistory(
          sourcePath: inPath,
          targetPath: savedPath,
          conversionType: 'Excel → PDF',
          isSuccess: true,
          fileSize: stat.size,
        );
        SaveSuccessDialog.show(context: context, filePath: savedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        _showErrorDialog('Excel to PDF Failed', e.toString());
      }
    }
  }

  // 7. PowerPoint (PPTX) -> PDF
  Future<void> _handlePptxToPdf() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pptx', 'ppt']);
    if (result.isEmpty || result.first.path == null) return;
    final inPath = result.first.path!;

    setState(() {
      _isConverting = true;
      _statusMessage = 'Parsing presentation slides & generating 16:9 PDF deck...';
    });

    try {
      final tempOut = await ConversionService.convertPptxToPdf(
        inputPath: inPath,
        onProgress: (stage) => setState(() => _statusMessage = stage),
      );

      if (!mounted) return;
      setState(() => _isConverting = false);

      final savedPath = await SaveFileDialog.show(
        context: context,
        defaultFileName: p.basenameWithoutExtension(inPath),
        targetExtension: '.pdf',
        category: DocumentCategory.pdf,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        final stat = File(savedPath).statSync();
        await _recordHistory(
          sourcePath: inPath,
          targetPath: savedPath,
          conversionType: 'PPTX → PDF',
          isSuccess: true,
          fileSize: stat.size,
        );
        SaveSuccessDialog.show(context: context, filePath: savedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        _showErrorDialog('PowerPoint to PDF Failed', e.toString());
      }
    }
  }

  // 8. Compress PDF
  Future<void> _handleCompressPdf() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result.isEmpty || result.first.path == null) return;
    final inPath = result.first.path!;
    final origSize = File(inPath).lengthSync();

    // Select Quality Mode
    final qualityMode = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Compression Level', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 75),
            child: const ListTile(
              leading: Icon(Icons.high_quality_rounded, color: Colors.blue),
              title: Text('High Quality (Mild Compression)'),
              subtitle: Text('Retains maximum clarity'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 50),
            child: const ListTile(
              leading: Icon(Icons.balance_rounded, color: Colors.green),
              title: Text('Balanced (Recommended)'),
              subtitle: Text('Good balance of size and visual fidelity'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 30),
            child: const ListTile(
              leading: Icon(Icons.compress_rounded, color: Colors.orange),
              title: Text('Small Size (Maximum Compression)'),
              subtitle: Text('Lowest size, optimal for email sharing'),
            ),
          ),
        ],
      ),
    );

    if (qualityMode == null) return;

    setState(() {
      _isConverting = true;
      _statusMessage = 'Compressing PDF stream data & images...';
    });

    try {
      final tempOut = await ConversionService.compressPdf(
        inputPath: inPath,
        quality: qualityMode,
        onProgress: (stage) => setState(() => _statusMessage = stage),
      );

      final newSize = tempOut.lengthSync();

      if (!mounted) return;
      setState(() => _isConverting = false);

      final savedPath = await SaveFileDialog.show(
        context: context,
        defaultFileName: '${p.basenameWithoutExtension(inPath)}_compressed',
        targetExtension: '.pdf',
        category: DocumentCategory.pdf,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        await _recordHistory(
          sourcePath: inPath,
          targetPath: savedPath,
          conversionType: 'Compress PDF (${FileUtils.formatFileSize(origSize)} → ${FileUtils.formatFileSize(newSize)})',
          isSuccess: true,
          fileSize: newSize,
        );
        SaveSuccessDialog.show(context: context, filePath: savedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        _showErrorDialog('Compression Failed', e.toString());
      }
    }
  }

  // 9. Protect PDF
  Future<void> _handlePasswordProtect() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result.isEmpty || result.first.path == null) return;
    final inPath = result.first.path!;

    final pwd = await TKDialogs.showNameInputDialog(
      context: context,
      title: 'Set PDF Password',
      initialValue: '',
      actionLabel: 'Protect',
    );

    if (pwd == null || pwd.isEmpty) return;

    setState(() {
      _isConverting = true;
      _statusMessage = 'Applying 256-bit AES encryption...';
    });

    try {
      final tempOut = await ConversionService.protectPdf(
        inputPath: inPath,
        userPassword: pwd,
        onProgress: (stage) => setState(() => _statusMessage = stage),
      );

      if (!mounted) return;
      setState(() => _isConverting = false);

      final savedPath = await SaveFileDialog.show(
        context: context,
        defaultFileName: '${p.basenameWithoutExtension(inPath)}_protected',
        targetExtension: '.pdf',
        category: DocumentCategory.pdf,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        final stat = File(savedPath).statSync();
        await _recordHistory(
          sourcePath: inPath,
          targetPath: savedPath,
          conversionType: 'Password Protect PDF',
          isSuccess: true,
          fileSize: stat.size,
        );
        SaveSuccessDialog.show(context: context, filePath: savedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        _showErrorDialog('Encryption Failed', e.toString());
      }
    }
  }

  void _showErrorDialog(String title, String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(error, style: const TextStyle(fontSize: 13)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversion Center', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Conversion History',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversionHistoryScreen()));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Section 1: Convert from PDF
              const Text('Convert from PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  TKActionCard(
                    title: 'PDF → Word',
                    subtitle: 'Convert to DOCX',
                    icon: Icons.article_rounded,
                    color: AppTheme.docBlue,
                    onTap: _handlePdfToDocx,
                  ),
                  TKActionCard(
                    title: 'PDF → Excel',
                    subtitle: 'Extract Tables to XLSX',
                    icon: Icons.table_chart_rounded,
                    color: AppTheme.sheetGreen,
                    onTap: _handlePdfToXlsx,
                  ),
                  TKActionCard(
                    title: 'PDF → Text',
                    subtitle: 'Extract TXT Content',
                    icon: Icons.text_snippet_rounded,
                    color: Colors.teal,
                    onTap: _handlePdfToText,
                  ),
                  TKActionCard(
                    title: 'PDF → Images',
                    subtitle: 'Export PNG / JPG',
                    icon: Icons.image_rounded,
                    color: Colors.deepPurple,
                    onTap: _handlePdfToImages,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section 2: Convert to PDF
              const Text('Convert to PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  TKActionCard(
                    title: 'Word → PDF',
                    subtitle: 'DOCX to Vector PDF',
                    icon: Icons.description_rounded,
                    color: AppTheme.docBlue,
                    onTap: _handleDocxToPdf,
                  ),
                  TKActionCard(
                    title: 'Excel → PDF',
                    subtitle: 'XLSX to Vector Tables',
                    icon: Icons.table_view_rounded,
                    color: AppTheme.sheetGreen,
                    onTap: _handleXlsxToPdf,
                  ),
                  TKActionCard(
                    title: 'PowerPoint → PDF',
                    subtitle: 'PPTX to 16:9 Deck',
                    icon: Icons.slideshow_rounded,
                    color: AppTheme.slideOrange,
                    onTap: _handlePptxToPdf,
                  ),
                  TKActionCard(
                    title: 'Images → PDF',
                    subtitle: 'Combine Photos',
                    icon: Icons.photo_library_rounded,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ImageToPdfScreen()));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section 3: PDF Utility & Security Tools
              const Text('PDF Tools & Optimization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  TKActionCard(
                    title: 'Merge PDFs',
                    subtitle: 'Combine Multiple PDFs',
                    icon: Icons.merge_type_rounded,
                    color: Colors.deepOrange,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfMergeSplitScreen(isMergeMode: true)));
                    },
                  ),
                  TKActionCard(
                    title: 'Split PDF',
                    subtitle: 'By Page Range',
                    icon: Icons.call_split_rounded,
                    color: Colors.pink,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfMergeSplitScreen(isMergeMode: false)));
                    },
                  ),
                  TKActionCard(
                    title: 'Compress PDF',
                    subtitle: 'Reduce File Size',
                    icon: Icons.compress_rounded,
                    color: Colors.amber.shade800,
                    onTap: _handleCompressPdf,
                  ),
                  TKActionCard(
                    title: 'Protect PDF',
                    subtitle: 'Set Password Encrypt',
                    icon: Icons.lock_outline_rounded,
                    color: Colors.redAccent,
                    onTap: _handlePasswordProtect,
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),

          if (_isConverting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.primaryBlue),
                        const SizedBox(height: 18),
                        Text(
                          _statusMessage,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
