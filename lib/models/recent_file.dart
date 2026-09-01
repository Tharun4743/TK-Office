import '../utils/file_utils.dart';

class RecentFile {
  final int? id;
  final String path;
  final String title;
  final DocumentCategory category;
  final int sizeInBytes;
  final DateTime lastOpened;
  final bool isStarred;

  RecentFile({
    this.id,
    required this.path,
    required this.title,
    required this.category,
    required this.sizeInBytes,
    required this.lastOpened,
    this.isStarred = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'title': title,
      'category': category.name,
      'size_in_bytes': sizeInBytes,
      'last_opened': lastOpened.millisecondsSinceEpoch,
      'is_starred': isStarred ? 1 : 0,
    };
  }

  factory RecentFile.fromMap(Map<String, dynamic> map) {
    return RecentFile(
      id: map['id'] as int?,
      path: map['path'] as String,
      title: map['title'] as String,
      category: DocumentCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => DocumentCategory.other,
      ),
      sizeInBytes: map['size_in_bytes'] as int? ?? 0,
      lastOpened: DateTime.fromMillisecondsSinceEpoch(map['last_opened'] as int),
      isStarred: (map['is_starred'] as int? ?? 0) == 1,
    );
  }

  RecentFile copyWith({
    int? id,
    String? path,
    String? title,
    DocumentCategory? category,
    int? sizeInBytes,
    DateTime? lastOpened,
    bool? isStarred,
  }) {
    return RecentFile(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      category: category ?? this.category,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      lastOpened: lastOpened ?? this.lastOpened,
      isStarred: isStarred ?? this.isStarred,
    );
  }
}
