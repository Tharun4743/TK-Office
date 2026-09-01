import 'package:flutter/material.dart';
import '../../models/recent_file.dart';
import '../../services/file_service/file_service.dart';
import '../../storage/recent_files_dao.dart';
import '../../utils/file_utils.dart';

class HomeController extends ChangeNotifier {
  final RecentFilesDao _recentFilesDao = RecentFilesDao();
  final FileService _fileService = FileService();

  List<RecentFile> _recentFiles = [];
  bool _isLoading = true;
  DocumentCategory? _selectedCategory;

  List<RecentFile> get recentFiles => _recentFiles;
  bool get isLoading => _isLoading;
  DocumentCategory? get selectedCategory => _selectedCategory;

  HomeController() {
    loadRecentFiles();
  }

  Future<void> loadRecentFiles() async {
    _isLoading = true;
    notifyListeners();

    _recentFiles = await _recentFilesDao.getAllRecentFiles(
      category: _selectedCategory,
    );

    _isLoading = false;
    notifyListeners();
  }

  void filterCategory(DocumentCategory? category) {
    _selectedCategory = category;
    loadRecentFiles();
  }

  Future<void> toggleStar(RecentFile file) async {
    if (file.id == null) return;
    await _recentFilesDao.toggleStar(file.id!, !file.isStarred);
    await loadRecentFiles();
  }

  Future<String?> pickAndOpenDocument() async {
    final path = await _fileService.pickFileFromDevice();
    if (path != null) {
      await loadRecentFiles();
    }
    return path;
  }
}
