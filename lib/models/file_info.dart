import '../utils/file_utils.dart';

class LocalFileInfo {
  final String path;
  final String name;
  final String extension;
  final int sizeInBytes;
  final DateTime modifiedDate;
  final DocumentCategory category;
  final bool isDirectory;
  final String? folderName;
  final bool isFavorite;
  final String? tag;

  LocalFileInfo({
    required this.path,
    required this.name,
    required this.extension,
    required this.sizeInBytes,
    required this.modifiedDate,
    required this.category,
    this.isDirectory = false,
    this.folderName,
    this.isFavorite = false,
    this.tag,
  });
}
