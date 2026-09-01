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
  bool _hasError = false;
  bool _isDisposed = false;
  SaveStatus _saveStatus = SaveStatus.idle;
  Timer? _debounceTimer;
  StreamSubscription? _contentSubscription;
  String _statusMessage = '';

  QuillController get quillController => _quillController;
  OfficeDocument? get document => _document;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
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

      _contentSubscription = _quillController.document.changes.listen((_) {
        _onContentChanged();
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _statusMessage = 'Error loading document: $e';
      _hasError = true;
      // Initialize a fallback controller so late fields are never uninitialized
      _quillController = QuillController(
        document: Document()..insert(0, '\n'),
        selection: const TextSelection.collapsed(offset: 0),
      );
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
    _statusMessage = '';
    notifyListeners();

    try {
      await _documentService.saveDocument(_document!);
      if (_isDisposed) return; // Guard: controller may have been disposed
      _saveStatus = SaveStatus.saved;
      notifyListeners();

      // Reset to idle after 2 seconds — guarded against post-dispose calls
      await Future.delayed(const Duration(seconds: 2));
      if (!_isDisposed && _saveStatus == SaveStatus.saved) {
        _saveStatus = SaveStatus.idle;
        notifyListeners();
      }
    } catch (e) {
      if (_isDisposed) return;
      _saveStatus = SaveStatus.error;
      _statusMessage = 'Autosave error: $e';
      notifyListeners();
    }
  }

  Future<bool> manualSave() async {
    if (_document == null) return false;

    _saveStatus = SaveStatus.saving;
    _statusMessage = '';
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
    _isDisposed = true;
    _debounceTimer?.cancel();
    _contentSubscription?.cancel();
    _quillController.dispose();
    super.dispose();
  }
}
