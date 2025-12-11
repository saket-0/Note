import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// =============================================================================
// TABLE DEFINITIONS
// =============================================================================

/// Folders table - hierarchical folder structure for organizing notes
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  IntColumn get parentId => integer().nullable().references(Folders, #id)();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

/// Notes table - individual notes with optional images and thumbnails
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get content => text()();
  TextColumn get thumbnailPath => text().nullable()();  // NEW: Compressed thumbnail for grid
  TextColumn get imagePath => text().nullable()();       // Original/primary image
  TextColumn get fileType => text().withDefault(const Constant('text'))();
  IntColumn get folderId => integer().nullable().references(Folders, #id)();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  IntColumn get color => integer().withDefault(const Constant(0))();
  BoolColumn get isChecklist => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

/// NoteImages table - multiple images per note with ordering
class NoteImages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId => integer().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get imagePath => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

// =============================================================================
// DATABASE CLASS
// =============================================================================

@DriftDatabase(tables: [Folders, Notes, NoteImages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        
        // === PERFORMANCE INDEXES ===
        await customStatement('CREATE INDEX idx_folders_parent ON folders(parent_id)');
        await customStatement('CREATE INDEX idx_folders_state ON folders(is_archived, is_deleted)');
        await customStatement('CREATE INDEX idx_notes_folder ON notes(folder_id)');
        await customStatement('CREATE INDEX idx_notes_state ON notes(is_archived, is_deleted)');
        await customStatement('CREATE INDEX idx_note_images_note ON note_images(note_id)');
      },
      onUpgrade: (m, from, to) async {
        // Future migrations go here
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  // ===========================================================================
  // REACTIVE STREAMS - Auto-update UI when data changes
  // ===========================================================================

  /// Watch all active folders for a parent (excludes archived/deleted)
  Stream<List<Folder>> watchFoldersForParent(int? parentId) {
    final query = select(folders)
      ..where((f) => parentId == null 
          ? f.parentId.isNull() 
          : f.parentId.equals(parentId))
      ..where((f) => f.isArchived.equals(false))
      ..where((f) => f.isDeleted.equals(false))
      ..orderBy([
        (f) => OrderingTerm.desc(f.isPinned),
        (f) => OrderingTerm.desc(f.position),
        (f) => OrderingTerm.asc(f.name),
      ]);
    return query.watch();
  }

  /// Watch all active notes for a folder (excludes archived/deleted)
  Stream<List<Note>> watchNotesForFolder(int? folderId) {
    final query = select(notes)
      ..where((n) => folderId == null 
          ? n.folderId.isNull() 
          : n.folderId.equals(folderId))
      ..where((n) => n.isArchived.equals(false))
      ..where((n) => n.isDeleted.equals(false))
      ..orderBy([
        (n) => OrderingTerm.desc(n.isPinned),
        (n) => OrderingTerm.desc(n.position),
        (n) => OrderingTerm.desc(n.createdAt),
      ]);
    return query.watch();
  }

  /// Watch archived items (folders + notes combined)
  Stream<List<dynamic>> watchArchivedContent() {
    final archivedFolders = (select(folders)
      ..where((f) => f.isArchived.equals(true))
      ..where((f) => f.isDeleted.equals(false)))
      .watch();
    
    final archivedNotes = (select(notes)
      ..where((n) => n.isArchived.equals(true))
      ..where((n) => n.isDeleted.equals(false)))
      .watch();
    
    return archivedFolders.asyncExpand((folderList) {
      return archivedNotes.map((noteList) {
        final combined = <dynamic>[...folderList, ...noteList];
        combined.sort((a, b) {
          final aPos = a is Folder ? a.position : (a as Note).position;
          final bPos = b is Folder ? b.position : (b as Note).position;
          return bPos.compareTo(aPos);
        });
        return combined;
      });
    });
  }

  /// Watch trashed items (folders + notes combined)
  Stream<List<dynamic>> watchTrashedContent() {
    final trashedFolders = (select(folders)
      ..where((f) => f.isDeleted.equals(true)))
      .watch();
    
    final trashedNotes = (select(notes)
      ..where((n) => n.isDeleted.equals(true)))
      .watch();
    
    return trashedFolders.asyncExpand((folderList) {
      return trashedNotes.map((noteList) {
        final combined = <dynamic>[...folderList, ...noteList];
        combined.sort((a, b) {
          final aPos = a is Folder ? a.position : (a as Note).position;
          final bPos = b is Folder ? b.position : (b as Note).position;
          return bPos.compareTo(aPos);
        });
        return combined;
      });
    });
  }

  /// Watch combined active content (folders + notes) for a folder
  Stream<List<dynamic>> watchActiveContent(int? folderId) {
    final foldersStream = watchFoldersForParent(folderId);
    final notesStream = watchNotesForFolder(folderId);
    
    return foldersStream.asyncExpand((folderList) {
      return notesStream.map((noteList) {
        final combined = <dynamic>[...folderList, ...noteList];
        combined.sort((a, b) {
          final aPinned = a is Folder ? a.isPinned : (a as Note).isPinned;
          final bPinned = b is Folder ? b.isPinned : (b as Note).isPinned;
          if (aPinned != bPinned) return aPinned ? -1 : 1;
          
          final aPos = a is Folder ? a.position : (a as Note).position;
          final bPos = b is Folder ? b.position : (b as Note).position;
          return bPos.compareTo(aPos);
        });
        return combined;
      });
    });
  }

  // ===========================================================================
  // FOLDER OPERATIONS
  // ===========================================================================

  Future<int> createFolder({
    required String name,
    int? parentId,
    int? position,
    bool isPinned = false,
  }) async {
    final pos = position ?? await _getNextFolderPosition(parentId);
    
    return into(folders).insert(FoldersCompanion.insert(
      name: name,
      parentId: Value(parentId),
      isPinned: Value(isPinned),
      position: Value(pos),
      createdAt: DateTime.now(),
    ));
  }

  Future<Folder?> getFolder(int id) {
    return (select(folders)..where((f) => f.id.equals(id))).getSingleOrNull();
  }

  Future<void> updateFolder(Folder folder) {
    return update(folders).replace(folder);
  }

  Future<void> updateFolderFields(int id, {
    String? name,
    int? parentId,
    bool? isPinned,
    int? position,
    bool? isArchived,
    bool? isDeleted,
  }) {
    return (update(folders)..where((f) => f.id.equals(id))).write(
      FoldersCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        parentId: parentId != null ? Value(parentId) : const Value.absent(),
        isPinned: isPinned != null ? Value(isPinned) : const Value.absent(),
        position: position != null ? Value(position) : const Value.absent(),
        isArchived: isArchived != null ? Value(isArchived) : const Value.absent(),
        isDeleted: isDeleted != null ? Value(isDeleted) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteFolder(int id, {bool permanent = false}) async {
    if (permanent) {
      await (delete(folders)..where((f) => f.id.equals(id))).go();
    } else {
      await (update(folders)..where((f) => f.id.equals(id))).write(
        const FoldersCompanion(isDeleted: Value(true), isPinned: Value(false)),
      );
    }
  }

  Future<void> archiveFolder(int id, bool archive) {
    return (update(folders)..where((f) => f.id.equals(id))).write(
      FoldersCompanion(
        isArchived: Value(archive),
        isPinned: archive ? const Value(false) : const Value.absent(),
      ),
    );
  }

  Future<void> restoreFolder(int id) {
    return (update(folders)..where((f) => f.id.equals(id))).write(
      const FoldersCompanion(isArchived: Value(false), isDeleted: Value(false)),
    );
  }

  // ===========================================================================
  // NOTE OPERATIONS
  // ===========================================================================

  Future<int> createNote({
    required String title,
    required String content,
    String? thumbnailPath,
    String? imagePath,
    String fileType = 'text',
    int? folderId,
    int color = 0,
    bool isPinned = false,
    bool isChecklist = false,
    int? position,
    List<String> images = const [],
  }) async {
    final pos = position ?? await _getNextNotePosition(folderId);
    
    return transaction(() async {
      final noteId = await into(notes).insert(NotesCompanion.insert(
        title: title,
        content: content,
        thumbnailPath: Value(thumbnailPath),
        imagePath: Value(imagePath),
        fileType: Value(fileType),
        folderId: Value(folderId),
        isPinned: Value(isPinned),
        position: Value(pos),
        color: Value(color),
        isChecklist: Value(isChecklist),
        createdAt: DateTime.now(),
      ));
      
      // Insert associated images
      for (int i = 0; i < images.length; i++) {
        await into(noteImages).insert(NoteImagesCompanion.insert(
          noteId: noteId,
          imagePath: images[i],
          position: Value(i),
        ));
      }
      
      return noteId;
    });
  }

  Future<Note?> getNote(int id) {
    return (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();
  }

  Future<List<String>> getNoteImages(int noteId) async {
    final images = await (select(noteImages)
      ..where((i) => i.noteId.equals(noteId))
      ..orderBy([(i) => OrderingTerm.asc(i.position)]))
      .get();
    return images.map((i) => i.imagePath).toList();
  }

  Future<void> updateNote(Note note, {List<String>? images}) {
    return transaction(() async {
      await update(notes).replace(note);
      
      if (images != null) {
        // Delete existing images and insert new ones
        await (delete(noteImages)..where((i) => i.noteId.equals(note.id))).go();
        for (int i = 0; i < images.length; i++) {
          await into(noteImages).insert(NoteImagesCompanion.insert(
            noteId: note.id,
            imagePath: images[i],
            position: Value(i),
          ));
        }
      }
    });
  }

  Future<void> updateNoteFields(int id, {
    String? title,
    String? content,
    String? thumbnailPath,
    int? folderId,
    bool? isPinned,
    int? position,
    int? color,
    bool? isChecklist,
    bool? isArchived,
    bool? isDeleted,
  }) {
    return (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        content: content != null ? Value(content) : const Value.absent(),
        thumbnailPath: thumbnailPath != null ? Value(thumbnailPath) : const Value.absent(),
        folderId: folderId != null ? Value(folderId) : const Value.absent(),
        isPinned: isPinned != null ? Value(isPinned) : const Value.absent(),
        position: position != null ? Value(position) : const Value.absent(),
        color: color != null ? Value(color) : const Value.absent(),
        isChecklist: isChecklist != null ? Value(isChecklist) : const Value.absent(),
        isArchived: isArchived != null ? Value(isArchived) : const Value.absent(),
        isDeleted: isDeleted != null ? Value(isDeleted) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteNote(int id, {bool permanent = false}) async {
    if (permanent) {
      // CASCADE DELETE will remove note_images automatically
      await (delete(notes)..where((n) => n.id.equals(id))).go();
    } else {
      await (update(notes)..where((n) => n.id.equals(id))).write(
        const NotesCompanion(isDeleted: Value(true), isPinned: Value(false)),
      );
    }
  }

  Future<void> archiveNote(int id, bool archive) {
    return (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        isArchived: Value(archive),
        isPinned: archive ? const Value(false) : const Value.absent(),
      ),
    );
  }

  Future<void> restoreNote(int id) {
    return (update(notes)..where((n) => n.id.equals(id))).write(
      const NotesCompanion(isArchived: Value(false), isDeleted: Value(false)),
    );
  }

  Future<void> moveNote(int noteId, int? targetFolderId, {int? newPosition}) async {
    final pos = newPosition ?? await _getNextNotePosition(targetFolderId);
    await (update(notes)..where((n) => n.id.equals(noteId))).write(
      NotesCompanion(
        folderId: Value(targetFolderId),
        position: Value(pos),
        isPinned: const Value(false),
      ),
    );
  }

  Future<void> moveFolder(int folderId, int? targetParentId, {int? newPosition}) async {
    final pos = newPosition ?? await _getNextFolderPosition(targetParentId);
    await (update(folders)..where((f) => f.id.equals(folderId))).write(
      FoldersCompanion(
        parentId: Value(targetParentId),
        position: Value(pos),
        isPinned: const Value(false),
      ),
    );
  }

  // ===========================================================================
  // BATCH OPERATIONS
  // ===========================================================================

  Future<void> updatePositions(List<({String type, int id, int position})> updates) {
    return transaction(() async {
      for (final u in updates) {
        if (u.type == 'folder') {
          await (update(folders)..where((f) => f.id.equals(u.id))).write(
            FoldersCompanion(position: Value(u.position)),
          );
        } else {
          await (update(notes)..where((n) => n.id.equals(u.id))).write(
            NotesCompanion(position: Value(u.position)),
          );
        }
      }
    });
  }

  Future<void> archiveItemsBatch(List<({int id, String type})> items, bool archive) {
    return transaction(() async {
      for (final item in items) {
        if (item.type == 'folder') {
          await archiveFolder(item.id, archive);
        } else {
          await archiveNote(item.id, archive);
        }
      }
    });
  }

  Future<void> deleteItemsBatch(List<({int id, String type})> items, {required bool permanent}) {
    return transaction(() async {
      for (final item in items) {
        if (item.type == 'folder') {
          await deleteFolder(item.id, permanent: permanent);
        } else {
          await deleteNote(item.id, permanent: permanent);
        }
      }
    });
  }

  Future<void> moveItemsBatch(List<({int id, String type, int position})> items, int? targetFolderId) {
    return transaction(() async {
      for (final item in items) {
        if (item.type == 'folder') {
          await (update(folders)..where((f) => f.id.equals(item.id))).write(
            FoldersCompanion(
              parentId: Value(targetFolderId),
              position: Value(item.position),
            ),
          );
        } else {
          await (update(notes)..where((n) => n.id.equals(item.id))).write(
            NotesCompanion(
              folderId: Value(targetFolderId),
              position: Value(item.position),
            ),
          );
        }
      }
    });
  }

  // ===========================================================================
  // SYNC READS (for immediate lookups)
  // ===========================================================================

  Future<List<Folder>> getAllFolders() {
    return (select(folders)
      ..orderBy([
        (f) => OrderingTerm.desc(f.isPinned),
        (f) => OrderingTerm.desc(f.position),
      ]))
      .get();
  }

  Future<List<Note>> getAllNotes() {
    return (select(notes)
      ..orderBy([
        (n) => OrderingTerm.desc(n.isPinned),
        (n) => OrderingTerm.desc(n.position),
      ]))
      .get();
  }

  Future<List<Folder>> getActiveFoldersForParent(int? parentId) {
    return (select(folders)
      ..where((f) => parentId == null ? f.parentId.isNull() : f.parentId.equals(parentId))
      ..where((f) => f.isArchived.equals(false))
      ..where((f) => f.isDeleted.equals(false))
      ..orderBy([
        (f) => OrderingTerm.desc(f.isPinned),
        (f) => OrderingTerm.desc(f.position),
      ]))
      .get();
  }

  Future<List<Note>> getActiveNotesForFolder(int? folderId) {
    return (select(notes)
      ..where((n) => folderId == null ? n.folderId.isNull() : n.folderId.equals(folderId))
      ..where((n) => n.isArchived.equals(false))
      ..where((n) => n.isDeleted.equals(false))
      ..orderBy([
        (n) => OrderingTerm.desc(n.isPinned),
        (n) => OrderingTerm.desc(n.position),
      ]))
      .get();
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  Future<int> _getNextFolderPosition(int? parentId) async {
    final result = await (selectOnly(folders)
      ..addColumns([folders.position.max()])
      ..where(parentId == null ? folders.parentId.isNull() : folders.parentId.equals(parentId))
      ..where(folders.isDeleted.equals(false))
      ..where(folders.isArchived.equals(false)))
      .getSingleOrNull();
    
    final maxPos = result?.read(folders.position.max()) ?? 0;
    return maxPos + 10000;
  }

  Future<int> _getNextNotePosition(int? folderId) async {
    final result = await (selectOnly(notes)
      ..addColumns([notes.position.max()])
      ..where(folderId == null ? notes.folderId.isNull() : notes.folderId.equals(folderId))
      ..where(notes.isDeleted.equals(false))
      ..where(notes.isArchived.equals(false)))
      .getSingleOrNull();
    
    final maxPos = result?.read(notes.position.max()) ?? 0;
    return maxPos + 10000;
  }
}

// =============================================================================
// DATABASE CONNECTION (Background Isolate)
// =============================================================================

/// Opens the database in a BACKGROUND ISOLATE for off-UI-thread execution.
/// This is critical for avoiding jank during heavy DB operations.
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'dsa_notes_drift',
  );
}

// =============================================================================
// PROVIDER
// =============================================================================

final driftDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
