/// Folder entity representing a folder/directory in the notes hierarchy.
class Folder {
  final int id;
  final String name;
  final int? parentId;
  final DateTime createdAt;
  final int position; 
  final bool isArchived;
  final bool isDeleted;

  Folder({
    required this.id, 
    required this.name, 
    this.parentId, 
    required this.createdAt,
    this.position = 0, 
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
      isArchived: (map['is_archived'] ?? 0) == 1,
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }

  Folder copyWith({
    String? name,
    int? parentId,
    int? position,
    bool? isArchived,
    bool? isDeleted,
  }) {
    return Folder(
      id: id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt,
      position: position ?? this.position,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
