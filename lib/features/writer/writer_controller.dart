import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../core/app_constants.dart';
import '../../models/document_model.dart';
import '../../services/document_service/document_service.dart';
import '../../services/file_service/file_service.dart';

enum SaveStatus {
  idle,
  saving,
  saved,
  error,
}

class WriterController extends ChangeNotifier {
  final DocumentService _documentService = DocumentService();
  final FileService _fileService = FileService();
  
  late QuillController _quillController;
  OfficeDocument? _document;
  bool _isLoading = true;
  SaveStatus _saveStatus = SaveStatus.idle;
  Timer? _debounceTimer;
  String _statusMessage = '';

  QuillController get quillController => _quillController;
  OfficeDocument? get document => _document;
  bool get isLoading => _isLoading;
  SaveStatus get saveStatus => _saveStatus;
  String get statusMessage => _statusMessage;
  bool get isDirty => _document?.isDirty ?? false;

  Future<void> init({String? filePath, String? initialTitle}) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (filePath != null) {
        _document = await _documentService.loadDocument(filePath);
        await _fileService.recordRecentFile(filePath);
      } else {
        _document = await _documentService.createNewDocument(
          title: initialTitle ?? 'Untitled Document',
        );
      }

      _quillController = QuillController(
        document: Document.fromDelta(_document!.delta),
        selection: const TextSelection.collapsed(offset: 0),
      );

      _quillController.document.changes.listen((_) {
        _onContentChanged();
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _statusMessage = 'Error loading document: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onContentChanged() {
    if (_document == null) return;
    _document!.delta = _quillController.document.toDelta();
    _document!.isDirty = true;
    _saveStatus = SaveStatus.idle;
    notifyListeners();

    // Debounce autosave
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: AppConstants.autosaveDebounceMs),
      () => autoSave(),
    );
  }

  Future<void> autoSave() async {
    if (_document == null || !_document!.isDirty) return;

    _saveStatus = SaveStatus.saving;
    notifyListeners();

    try {
      await _documentService.saveDocument(_document!);
      _saveStatus = SaveStatus.saved;
      notifyListeners();

      // Reset to idle after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (_saveStatus == SaveStatus.saved) {
          _saveStatus = SaveStatus.idle;
          notifyListeners();
        }
      });
    } catch (e) {
      _saveStatus = SaveStatus.error;
      _statusMessage = 'Autosave error: $e';
      notifyListeners();
    }
  }

  Future<bool> manualSave() async {
    if (_document == null) return false;

    _saveStatus = SaveStatus.saving;
    notifyListeners();

    try {
      _document!.delta = _quillController.document.toDelta();
      await _documentService.saveDocument(_document!);
      if (_document!.filePath != null) {
        await _fileService.recordRecentFile(_document!.filePath!);
      }
      _saveStatus = SaveStatus.saved;
      notifyListeners();
      return true;
    } catch (e) {
      _saveStatus = SaveStatus.error;
      _statusMessage = 'Save error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<String?> exportPdf() async {
    if (_document == null) return null;
    await manualSave();
    return await _documentService.exportToPdf(_document!);
  }

  Future<void> printDocument() async {
    if (_document == null) return;
    await manualSave();
    await _documentService.printDocument(_document!);
  }

  void undo() {
    _quillController.undo();
  }

  void redo() {
    _quillController.redo();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _quillController.dispose();
    super.dispose();
  }
}
