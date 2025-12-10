import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../domain/entities/note.dart';

/// Notes Repository with Lazy Loading + LRU Cache strategy.
/// 
/// Features:
/// - **Lazy Loading**: Only fetches notes from the DB when a specific folder is requested
/// - **LRU Caching**: Keeps the notes of the last 15 visited folders in memory
/// - **Write-Through Consistency**: All add/update/delete operations immediately update 
///   the cache (if that folder is loaded) so the UI updates without a refetch
class NotesRepository {
  final AppDatabase _db;
  
  // THE CACHE: Maps FolderID -> List of Notes
  final Map<int?, List<Note>> _folderCache = {};
  
  // THE LRU TRACKER: Stores FolderIDs in order of access (End = Most Recent)
  final List<int?> _lruTracker = [];
  
  // CONSTANT: Max folders to keep in memory
  static const int _maxCacheSize = 15;

  NotesRepository(this._db);

  // ===========================================
  // 1. READ: Smart Fetch with LRU Logic
  // ===========================================

  /// Get notes for a folder with smart caching.
  /// 
  /// - Returns cached notes immediately if available
  /// - Lazily loads from DB if not cached
  /// - Enforces LRU eviction to save memory
  Future<List<Note>> getNotesForFolder(int? folderId) async {
    // A. Check Cache First
    if (_folderCache.containsKey(folderId)) {
      _refreshLru(folderId); // Mark as recently used
      return _folderCache[folderId]!;
    }

    // B. Not in Cache? Fetch from DB (Lazy Load)
    final notes = await _db.getNotesForFolder(folderId);

    // C. Add to Cache & Enforce Size Limit
    _folderCache[folderId] = notes;
    _refreshLru(folderId);
    _enforceCacheLimit();

    return notes;
  }

  /// Check if a folder's notes are currently cached.
  bool isFolderCached(int? folderId) => _folderCache.containsKey(folderId);

  /// Get cached notes synchronously (returns empty list if not cached).
  /// Use this for UI reads when you know the folder was previously loaded.
  List<Note> getCachedNotes(int? folderId) {
    return _folderCache[folderId] ?? [];
  }

  // ===========================================
  // 2. WRITE: Add Note (Updates DB + Cache)
  // ===========================================

  /// Add a new note to DB and update cache if folder is loaded.
  /// 
  /// Write-through: If that folder isn't in memory, we don't care - 
  /// it will load fresh next time.
  Future<void> addNote(Note note) async {
    // 1. Write to DB (Source of Truth)
    final savedNoteId = await _db.createNote(
      title: note.title,
      content: note.content,
      imagePath: note.imagePath,
      images: note.images,
      fileType: note.fileType,
      folderId: note.folderId,
      color: note.color,
      isPinned: note.isPinned,
      isChecklist: note.isChecklist,
      position: note.position,
    );

    // 2. Update Cache if that folder is currently loaded
    final folderId = note.folderId;
    if (_folderCache.containsKey(folderId)) {
      // Create note with real ID from DB
      final savedNote = Note(
        id: savedNoteId,
        title: note.title,
        content: note.content,
        imagePath: note.imagePath,
        images: note.images,
        fileType: note.fileType,
        folderId: note.folderId,
        createdAt: note.createdAt,
        color: note.color,
        isPinned: note.isPinned,
        isChecklist: note.isChecklist,
        position: note.position,
        isArchived: note.isArchived,
        isDeleted: note.isDeleted,
      );
      _folderCache[folderId]!.add(savedNote);
      // Sort by isPinned DESC, position DESC (matching UI expectations)
      _sortNotesList(folderId);
    }
  }

  // ===========================================
  // 3. UPDATE: Edit Note (Updates DB + Cache)
  // ===========================================

  /// Update an existing note in DB and update cache if folder is loaded.
  Future<void> updateNote(Note note) async {
    // 1. Write to DB
    await _db.updateNote(note);

    // 2. Update Cache
    final folderId = note.folderId;
    if (_folderCache.containsKey(folderId)) {
      final notesList = _folderCache[folderId]!;
      final index = notesList.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        notesList[index] = note;
        // Re-sort in case isPinned or position changed
        _sortNotesList(folderId);
      }
    }
  }

  // ===========================================
  // 4. DELETE: Remove Note (Updates DB + Cache)
  // ===========================================

  /// Delete a note from DB and remove from cache if folder is loaded.
  Future<void> deleteNote(int noteId, int? folderId, {bool permanent = false}) async {
    // 1. Delete from DB
    await _db.deleteNote(noteId, permanent: permanent);

    // 2. Remove from Cache
    if (_folderCache.containsKey(folderId)) {
      _folderCache[folderId]!.removeWhere((n) => n.id == noteId);
    }
  }

  // ===========================================
  // 5. MOVE: Move Note to Different Folder
  // ===========================================

  /// Move a note to a different folder.
  /// Removes from source cache and adds to target cache (if loaded).
  Future<void> moveNote(int noteId, int? sourceFolderId, int? targetFolderId, {int? newPosition}) async {
    // 1. Get the note from cache or DB
    Note? note;
    if (_folderCache.containsKey(sourceFolderId)) {
      note = _folderCache[sourceFolderId]!
          .cast<Note?>()
          .firstWhere((n) => n?.id == noteId, orElse: () => null);
    }
    
    // 2. Update DB
    await _db.moveNote(noteId, targetFolderId, newPosition: newPosition);

    // 3. Remove from source cache
    if (_folderCache.containsKey(sourceFolderId)) {
      _folderCache[sourceFolderId]!.removeWhere((n) => n.id == noteId);
    }

    // 4. Add to target cache if loaded and we have the note data
    if (_folderCache.containsKey(targetFolderId) && note != null) {
      final movedNote = note.copyWith(
        folderId: targetFolderId,
        position: newPosition ?? note.position,
        isPinned: false, // Unpin when moving
      );
      _folderCache[targetFolderId]!.add(movedNote);
      _sortNotesList(targetFolderId);
    }
  }

  // ===========================================
  // BATCH OPERATIONS
  // ===========================================

  /// Delete multiple notes atomically.
  Future<void> deleteNotes(List<({int noteId, int? folderId})> notes, {bool permanent = false}) async {
    // 1. Batch delete from DB
    final items = notes.map((n) => (id: n.noteId, type: 'note')).toList();
    await _db.deleteItemsBatch(items, permanent: permanent);

    // 2. Remove from cache
    for (final n in notes) {
      if (_folderCache.containsKey(n.folderId)) {
        _folderCache[n.folderId]!.removeWhere((note) => note.id == n.noteId);
      }
    }
  }

  // ===========================================
  // CACHE MANAGEMENT
  // ===========================================

  /// Clear all cached data.
  void clearCache() {
    _folderCache.clear();
    _lruTracker.clear();
  }

  /// Invalidate a specific folder's cache.
  /// Next access will reload from DB.
  void invalidateFolder(int? folderId) {
    _folderCache.remove(folderId);
    _lruTracker.remove(folderId);
  }

  /// Get current cache statistics for debugging.
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedFolders': _folderCache.length,
      'maxCacheSize': _maxCacheSize,
      'lruOrder': List<int?>.from(_lruTracker),
      'totalCachedNotes': _folderCache.values.fold<int>(0, (sum, list) => sum + list.length),
    };
  }

  // ===========================================
  // HELPER METHODS
  // ===========================================

  /// Moves folderId to the end of the list (Most Recently Used)
  void _refreshLru(int? folderId) {
    _lruTracker.remove(folderId);
    _lruTracker.add(folderId);
  }

  /// Removes oldest folders if we exceed the limit
  void _enforceCacheLimit() {
    while (_lruTracker.length > _maxCacheSize) {
      final leastRecentFolderId = _lruTracker.removeAt(0); // Remove from front
      _folderCache.remove(leastRecentFolderId); // Clear actual data
      print('[NotesRepository] Evicted folder $leastRecentFolderId from cache to save memory.');
    }
  }

  /// Sort notes by isPinned DESC, position DESC
  void _sortNotesList(int? folderId) {
    final list = _folderCache[folderId];
    if (list != null) {
      list.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.position.compareTo(a.position);
      });
    }
  }
}

// --- Provider ---
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final db = ref.watch(dbProvider);
  return NotesRepository(db);
});
