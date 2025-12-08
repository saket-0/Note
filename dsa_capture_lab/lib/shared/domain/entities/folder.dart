/// Folder entity representing a folder/directory in the notes hierarchy.
class Folder {
  // Sentinel value to distinguish "not provided" from "explicitly null"
  static const Object _notProvided = Object();
  
  final int id;
  final String name;
  final int? parentId;
  final DateTime createdAt;
  final int position; 
  final bool isPinned;
  final bool isArchived;
  final bool isDeleted;

  Folder({
    required this.id, 
    required this.name, 
    this.parentId, 
    required this.createdAt,
    this.position = 0,
    this.isPinned = false,
    this.isArchived = false,
    this.isDeleted = false,
  });

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'],
      name: map['name'],
      parentId: map['parent_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      position: map['position'] ?? 0,
      isPinned: (map['is_pinned'] ?? 0) == 1,
      isArchived: (map['is_archived'] ?? 0) == 1,
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }

  Folder copyWith({
    String? name,
    // Use Object? to allow distinguishing null from "not provided"
    Object? parentId = _notProvided,
    int? position,
    bool? isPinned,
    bool? isArchived,
    bool? isDeleted,
  }) {
    return Folder(
      id: id,
      name: name ?? this.name,
      // If parentId is _notProvided, use existing value; otherwise use the new value (which can be null)
      parentId: parentId == _notProvided ? this.parentId : parentId as int?,
      createdAt: createdAt,
      position: position ?? this.position,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
