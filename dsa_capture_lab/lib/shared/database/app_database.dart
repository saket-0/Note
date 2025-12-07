import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/entities.dart';

export '../domain/entities/entities.dart';

/// Optimized Database Layer with:
/// - Batch image loading (eliminates N+1)
/// - Indexed queries for fast lookups
/// - Transaction support for atomic operations
class AppDatabase {
  static Database? _database;
  static const String _dbName = 'dsa_notes_v4.db'; // New DB version for clean slate

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

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
            position INTEGER DEFAULT 0,
            FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE
          )
        ''');

        // === PERFORMANCE INDEXES ===
        await db.execute('CREATE INDEX idx_folders_parent ON folders(parent_id)');
        await db.execute('CREATE INDEX idx_folders_state ON folders(is_archived, is_deleted)');
        await db.execute('CREATE INDEX idx_notes_folder ON notes(folder_id)');
        await db.execute('CREATE INDEX idx_notes_state ON notes(is_archived, is_deleted)');
        await db.execute('CREATE INDEX idx_note_images_note ON note_images(note_id)');
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        // Performance tuning
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.rawQuery('PRAGMA synchronous = NORMAL');
        await db.rawQuery('PRAGMA cache_size = 10000');
      },
    );
  }

  // ===========================================
  // BATCH LOADING (Eliminates N+1 Queries)
  // ===========================================

  /// Load ALL notes with images in a single query batch
  Future<List<Note>> getAllNotes() async {
    final db = await database;
    
    // Step 1: Get all notes
    final noteMaps = await db.query(
      'notes',
      orderBy: 'is_pinned DESC, position ASC, created_at DESC',
    );
    
    if (noteMaps.isEmpty) return [];
    
    // Step 2: Get ALL images in one query
    final allImages = await db.query('note_images', orderBy: 'note_id, position ASC');
    
    // Step 3: Group images by note_id in memory (O(n) instead of N queries)
    final imagesByNote = <int, List<String>>{};
    for (final img in allImages) {
      final noteId = img['note_id'] as int;
      imagesByNote.putIfAbsent(noteId, () => []).add(img['image_path'] as String);
    }
    
    // Step 4: Build Note objects with images
    return noteMaps.map((m) {
      final noteId = m['id'] as int;
      return Note.fromMap(m, images: imagesByNote[noteId] ?? []);
    }).toList();
  }

  /// Load ALL folders in a single query
  Future<List<Folder>> getAllFolders() async {
    final db = await database;
    final maps = await db.query('folders', orderBy: 'position ASC, name ASC');
    return maps.map((e) => Folder.fromMap(e)).toList();
  }

  // ===========================================
  // TRANSACTION SUPPORT
  // ===========================================

  /// Run multiple operations atomically
  Future<T> runInTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  // ===========================================
  // FOLDER OPERATIONS
  // ===========================================

  Future<int> createFolder(String name, int? parentId, {int? position}) async {
    final db = await database;
    
    final finalPos = position ?? await _getNextPosition(db, 'folders', 'parent_id', parentId);

    return await db.insert('folders', {
      'name': name,
      'parent_id': parentId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'position': finalPos,
    });
  }

  Future<Folder?> getFolder(int id) async {
    final db = await database;
    final maps = await db.query('folders', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? Folder.fromMap(maps.first) : null;
  }

  Future<void> updateFolder(Folder folder) async {
    final db = await database;
    await db.update(
      'folders',
      {
        'name': folder.name,
        'parent_id': folder.parentId,
        'position': folder.position,
        'is_archived': folder.isArchived ? 1 : 0,
        'is_deleted': folder.isDeleted ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [folder.id],
    );
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

  // ===========================================
  // NOTE OPERATIONS
  // ===========================================

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
    int? position,
  }) async {
    final db = await database;
    
    return await db.transaction((txn) async {
      final finalPos = position ?? await _getNextPositionTxn(txn, 'notes', 'folder_id', folderId);

      final noteId = await txn.insert('notes', {
        'title': title,
        'content': content,
        'image_path': imagePath,
        'file_type': fileType,
        'folder_id': folderId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'position': finalPos,
        'color': color,
        'is_pinned': isPinned ? 1 : 0,
        'is_checklist': isChecklist ? 1 : 0,
      });

      // Insert images atomically
      for (int i = 0; i < images.length; i++) {
        await txn.insert('note_images', {
          'note_id': noteId,
          'image_path': images[i],
          'position': i,
        });
      }

      return noteId;
    });
  }

  Future<Note?> getNote(int id) async {
    final db = await database;
    final maps = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;

    final images = await db.query('note_images', where: 'note_id = ?', whereArgs: [id], orderBy: 'position ASC');
    return Note.fromMap(maps.first, images: images.map((i) => i['image_path'] as String).toList());
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    
    return await db.transaction((txn) async {
      await txn.update(
        'notes',
        {
          'title': note.title,
          'content': note.content,
          'color': note.color,
          'is_pinned': note.isPinned ? 1 : 0,
          'is_checklist': note.isChecklist ? 1 : 0,
          'is_archived': note.isArchived ? 1 : 0,
          'is_deleted': note.isDeleted ? 1 : 0,
          'position': note.position,
          'folder_id': note.folderId,
        },
        where: 'id = ?',
        whereArgs: [note.id],
      );

      // Sync images atomically
      await txn.delete('note_images', where: 'note_id = ?', whereArgs: [note.id]);
      for (int i = 0; i < note.images.length; i++) {
        await txn.insert('note_images', {
          'note_id': note.id,
          'image_path': note.images[i],
          'position': i,
        });
      }

      return note.id;
    });
  }

  Future<void> updateNotePosition(int id, int newPosition) async {
    final db = await database;
    await db.update('notes', {'position': newPosition}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> moveNote(int noteId, int? targetFolderId, {int? newPosition}) async {
    final db = await database;
    final updates = <String, Object?>{'folder_id': targetFolderId};
    if (newPosition != null) {
      updates['position'] = newPosition;
    }
    return await db.update('notes', updates, where: 'id = ?', whereArgs: [noteId]);
  }

  Future<int> moveFolder(int folderId, int? targetParentId, {int? newPosition}) async {
    final db = await database;
    final updates = <String, Object?>{'parent_id': targetParentId};
    if (newPosition != null) {
      updates['position'] = newPosition;
    }
    return await db.update('folders', updates, where: 'id = ?', whereArgs: [folderId]);
  }

  Future<int> deleteNote(int id, {bool permanent = false}) async {
    final db = await database;
    if (permanent) {
      return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    } else {
      return await db.update('notes', {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
    }
  }

  // ===========================================
  // STATE OPERATIONS (Archive/Restore/Trash)
  // ===========================================

  Future<void> archiveItem(int id, String type, bool archive) async {
    final db = await database;
    final table = type == 'folder' ? 'folders' : 'notes';
    await db.update(table, {'is_archived': archive ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> restoreItem(int id, String type) async {
    final db = await database;
    final table = type == 'folder' ? 'folders' : 'notes';
    await db.update(table, {'is_deleted': 0, 'is_archived': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // ===========================================
  // BATCH POSITION UPDATES
  // ===========================================

  /// Update positions for multiple items in one transaction
  Future<void> updatePositions(List<({String type, int id, int position})> updates) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final u in updates) {
        final table = u.type == 'folder' ? 'folders' : 'notes';
        await txn.update(table, {'position': u.position}, where: 'id = ?', whereArgs: [u.id]);
      }
    });
  }

  // ===========================================
  // HELPERS
  // ===========================================

  Future<int> _getNextPosition(Database db, String table, String parentCol, int? parentId) async {
    final result = await db.rawQuery(
      'SELECT MAX(position) as maxPos FROM $table WHERE $parentCol ${parentId == null ? "IS NULL" : "= ?"} AND is_deleted = 0 AND is_archived = 0',
      parentId == null ? [] : [parentId],
    );
    return ((result.first['maxPos'] as int?) ?? -1) + 1;
  }

  Future<int> _getNextPositionTxn(Transaction txn, String table, String parentCol, int? parentId) async {
    final result = await txn.rawQuery(
      'SELECT MAX(position) as maxPos FROM $table WHERE $parentCol ${parentId == null ? "IS NULL" : "= ?"} AND is_deleted = 0 AND is_archived = 0',
      parentId == null ? [] : [parentId],
    );
    return ((result.first['maxPos'] as int?) ?? -1) + 1;
  }
}

// --- Provider ---
final dbProvider = Provider<AppDatabase>((ref) => AppDatabase());
