import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/presentation_model.dart';
import '../../utils/file_utils.dart';
import '../storage_service/local_storage_service.dart';
import 'pptx_service.dart';

class PresentationService {
  Future<PresentationModel> createNewPresentation({String title = 'Untitled Presentation'}) async {
    final path = await LocalStorageService.instance.generateUniqueFilePath(
      baseName: title,
      extension: '.pptx',
      category: DocumentCategory.presentation,
    );

    final pres = PresentationModel.empty(title: title);
    pres.filePath = path;

    await savePresentation(pres);
    return pres;
  }

  Future<PresentationModel> loadPresentation(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final ext = file.path.toLowerCase();
    PresentationModel pres;

    if (ext.endsWith('.pptx')) {
      pres = await PptxService.importPptx(filePath);
    } else if (ext.endsWith('.json')) {
      final content = await file.readAsString();
      pres = PresentationModel.fromJsonString(content, filePath: filePath);
    } else {
      pres = await PptxService.importPptx(filePath);
    }

    return pres;
  }

  Future<void> savePresentation(PresentationModel presentation) async {
    presentation.filePath ??= await LocalStorageService.instance.generateUniqueFilePath(
      baseName: presentation.title,
      extension: '.pptx',
      category: DocumentCategory.presentation,
    );

    final file = File(presentation.filePath!);
    final ext = file.path.toLowerCase();

    if (ext.endsWith('.json')) {
      await file.writeAsString(presentation.toJsonString());
    } else {
      final bytes = PptxService.exportToPptx(presentation);
      await file.writeAsBytes(bytes);
    }

    presentation.isDirty = false;
    presentation.lastModified = DateTime.now();
  }

  Future<String> exportToPdf(PresentationModel presentation) async {
    final pdfDoc = pw.Document();

    for (final slide in presentation.slides) {
      pdfDoc.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(16 * 72 / 2.54, 9 * 72 / 2.54), // 16:9 aspect ratio
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Container(
            color: PdfColors.white,
            padding: const pw.EdgeInsets.all(32),
            child: pw.Stack(
              children: slide.elements.map((elem) {
                if (elem.type == SlideElementType.text) {
                  return pw.Positioned(
                    left: elem.x,
                    top: elem.y,
                    child: pw.SizedBox(
                      width: elem.width,
                      height: elem.height,
                      child: pw.Text(
                        elem.content,
                        style: pw.TextStyle(
                          fontSize: elem.fontSize * 0.8,
                          fontWeight: elem.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                          fontStyle: elem.isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
                        ),
                      ),
                    ),
                  );
                } else {
                  return pw.Positioned(
                    left: elem.x,
                    top: elem.y,
                    child: pw.SizedBox(
                      width: elem.width,
                      height: elem.height,
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.blueGrey, width: 1),
                        ),
                      ),
                    ),
                  );
                }
              }).toList(),
            ),
          ),
        ),
      );
    }

    final pdfBytes = await pdfDoc.save();
    final pdfPath = await LocalStorageService.instance.generateUniqueFilePath(
      baseName: presentation.title,
      extension: '.pdf',
      category: DocumentCategory.pdf,
    );

    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(pdfBytes);
    return pdfPath;
  }

  Future<void> printPresentation(PresentationModel presentation) async {
    final pdfPath = await exportToPdf(presentation);
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: presentation.title,
    );
  }
}
