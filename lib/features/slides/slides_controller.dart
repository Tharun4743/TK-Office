import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_constants.dart';
import '../../models/presentation_model.dart';
import '../../services/file_service/file_service.dart';
import '../../services/presentation_service/presentation_service.dart';
import '../writer/writer_controller.dart';

class SlidesController extends ChangeNotifier {
  final PresentationService _presentationService = PresentationService();
  final FileService _fileService = FileService();

  PresentationModel? _presentation;
  bool _isLoading = true;
  SaveStatus _saveStatus = SaveStatus.idle;
  Timer? _debounceTimer;
  String? _selectedElementId;

  PresentationModel? get presentation => _presentation;
  bool get isLoading => _isLoading;
  SaveStatus get saveStatus => _saveStatus;
  String? get selectedElementId => _selectedElementId;
  bool get isDirty => _presentation?.isDirty ?? false;

  SlideModel? get activeSlide => _presentation?.activeSlide;
  int get activeSlideIndex => _presentation?.activeSlideIndex ?? 0;
  SlideElement? get selectedElement =>
      activeSlide?.elements.where((e) => e.id == _selectedElementId).firstOrNull;

  Future<void> init({String? filePath, String? initialTitle}) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (filePath != null) {
        _presentation = await _presentationService.loadPresentation(filePath);
        await _fileService.recordRecentFile(filePath);
      } else {
        _presentation = await _presentationService.createNewPresentation(
          title: initialTitle ?? 'Untitled Presentation',
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectSlide(int index) {
    if (_presentation == null || index < 0 || index >= _presentation!.slides.length) return;
    _presentation!.activeSlideIndex = index;
    _selectedElementId = null;
    notifyListeners();
  }

  void selectElement(String? id) {
    _selectedElementId = id;
    notifyListeners();
  }

  void addSlide({String title = 'New Slide'}) {
    if (_presentation == null) return;
    final newId = 'slide_${DateTime.now().millisecondsSinceEpoch}';
    final newSlide = SlideModel(
      id: newId,
      title: title,
      elements: [
        SlideElement(
          id: '${newId}_title',
          type: SlideElementType.text,
          x: 30,
          y: 40,
          width: 300,
          height: 40,
          content: title,
          fontSize: 22,
          isBold: true,
        ),
        SlideElement(
          id: '${newId}_body',
          type: SlideElementType.text,
          x: 30,
          y: 90,
          width: 300,
          height: 120,
          content: '• Tap to add bullet point\n• Add key presentation ideas here',
          fontSize: 14,
        ),
      ],
    );

    _presentation!.slides.add(newSlide);
    _presentation!.activeSlideIndex = _presentation!.slides.length - 1;
    _markDirty();
  }

  void duplicateSlide(int index) {
    if (_presentation == null || index < 0 || index >= _presentation!.slides.length) return;
    final original = _presentation!.slides[index];
    final newId = 'slide_${DateTime.now().millisecondsSinceEpoch}';

    final duplicated = SlideModel(
      id: newId,
      title: '${original.title} (Copy)',
      backgroundColor: original.backgroundColor,
      speakerNotes: original.speakerNotes,
      elements: original.elements.map((e) {
        final map = e.toMap();
        map['id'] = '${newId}_${DateTime.now().microsecondsSinceEpoch}';
        return SlideElement.fromMap(map);
      }).toList(),
    );

    _presentation!.slides.insert(index + 1, duplicated);
    _presentation!.activeSlideIndex = index + 1;
    _markDirty();
  }

  void deleteSlide(int index) {
    if (_presentation == null || _presentation!.slides.length <= 1) return;
    _presentation!.slides.removeAt(index);
    if (_presentation!.activeSlideIndex >= _presentation!.slides.length) {
      _presentation!.activeSlideIndex = _presentation!.slides.length - 1;
    }
    _selectedElementId = null;
    _markDirty();
  }

  void addTextBox() {
    if (activeSlide == null) return;
    final elemId = 'elem_${DateTime.now().millisecondsSinceEpoch}';
    final elem = SlideElement(
      id: elemId,
      type: SlideElementType.text,
      x: 50,
      y: 80,
      width: 240,
      height: 40,
      content: 'New Text Box',
      fontSize: 16,
    );
    activeSlide!.elements.add(elem);
    _selectedElementId = elemId;
    _markDirty();
  }

  void addShape(SlideShapeType shape) {
    if (activeSlide == null) return;
    final elemId = 'elem_${DateTime.now().millisecondsSinceEpoch}';
    final elem = SlideElement(
      id: elemId,
      type: SlideElementType.shape,
      shapeType: shape,
      x: 80,
      y: 80,
      width: 120,
      height: 80,
      fillColor: Colors.blue.shade100,
    );
    activeSlide!.elements.add(elem);
    _selectedElementId = elemId;
    _markDirty();
  }

  void updateElementPosition(String id, double x, double y) {
    final elem = activeSlide?.elements.where((e) => e.id == id).firstOrNull;
    if (elem != null) {
      elem.x = x.clamp(0, 360);
      elem.y = y.clamp(0, 220);
      _markDirty();
    }
  }

  void updateElementText(String id, String newText) {
    final elem = activeSlide?.elements.where((e) => e.id == id).firstOrNull;
    if (elem != null) {
      elem.content = newText;
      _markDirty();
    }
  }

  void deleteSelectedElement() {
    if (activeSlide == null || _selectedElementId == null) return;
    activeSlide!.elements.removeWhere((e) => e.id == _selectedElementId);
    _selectedElementId = null;
    _markDirty();
  }

  void _markDirty() {
    if (_presentation == null) return;
    _presentation!.isDirty = true;
    _saveStatus = SaveStatus.idle;
    notifyListeners();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: AppConstants.autosaveDebounceMs),
      () => autoSave(),
    );
  }

  Future<void> autoSave() async {
    if (_presentation == null || !_presentation!.isDirty) return;

    _saveStatus = SaveStatus.saving;
    notifyListeners();

    try {
      await _presentationService.savePresentation(_presentation!);
      _saveStatus = SaveStatus.saved;
      notifyListeners();

      Future.delayed(const Duration(seconds: 2), () {
        if (_saveStatus == SaveStatus.saved) {
          _saveStatus = SaveStatus.idle;
          notifyListeners();
        }
      });
    } catch (_) {
      _saveStatus = SaveStatus.error;
      notifyListeners();
    }
  }

  Future<bool> manualSave() async {
    if (_presentation == null) return false;
    _saveStatus = SaveStatus.saving;
    notifyListeners();

    try {
      await _presentationService.savePresentation(_presentation!);
      if (_presentation!.filePath != null) {
        await _fileService.recordRecentFile(_presentation!.filePath!);
      }
      _saveStatus = SaveStatus.saved;
      notifyListeners();
      return true;
    } catch (_) {
      _saveStatus = SaveStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<String?> exportPdf() async {
    if (_presentation == null) return null;
    await manualSave();
    return await _presentationService.exportToPdf(_presentation!);
  }

  Future<void> printPresentation() async {
    if (_presentation == null) return;
    await manualSave();
    await _presentationService.printPresentation(_presentation!);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
