import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Domain Models ---

class Folder {
  final int id;
  final String name;
  final int? parentId;
  final DateTime createdAt;

  Folder({required this.id, required this.name, this.parentId, required this.createdAt});

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'],
      name: map['name'],
      parentId: map['parent_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
}

class Note {
  final int id;
  final String title;
  final String content;
  final String? imagePath;
  final String fileType; 
  final int? folderId;
  final DateTime createdAt;
  final int color; // New: 0xFF... or index
  final bool isPinned; // New

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.imagePath,
    this.fileType = 'text',
    this.folderId,
    required this.createdAt,
    this.color = 0,
    this.isPinned = false,
  });

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      imagePath: map['image_path'],
      fileType: map['file_type'] ?? 'text',
      folderId: map['folder_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      color: map['color'] ?? 0,
      isPinned: (map['is_pinned'] ?? 0) == 1,
    );
  }
  
  Note copyWith({
    String? title,
    String? content,
    int? color,
    bool? isPinned,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      imagePath: imagePath,
      fileType: fileType,
      folderId: folderId,
      createdAt: createdAt,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

// --- Database Helper ---

class AppDatabase {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'dsa_notes_v2.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create Folders Table
        await db.execute('''
          CREATE TABLE folders(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            parent_id INTEGER,
            created_at INTEGER NOT NULL
          )
        ''');

        // Create Notes Table
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            image_path TEXT,
            file_type TEXT DEFAULT 'text', -- Added file_type with a default
            folder_id INTEGER,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (folder_id) REFERENCES folders (id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 1) {
          // This block would typically handle migrations from older versions.
          // Since we are starting with version 1 and adding a column,
          // we'll handle it with an ALTER TABLE statement if the column is missing.
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        // Auto-migrations
        try { await db.query('notes', columns: ['file_type'], limit: 1); } 
        catch (_) { await db.execute('ALTER TABLE notes ADD COLUMN file_type TEXT DEFAULT \'text\''); }

        try { await db.query('folders', columns: ['position'], limit: 1); } 
        catch (_) { await db.execute('ALTER TABLE folders ADD COLUMN position INTEGER DEFAULT 0'); }

        try { await db.query('notes', columns: ['position'], limit: 1); } 
        catch (_) { await db.execute('ALTER TABLE notes ADD COLUMN position INTEGER DEFAULT 0'); }

        // New Keep Features: Color & Pinned
        try { await db.query('notes', columns: ['color'], limit: 1); } 
        catch (_) { await db.execute('ALTER TABLE notes ADD COLUMN color INTEGER DEFAULT 0'); }

        try { await db.query('notes', columns: ['is_pinned'], limit: 1); } 
        catch (_) { await db.execute('ALTER TABLE notes ADD COLUMN is_pinned INTEGER DEFAULT 0'); }
      },
    );
  }

  // --- CRUD for Folders ---
  
  Future<int> createFolder(String name, int? parentId) async {
    final db = await database;
    // Get max position to append at end
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT MAX(position) as maxPos FROM folders WHERE parent_id ${parentId == null ? "IS NULL" : "= ?"}',
      parentId == null ? [] : [parentId]
    );
    int maxPos = (result.first['maxPos'] as int?) ?? -1;

    return await db.insert('folders', {
      'name': name,
      'parent_id': parentId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'position': maxPos + 1,
    });
  }

  Future<List<Folder>> getFolders(int? parentId) async {
    final db = await database;
    final String whereClause = parentId == null ? 'parent_id IS NULL' : 'parent_id = ?';
    final List<Object?> args = parentId == null ? [] : [parentId];
    
    final maps = await db.query(
      'folders',
      where: whereClause,
      whereArgs: args,
      orderBy: 'position ASC, name ASC',
    );
    return maps.map((e) => Folder.fromMap(e)).toList();
  }
  
  Future<Folder?> getFolder(int id) async {
    final db = await database;
    final maps = await db.query('folders', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Folder.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateFolderPosition(int id, int newPosition) async {
    final db = await database;
    await db.update('folders', {'position': newPosition}, where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD for Notes/Files ---

  Future<int> createNote({
    required String title,
    required String content,
    String? imagePath,
    String fileType = 'text',
    int? folderId,
    int color = 0,
    bool isPinned = false,
  }) async {
    final db = await database;
     // Get max position
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT MAX(position) as maxPos FROM notes WHERE folder_id ${folderId == null ? "IS NULL" : "= ?"}',
      folderId == null ? [] : [folderId]
    );
    int maxPos = (result.first['maxPos'] as int?) ?? -1;

    return await db.insert('notes', {
      'title': title,
      'content': content,
      'image_path': imagePath,
      'file_type': fileType,
      'folder_id': folderId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'position': maxPos + 1,
      'color': color,
      'is_pinned': isPinned ? 1 : 0,
    });
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return await db.update(
      'notes',
      {
        'title': note.title,
        'content': note.content,
        'color': note.color,
        'is_pinned': note.isPinned ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }
  
  Future<int> moveNote(int noteId, int targetFolderId) async {
    final db = await database;
    return await db.update(
      'notes',
      {'folder_id': targetFolderId},
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  Future<void> updateNotePosition(int id, int newPosition) async {
    final db = await database;
    await db.update('notes', {'position': newPosition}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> getNotes(int? folderId) async {
    final db = await database;
    final String whereClause = folderId == null ? 'folder_id IS NULL' : 'folder_id = ?';
    final List<Object?> args = folderId == null ? [] : [folderId];

    final maps = await db.query(
      'notes',
      where: whereClause,
      whereArgs: args,
      // Sort: Pinned first, then Position, then Newest
      orderBy: 'is_pinned DESC, position ASC, created_at DESC', 
    );
    return maps.map((e) => Note.fromMap(e)).toList();
  }
}

// --- Provider ---

final dbProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});