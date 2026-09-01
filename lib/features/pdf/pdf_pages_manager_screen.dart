import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as px;
import '../../services/conversion_service/conversion_service.dart';
import '../../services/pdf_service/pdf_tools_service.dart';
import '../../services/save_manager/universal_save_manager.dart';
import '../../shared/widgets/tk_dialogs.dart';
import '../../utils/file_utils.dart';

class PdfPagesManagerScreen extends StatefulWidget {
  final String pdfPath;

  const PdfPagesManagerScreen({
    super.key,
    required this.pdfPath,
  });

  @override
  State<PdfPagesManagerScreen> createState() => _PdfPagesManagerScreenState();
}

class _PdfPagesManagerScreenState extends State<PdfPagesManagerScreen> {
  px.PdfDocument? _pdfDoc;
  int _pageCount = 0;
  final List<Uint8List?> _thumbnails = [];
  final Set<int> _selectedPages1Indexed = {};
  List<int> _pageOrder1Indexed = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPageThumbnails();
  }

  @override
  void dispose() {
    _pdfDoc?.close();
    super.dispose();
  }

  Future<void> _loadPageThumbnails() async {
    setState(() => _isLoading = true);
    try {
      _pdfDoc?.close();
      _pdfDoc = await px.PdfDocument.openFile(widget.pdfPath);
      _pageCount = _pdfDoc!.pagesCount;
      _pageOrder1Indexed = List.generate(_pageCount, (i) => i + 1);
      _thumbnails.clear();
      _thumbnails.addAll(List.filled(_pageCount, null));

      for (int i = 1; i <= _pageCount; i++) {
        final page = await _pdfDoc!.getPage(i);
        final image = await page.render(
          width: page.width * 0.4,
          height: page.height * 0.4,
          format: px.PdfPageImageFormat.jpeg,
        );
        await page.close();
        if (mounted) {
          setState(() {
            _thumbnails[i - 1] = image?.bytes;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading thumbnails: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelectPage(int pageNum) {
    setState(() {
      if (_selectedPages1Indexed.contains(pageNum)) {
        _selectedPages1Indexed.remove(pageNum);
      } else {
        _selectedPages1Indexed.add(pageNum);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedPages1Indexed.length == _pageOrder1Indexed.length) {
        _selectedPages1Indexed.clear();
      } else {
        _selectedPages1Indexed.addAll(_pageOrder1Indexed);
      }
    });
  }

  Future<void> _deleteSelectedPages() async {
    if (_selectedPages1Indexed.isEmpty) return;
    if (_selectedPages1Indexed.length >= _pageOrder1Indexed.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete all pages of the document.')),
      );
      return;
    }

    final confirm = await TKDialogs.confirmDelete(
      context: context,
      itemName: '${_selectedPages1Indexed.length} selected page(s)',
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final tempOut = await ConversionService.getTempOutputFile('pages_deleted', '.pdf');

      await PdfToolsService.deletePages(
        inputPath: widget.pdfPath,
        pagesToDelete1Indexed: _selectedPages1Indexed.toList(),
        outputPath: tempOut.path,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      final savedPath = await UniversalSaveManager.saveConvertedFile(
        context: context,
        defaultFileName: '${p.basenameWithoutExtension(widget.pdfPath)}_modified',
        targetExtension: '.pdf',
        category: DocumentCategory.pdf,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        Navigator.pop(context, savedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rotateSelectedPages(int angle) async {
    if (_selectedPages1Indexed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one page to rotate.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final tempOut = await ConversionService.getTempOutputFile('pages_rotated', '.pdf');

      await PdfToolsService.rotatePages(
        inputPath: widget.pdfPath,
        pagesToRotate1Indexed: _selectedPages1Indexed.toList(),
        rotationAngle: angle,
        outputPath: tempOut.path,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      final savedPath = await UniversalSaveManager.saveConvertedFile(
        context: context,
        defaultFileName: '${p.basenameWithoutExtension(widget.pdfPath)}_rotated',
        targetExtension: '.pdf',
        category: DocumentCategory.pdf,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        Navigator.pop(context, savedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _extractSelectedPages() async {
    if (_selectedPages1Indexed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one page to extract.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final tempOut = await ConversionService.getTempOutputFile('pages_extracted', '.pdf');

      await PdfToolsService.extractPages(
        inputPath: widget.pdfPath,
        pagesToExtract1Indexed: _selectedPages1Indexed.toList(),
        outputPath: tempOut.path,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      final savedPath = await UniversalSaveManager.saveConvertedFile(
        context: context,
        defaultFileName: '${p.basenameWithoutExtension(widget.pdfPath)}_extracted',
        targetExtension: '.pdf',
        category: DocumentCategory.pdf,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        Navigator.pop(context, savedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PDF Page Manager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              '${_selectedPages1Indexed.length} of $_pageCount pages selected',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_selectedPages1Indexed.length == _pageOrder1Indexed.length
                ? Icons.deselect_rounded
                : Icons.select_all_rounded),
            tooltip: 'Select All',
            onPressed: _selectAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _pageOrder1Indexed.length,
                  itemBuilder: (context, index) {
                    final pageNum = _pageOrder1Indexed[index];
                    final isSelected = _selectedPages1Indexed.contains(pageNum);
                    final thumbBytes = (pageNum - 1 < _thumbnails.length) ? _thumbnails[pageNum - 1] : null;

                    return GestureDetector(
                      onTap: () => _toggleSelectPage(pageNum),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? Colors.blueAccent : (isDark ? Colors.white24 : Colors.grey.shade300),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 50 : 20),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Page Thumbnail Image
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: thumbBytes != null
                                    ? Image.memory(thumbBytes, fit: BoxFit.cover)
                                    : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            ),

                            // Page Number Badge
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Page $pageNum',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                            // Checkmark
                            if (isSelected)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                                  child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_isSaving)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text('Applying Page Operations...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                tooltip: 'Delete Selected',
                onPressed: _selectedPages1Indexed.isNotEmpty ? _deleteSelectedPages : null,
              ),

              // Rotate 90
              IconButton(
                icon: const Icon(Icons.rotate_right_rounded, color: Colors.blue),
                tooltip: 'Rotate 90°',
                onPressed: _selectedPages1Indexed.isNotEmpty ? () => _rotateSelectedPages(90) : null,
              ),

              // Rotate 180
              IconButton(
                icon: const Icon(Icons.rotate_90_degrees_cw_rounded, color: Colors.blue),
                tooltip: 'Rotate 180°',
                onPressed: _selectedPages1Indexed.isNotEmpty ? () => _rotateSelectedPages(180) : null,
              ),

              // Extract
              IconButton(
                icon: const Icon(Icons.file_download_outlined, color: Colors.green),
                tooltip: 'Extract Selected Pages',
                onPressed: _selectedPages1Indexed.isNotEmpty ? _extractSelectedPages : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
