import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/drift/app_database.dart';

/// Reactive Notes Repository - Stream-based data access layer.
/// 
/// **Architecture:**
/// - All reads return Streams that auto-update on DB changes
/// - No manual caching - Drift handles query invalidation
/// - Writes are simple async calls - streams auto-update
/// 
/// **Performance:**
/// - Database runs in background isolate (off UI thread)
/// - Streams efficiently track only changed data
/// - Zero jank for 2,000+ notes
class NotesRepository {
  final AppDatabase _db;
  final Ref _ref;
  
  NotesRepository(this._db, this._ref);

  // ===========================================================================
  // REACTIVE STREAMS - UI auto-updates when data changes
  // ===========================================================================

  /// Watch all active folders for a parent folder.
  /// Excludes archived/deleted. Sorted by isPinned DESC, position DESC.
  Stream<List<Folder>> watchFolders(int? parentId) {
    return _db.watchFoldersForParent(parentId);
  }

  /// Watch all active notes for a folder.
  /// Excludes archived/deleted. Sorted by isPinned DESC, position DESC.
  Stream<List<Note>> watchNotes(int? folderId) {
    return _db.watchNotesForFolder(folderId);
  }

  /// Watch combined active content (folders + notes) for a folder.
  /// Sorted by isPinned DESC, position DESC with folders before notes.
  Stream<List<dynamic>> watchActiveContent(int? folderId) {
    return _db.watchActiveContent(folderId);
  }

  /// Watch archived content (folders + notes).
  Stream<List<dynamic>> watchArchivedContent() {
    return _db.watchArchivedContent();
  }

  /// Watch trashed content (folders + notes).
  Stream<List<dynamic>> watchTrashedContent() {
    return _db.watchTrashedContent();
  }

  // ===========================================================================
  // SYNC READS (for immediate access when needed)
  // ===========================================================================

  /// Get a single folder by ID.
  Future<Folder?> getFolder(int id) => _db.getFolder(id);

  /// Get a single note by ID.
  Future<Note?> getNote(int id) => _db.getNote(id);

  /// Get images for a note.
  Future<List<String>> getNoteImages(int noteId) => _db.getNoteImages(noteId);

  /// Get all active folders for a parent (non-reactive).
  Future<List<Folder>> getFoldersForParent(int? parentId) {
    return _db.getActiveFoldersForParent(parentId);
  }

  /// Get all active notes for a folder (non-reactive).
  Future<List<Note>> getNotesForFolder(int? folderId) {
    return _db.getActiveNotesForFolder(folderId);
  }

  /// Get combined active content for a folder (non-reactive).
  Future<List<dynamic>> getActiveContent(int? folderId) async {
    final folders = await _db.getActiveFoldersForParent(folderId);
    final notes = await _db.getActiveNotesForFolder(folderId);
    
    final combined = <dynamic>[...folders, ...notes];
    combined.sort((a, b) {
      final aPinned = a is Folder ? a.isPinned : (a as Note).isPinned;
      final bPinned = b is Folder ? b.isPinned : (b as Note).isPinned;
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      
      final aPos = a is Folder ? a.position : (a as Note).position;
      final bPos = b is Folder ? b.position : (b as Note).position;
      return bPos.compareTo(aPos);
    });
    
    return combined;
  }

  /// Get all image paths for a folder (for preloading).
  Future<List<String>> getImagePathsForFolder(int? folderId) async {
    final notes = await _db.getActiveNotesForFolder(folderId);
    final paths = <String>[];
    for (final note in notes) {
      if (note.thumbnailPath != null) paths.add(note.thumbnailPath!);
      if (note.imagePath != null) paths.add(note.imagePath!);
    }
    return paths;
  }

  /// Get subfolder IDs for a parent (for prefetching).
  Future<List<int>> getSubfolderIds(int? parentId) async {
    final folders = await _db.getActiveFoldersForParent(parentId);
    return folders.map((f) => f.id).toList();
  }

  // ===========================================================================
  // FOLDER OPERATIONS
  // ===========================================================================

  /// Create a new folder. Stream auto-updates.
  Future<int> createFolder({
    required String name,
    int? parentId,
    int? position,
    bool isPinned = false,
  }) {
    return _db.createFolder(
      name: name,
      parentId: parentId,
      position: position,
      isPinned: isPinned,
    );
  }

  /// Update a folder. Stream auto-updates.
  Future<void> updateFolder(Folder folder) {
    return _db.updateFolder(folder);
  }

  /// Update specific folder fields. Stream auto-updates.
  Future<void> updateFolderFields(int id, {
    String? name,
    int? parentId,
    bool? isPinned,
    int? position,
    bool? isArchived,
    bool? isDeleted,
  }) {
    return _db.updateFolderFields(id,
      name: name,
      parentId: parentId,
      isPinned: isPinned,
      position: position,
      isArchived: isArchived,
      isDeleted: isDeleted,
    );
  }

  /// Delete a folder (soft or permanent). Stream auto-updates.
  Future<void> deleteFolder(int id, {bool permanent = false}) {
    return _db.deleteFolder(id, permanent: permanent);
  }

  /// Archive a folder. Stream auto-updates.
  Future<void> archiveFolder(int id, bool archive) {
    return _db.archiveFolder(id, archive);
  }

  /// Restore a folder from trash/archive. Stream auto-updates.
  Future<void> restoreFolder(int id) {
    return _db.restoreFolder(id);
  }

  /// Move a folder to a new parent. Stream auto-updates.
  Future<void> moveFolder(int folderId, int? targetParentId, {int? newPosition}) {
    return _db.moveFolder(folderId, targetParentId, newPosition: newPosition);
  }

  // ===========================================================================
  // NOTE OPERATIONS
  // ===========================================================================

  /// Create a new note. Stream auto-updates.
  Future<int> createNote({
    required String title,
    required String content,
    String? thumbnailPath,
    String? imagePath,
    List<String> images = const [],
    String fileType = 'text',
    int? folderId,
    int color = 0,
    bool isPinned = false,
    bool isChecklist = false,
    int? position,
  }) {
    return _db.createNote(
      title: title,
      content: content,
      thumbnailPath: thumbnailPath,
      imagePath: imagePath,
      images: images,
      fileType: fileType,
      folderId: folderId,
      color: color,
      isPinned: isPinned,
      isChecklist: isChecklist,
      position: position,
    );
  }

  /// Update a note. Stream auto-updates.
  Future<void> updateNote(Note note, {List<String>? images}) {
    return _db.updateNote(note, images: images);
  }

  /// Update specific note fields. Stream auto-updates.
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
    return _db.updateNoteFields(id,
      title: title,
      content: content,
      thumbnailPath: thumbnailPath,
      folderId: folderId,
      isPinned: isPinned,
      position: position,
      color: color,
      isChecklist: isChecklist,
      isArchived: isArchived,
      isDeleted: isDeleted,
    );
  }

  /// Delete a note (soft or permanent). Stream auto-updates.
  Future<void> deleteNote(int id, {bool permanent = false}) {
    return _db.deleteNote(id, permanent: permanent);
  }

  /// Archive a note. Stream auto-updates.
  Future<void> archiveNote(int id, bool archive) {
    return _db.archiveNote(id, archive);
  }

  /// Restore a note from trash/archive. Stream auto-updates.
  Future<void> restoreNote(int id) {
    return _db.restoreNote(id);
  }

  /// Move a note to a different folder. Stream auto-updates.
  Future<void> moveNote(int noteId, int? targetFolderId, {int? newPosition}) {
    return _db.moveNote(noteId, targetFolderId, newPosition: newPosition);
  }

  // ===========================================================================
  // BATCH OPERATIONS
  // ===========================================================================

  /// Update positions for multiple items. Stream auto-updates.
  Future<void> updatePositions(List<({String type, int id, int position})> updates) {
    return _db.updatePositions(updates);
  }

  /// Archive multiple items. Stream auto-updates.
  Future<void> archiveItems(List<({int id, String type})> items, bool archive) {
    return _db.archiveItemsBatch(items, archive);
  }

  /// Delete multiple items. Stream auto-updates.
  Future<void> deleteItems(List<({int id, String type})> items, {required bool permanent}) {
    return _db.deleteItemsBatch(items, permanent: permanent);
  }

  /// Move multiple items to a folder. Stream auto-updates.
  Future<void> moveItems(List<({int id, String type, int position})> items, int? targetFolderId) {
    return _db.moveItemsBatch(items, targetFolderId);
  }

  // ===========================================================================
  // REORDER OPERATIONS
  // ===========================================================================

  /// Reorder items with calculated positions. Stream auto-updates.
  Future<void> reorderItems(List<dynamic> items) async {
    final updates = <({String type, int id, int position})>[];
    
    // Calculate positions: highest index = highest position (appears first)
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final newPos = (items.length - i) * 10000;
      
      if (item is Folder) {
        updates.add((type: 'folder', id: item.id, position: newPos));
      } else if (item is Note) {
        updates.add((type: 'note', id: item.id, position: newPos));
      }
    }
    
    if (updates.isNotEmpty) {
      await _db.updatePositions(updates);
    }
  }
}

// =============================================================================
// PROVIDERS
// =============================================================================

/// Main repository provider
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final db = ref.watch(driftDatabaseProvider);
  return NotesRepository(db, ref);
});

/// Active content stream for a folder
final activeContentStreamProvider = StreamProvider.family<List<dynamic>, int?>((ref, folderId) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchActiveContent(folderId);
});

/// Archived content stream
final archivedContentStreamProvider = StreamProvider<List<dynamic>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchArchivedContent();
});

/// Trashed content stream
final trashedContentStreamProvider = StreamProvider<List<dynamic>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchTrashedContent();
});

/// Folders stream for a parent
final foldersStreamProvider = StreamProvider.family<List<Folder>, int?>((ref, parentId) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchFolders(parentId);
});

/// Notes stream for a folder
final notesStreamProvider = StreamProvider.family<List<Note>, int?>((ref, folderId) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchNotes(folderId);
});
