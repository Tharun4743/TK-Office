import 'package:flutter/material.dart';
import '../../models/spreadsheet_model.dart';
import '../../models/presentation_model.dart';
import '../routing/document_type_detector.dart';
import '../routing/document_validator.dart';
import '../routing/document_router.dart';
import '../spreadsheet_service/xlsx_service.dart';
import '../presentation_service/pptx_service.dart';

/// Central engine abstraction layer for TK Suite.
/// Decouples the UI layer from concrete document parsing and rendering implementations.
class DocumentEngineManager {
  static final DocumentEngineManager instance = DocumentEngineManager._internal();
  DocumentEngineManager._internal();

  /// Resolves the document type from path or content URI
  Future<DocumentType> detectDocumentType(
    String pathOrUri, {
    String? displayName,
    String? mimeType,
  }) async {
    return DocumentTypeDetector.detect(
      pathOrUri,
      displayName: displayName,
      mimeType: mimeType,
    );
  }

  /// Validates document pre-flight integrity
  Future<ValidationResult> validateDocument(String filePath, DocumentType docType) async {
    return DocumentValidator.validateFile(filePath, docType);
  }

  /// Routes to the appropriate viewer with default View mode
  Future<void> openDocument(
    BuildContext context,
    String pathOrUri, {
    String? displayName,
    String? mimeType,
  }) async {
    await DocumentRouter.routeDocument(
      context,
      pathOrUri,
      displayName: displayName,
      mimeType: mimeType,
    );
  }

  /// Loads a spreadsheet workbook
  Future<WorkbookModel> loadSpreadsheet(String filePath) async {
    return XlsxService.importXlsx(filePath);
  }

  /// Loads a presentation model
  Future<PresentationModel> loadPresentation(String filePath) async {
    return PptxService.importPptx(filePath);
  }
}
