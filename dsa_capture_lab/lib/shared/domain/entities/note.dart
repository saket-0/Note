/// Note entity representing a note/file in the notes app.
class Note {
  final int id;
  final String title;
  final String content;
  final String? imagePath; 
  final List<String> images; 
  final String fileType; 
  final int? folderId;
  final DateTime createdAt;
  final int color; 
  final bool isPinned; 
  final bool isChecklist; 
  final int position; 
  final bool isArchived;
  final bool isDeleted;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.imagePath,
    this.images = const [],
    this.fileType = 'text',
    this.folderId,
    required this.createdAt,
    this.color = 0,
    this.isPinned = false,
    this.isChecklist = false,
    this.position = 0, 
    this.isArchived = false,
    this.isDeleted = false,
  });

  factory Note.fromMap(Map<String, dynamic> map, {List<String> images = const []}) {
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      imagePath: map['image_path'],
      images: images,
      fileType: map['file_type'] ?? 'text',
      folderId: map['folder_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      color: map['color'] ?? 0,
      isPinned: (map['is_pinned'] ?? 0) == 1,
      isChecklist: (map['is_checklist'] ?? 0) == 1,
      position: map['position'] ?? 0,
      isArchived: (map['is_archived'] ?? 0) == 1,
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }
  
  Note copyWith({
    String? title,
    String? content,
    int? color,
    bool? isPinned,
    bool? isChecklist,
    int? position,
    List<String>? images,
    bool? isArchived,
    bool? isDeleted,
    int? folderId,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      imagePath: imagePath,
      images: images ?? this.images,
      fileType: fileType,
      folderId: folderId ?? this.folderId,
      createdAt: createdAt,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isChecklist: isChecklist ?? this.isChecklist,
      position: position ?? this.position,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
