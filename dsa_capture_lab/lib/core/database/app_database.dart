import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Domain Models ---

class Folder {
  final int id;
  final String name;
  final int? parentId;
  final DateTime createdAt;
  final int position; 
  final bool isArchived; // Added
  final bool isDeleted; // Added

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
  final bool isArchived; // Added
  final bool isDeleted; // Added

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
    final path = join(dbPath, 'dsa_notes_v3.db'); 

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
            created_at INTEGER NOT NULL,
            position INTEGER DEFAULT 0,
            is_archived INTEGER DEFAULT 0,
            is_deleted INTEGER DEFAULT 0
          )
        ''');

        // Create Notes Table
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            image_path TEXT,
            file_type TEXT DEFAULT 'text',
            folder_id INTEGER,
            created_at INTEGER NOT NULL,
            position INTEGER DEFAULT 0,
            color INTEGER DEFAULT 0,
            is_pinned INTEGER DEFAULT 0,
            is_checklist INTEGER DEFAULT 0, 
            is_archived INTEGER DEFAULT 0,
            is_deleted INTEGER DEFAULT 0,
            FOREIGN KEY (folder_id) REFERENCES folders (id) ON DELETE CASCADE
          )
        ''');

        // Create Note Images Table
        await db.execute('''
          CREATE TABLE note_images(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            note_id INTEGER NOT NULL,
            image_path TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE
          )
        ''');
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        // Auto-migrations
        final tables = ['notes', 'folders'];
        for (var table in tables) {
           try { await db.query(table, columns: ['is_archived'], limit: 1); } 
           catch (_) { await db.execute('ALTER TABLE $table ADD COLUMN is_archived INTEGER DEFAULT 0'); }

           try { await db.query(table, columns: ['is_deleted'], limit: 1); } 
           catch (_) { await db.execute('ALTER TABLE $table ADD COLUMN is_deleted INTEGER DEFAULT 0'); }
        }

        try { await db.query('notes', columns: ['file_type'], limit: 1); } 
        catch (_) { await db.execute('ALTER TABLE notes ADD COLUMN file_type TEXT DEFAULT \'text\''); }

        try { await db.query('folders', columns: ['position'], limit: 1); } 
        catch (_) { await db.execute('ALTER TABLE folders ADD COLUMN position INTEGER DEFAULT 0'); }

        try { await db.query('notes', columns: ['position'], limit: 1); } 
        catch (_) { await db.execute('ALTER TABLE notes ADD COLUMN position INTEGER DEFAULT 0'); }

        try { await db.query('notes', columns: ['color'], limit: 1); } 
        catch (_) { await db.execute('ALTER TABLE notes ADD COLUMN color INTEGER DEFAULT 0'); }

        try { await db.query('notes', columns: ['is_pinned'], limit: 1); } 
        catch (_) { await db.execute('ALTER TABLE notes ADD COLUMN is_pinned INTEGER DEFAULT 0'); }

         try { await db.query('notes', columns: ['is_checklist'], limit: 1); } 
        catch (_) { await db.execute('ALTER TABLE notes ADD COLUMN is_checklist INTEGER DEFAULT 0'); }

        // Create note_images table if not exists (using CREATE TABLE IF NOT EXISTS logic implicitly via try/catch usage usually, but for tables we check master)
        final imagesTable = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='note_images'");
        if (imagesTable.isEmpty) {
           await db.execute('''
            CREATE TABLE note_images(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              note_id INTEGER NOT NULL,
              image_path TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE
            )
          ''');
        }
      },
    );
  }

  Future<List<String>> _fetchImagesForNote(int noteId) async {
     final db = await database;
     final imgMaps = await db.query('note_images', where: 'note_id = ?', whereArgs: [noteId]);
     return imgMaps.map((i) => i['image_path'] as String).toList();
  }

  // --- CRUD for Folders ---
  
  Future<Note?> getNote(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    
    // Fetch Images if needed (or assume simplified)
    List<String> images = [];
    if (maps.first['file_type'] == 'text') {
       images = await _fetchImagesForNote(id);
    }
    
    return Note.fromMap(maps.first, images: images);
  }
  


  Future<int> createFolder(String name, int? parentId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT MAX(position) as maxPos FROM folders WHERE parent_id ${parentId == null ? "IS NULL" : "= ?"} AND is_deleted = 0 AND is_archived = 0',
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

  Future<List<Folder>> getFolders(int? parentId, {bool showArchived = false, bool showDeleted = false}) async {
    final db = await database;
    String whereClause;
    List<Object?> args;

    if (showDeleted) {
      whereClause = 'is_deleted = 1';
      args = [];
    } else if (showArchived) {
      whereClause = 'is_archived = 1 AND is_deleted = 0';
      args = [];
    } else {
      whereClause = '(parent_id ${parentId == null ? "IS NULL" : "= ?"}) AND is_archived = 0 AND is_deleted = 0';
      args = parentId == null ? [] : [parentId];
    }
    
    final maps = await db.query(
      'folders',
      where: whereClause,
      whereArgs: args,
      orderBy: 'position ASC, name ASC',
    );
    return maps.map((e) => Folder.fromMap(e)).toList();
  }
  
  /// Get ALL folders from database (for cache loading)
  Future<List<Folder>> getAllFolders() async {
    final db = await database;
    final maps = await db.query('folders', orderBy: 'position ASC, name ASC');
    return maps.map((e) => Folder.fromMap(e)).toList();
  }
  
  /// Get ALL notes from database (for cache loading)
  Future<List<Note>> getAllNotes() async {
    final db = await database;
    final maps = await db.query('notes', orderBy: 'is_pinned DESC, position ASC, created_at DESC');
    
    List<Note> notes = [];
    for (var m in maps) {
       final noteId = m['id'] as int;
       final imgMaps = await db.query('note_images', where: 'note_id = ?', whereArgs: [noteId]);
       final images = imgMaps.map((i) => i['image_path'] as String).toList();
       notes.add(Note.fromMap(m, images: images));
    }
    return notes;
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

  Future<int> deleteFolder(int id, {bool permanent = false}) async {
    final db = await database;
    if (permanent) {
       return await db.delete('folders', where: 'id = ?', whereArgs: [id]);
    } else {
       return await db.update('folders', {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
    }
  }

  // --- CRUD for Notes/Files ---

  Future<int> createNote({
    required String title,
    required String content,
    String? imagePath,
    List<String> images = const [], 
    String fileType = 'text',
    int? folderId,
    int color = 0,
    bool isPinned = false,
    bool isChecklist = false,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT MAX(position) as maxPos FROM notes WHERE folder_id ${folderId == null ? "IS NULL" : "= ?"} AND is_deleted = 0 AND is_archived = 0',
      folderId == null ? [] : [folderId]
    );
    int maxPos = (result.first['maxPos'] as int?) ?? -1;

    final noteId = await db.insert('notes', {
      'title': title,
      'content': content,
      'image_path': imagePath,
      'file_type': fileType,
      'folder_id': folderId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'position': maxPos + 1,
      'color': color,
      'is_pinned': isPinned ? 1 : 0,
      'is_checklist': isChecklist ? 1 : 0,
    });

    // Insert Images
    for (String path in images) {
      await db.insert('note_images', {
        'note_id': noteId,
        'image_path': path,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    return noteId;
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    
    // Update basic fields
    await db.update(
      'notes',
      {
        'title': note.title,
        'content': note.content,
        'color': note.color,
        'is_pinned': note.isPinned ? 1 : 0,
        'is_checklist': note.isChecklist ? 1 : 0,
        'is_archived': note.isArchived ? 1 : 0,
        'is_deleted': note.isDeleted ? 1 : 0,
        // We don't update legacy image_path usually unless explicitly handled
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );

    // Sync Images (Simple: Delete all and re-add? Or incremental?)
    // For simplicity/robustness: Delete all linked images and re-add active ones.
    // Optimization: Diff them, but simplest for now:
    await db.delete('note_images', where: 'note_id = ?', whereArgs: [note.id]);
    for (String path in note.images) {
      await db.insert('note_images', {
        'note_id': note.id,
        'image_path': path,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    return note.id;
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

  Future<int> deleteNote(int id, {bool permanent = false}) async {
    final db = await database;
     if (permanent) {
      return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    } else {
      return await db.update('notes', {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> restoreItem(int id, String type) async {
    final db = await database;
    final table = type == 'folder' ? 'folders' : 'notes';
    await db.update(table, {'is_deleted': 0, 'is_archived': 0}, where: 'id = ?', whereArgs: [id]);
  }
  
  Future<void> archiveItem(int id, String type, bool archive) async {
     final db = await database;
    final table = type == 'folder' ? 'folders' : 'notes';
    await db.update(table, {'is_archived': archive ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> getNotes(int? folderId, {bool showArchived = false, bool showDeleted = false}) async {
    final db = await database;
    String whereClause;
    List<Object?> args;

    if (showDeleted) {
      whereClause = 'is_deleted = 1';
      args = [];
    } else if (showArchived) {
      whereClause = 'is_archived = 1 AND is_deleted = 0';
      args = [];
    } else {
      whereClause = '(folder_id ${folderId == null ? "IS NULL" : "= ?"}) AND is_archived = 0 AND is_deleted = 0';
      args = folderId == null ? [] : [folderId];
    }

    final maps = await db.query(
      'notes',
      where: whereClause,
      whereArgs: args,
      orderBy: 'is_pinned DESC, position ASC, created_at DESC', 
    );
    
    // Fetch images for each note?
    // Optimization: Fetch ALL images for these notes in one query?
    // "SELECT * FROM note_images WHERE note_id IN (...)"
    // Or just simple loop for now (easier to implement).
    
    List<Note> notes = [];
    for (var m in maps) {
       final noteId = m['id'] as int;
       final imgMaps = await db.query('note_images', where: 'note_id = ?', whereArgs: [noteId]);
       final images = imgMaps.map((i) => i['image_path'] as String).toList();
       
       notes.add(Note.fromMap(m, images: images));
    }

    return notes;
  }
}

// --- Provider ---

final dbProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});