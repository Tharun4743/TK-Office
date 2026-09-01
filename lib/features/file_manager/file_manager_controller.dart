import 'package:flutter/material.dart';
import '../../models/file_info.dart';
import '../../services/file_service/file_service.dart';
import '../../utils/file_utils.dart';

enum FileSortOption {
  dateDesc,
  dateAsc,
  nameAsc,
  nameDesc,
  sizeDesc,
  sizeAsc,
}

class FileManagerController extends ChangeNotifier {
  final FileService _fileService = FileService();
  
  List<LocalFileInfo> _allFiles = [];
  List<LocalFileInfo> _filteredFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  DocumentCategory? _selectedCategory;
  FileSortOption _sortOption = FileSortOption.dateDesc;

  List<LocalFileInfo> get files => _filteredFiles;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  DocumentCategory? get selectedCategory => _selectedCategory;
  FileSortOption get sortOption => _sortOption;

  FileManagerController() {
    loadFiles();
  }

  Future<void> loadFiles() async {
    _isLoading = true;
    notifyListeners();

    _allFiles = await _fileService.listAllLocalFiles();
    _applyFiltersAndSort();

    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void filterByCategory(DocumentCategory? category) {
    _selectedCategory = category;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void setSortOption(FileSortOption option) {
    _sortOption = option;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void _applyFiltersAndSort() {
    _filteredFiles = _allFiles.where((file) {
      final matchesCategory = _selectedCategory == null || file.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          file.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    switch (_sortOption) {
      case FileSortOption.dateDesc:
        _filteredFiles.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
        break;
      case FileSortOption.dateAsc:
        _filteredFiles.sort((a, b) => a.modifiedDate.compareTo(b.modifiedDate));
        break;
      case FileSortOption.nameAsc:
        _filteredFiles.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case FileSortOption.nameDesc:
        _filteredFiles.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case FileSortOption.sizeDesc:
        _filteredFiles.sort((a, b) => b.sizeInBytes.compareTo(a.sizeInBytes));
        break;
      case FileSortOption.sizeAsc:
        _filteredFiles.sort((a, b) => a.sizeInBytes.compareTo(b.sizeInBytes));
        break;
    }
  }

  Future<bool> renameFile(String path, String newName) async {
    final success = await _fileService.renameFile(path, newName);
    if (success) await loadFiles();
    return success;
  }

  Future<bool> deleteFile(String path) async {
    final success = await _fileService.deleteFile(path);
    if (success) await loadFiles();
    return success;
  }

  Future<String?> duplicateFile(String path) async {
    final newPath = await _fileService.duplicateFile(path);
    if (newPath != null) await loadFiles();
    return newPath;
  }

  Future<void> shareFile(String path) async {
    await _fileService.shareFile(path);
  }
}
