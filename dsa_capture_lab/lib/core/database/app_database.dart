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
  final int? folderId;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.imagePath,
    this.folderId,
    required this.createdAt,
  });

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      imagePath: map['image_path'],
      folderId: map['folder_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
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
            folder_id INTEGER,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (folder_id) REFERENCES folders (id) ON DELETE CASCADE
          )
        ''');
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // --- Folders API ---
  
  Future<int> createFolder(String name, int? parentId) async {
    final db = await database;
    return await db.insert('folders', {
      'name': name,
      'parent_id': parentId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
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
      orderBy: 'name ASC',
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

  // --- Notes API ---

  Future<int> createNote({
    required String title,
    required String content,
    String? imagePath,
    int? folderId,
  }) async {
    final db = await database;
    return await db.insert('notes', {
      'title': title,
      'content': content,
      'image_path': imagePath,
      'folder_id': folderId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return await db.update(
      'notes',
      {
        'title': note.title,
        'content': note.content,
        // We typically don't update imagePath or folderId in simple edit, but we can.
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );
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
      orderBy: 'created_at DESC',
    );
    return maps.map((e) => Note.fromMap(e)).toList();
  }
}

// --- Provider ---

final dbProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});