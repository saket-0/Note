import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../domain/entities/entities.dart';
import '../../features/dashboard/providers/dashboard_state.dart';
import '../services/layout_service.dart';

/// Unified Data Repository with cache-first architecture.
/// 
/// Features:
/// - Synchronous reads from in-memory cache
/// - Async writes with automatic DB sync
/// - State-based change notifications (reactive UI)
/// - Optimistic updates with rollback on failure
class DataRepository {
  final AppDatabase _db;
  final Ref _ref;
  
  // === IN-MEMORY CACHE ===
  // Folders by parentId (null = root)
  final Map<int?, List<Folder>> _foldersByParent = {};
  // Notes by folderId (null = root)
  final Map<int?, List<Note>> _notesByFolder = {};
  // Archived items (flat)
  final List<dynamic> _archivedItems = [];
  // Trashed items (flat)
  final List<dynamic> _trashedItems = [];
  
  // Temp ID management for optimistic UI
  int _tempIdCounter = -1;
  final Set<int> _pendingIds = {};
  
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;
  
  DataRepository(this._db, this._ref);

  // ===========================================
  // INITIALIZATION
  // ===========================================

  /// Load all data from DB into memory cache.
  /// Call once at app startup.
  Future<void> initialize() async {
    if (_isLoaded) return;
    
    // Clear existing
    _foldersByParent.clear();
    _notesByFolder.clear();
    _archivedItems.clear();
    _trashedItems.clear();
    
    // Batch load (2 queries total, not N+1)
    final allFolders = await _db.getAllFolders();
    final allNotes = await _db.getAllNotes();
    
    // Categorize folders
    for (final folder in allFolders) {
      if (folder.isDeleted) {
        _trashedItems.add(folder);
      } else if (folder.isArchived) {
        _archivedItems.add(folder);
      } else {
        _foldersByParent.putIfAbsent(folder.parentId, () => []).add(folder);
      }
    }
    
    // Categorize notes
    for (final note in allNotes) {
      if (note.isDeleted) {
        _trashedItems.add(note);
      } else if (note.isArchived) {
        _archivedItems.add(note);
      } else {
        _notesByFolder.putIfAbsent(note.folderId, () => []).add(note);
      }
    }
    
    // Sort all cached lists
    _sortAllLists();
    _isLoaded = true;
  }

  void _sortAllLists() {
    for (final list in _foldersByParent.values) {
      list.sort((a, b) => b.position.compareTo(a.position));
    }
    for (final list in _notesByFolder.values) {
      list.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.position.compareTo(a.position);
      });
    }
  }

  void _notifyChange() {
    // Increment version counter to trigger provider rebuilds
    _ref.read(dataVersionProvider.notifier).state++;
  }

  // ===========================================
  // SYNCHRONOUS READS (From Cache)
  // ===========================================

  /// Get active content for a folder (folders + notes)
  List<dynamic> getActiveContent(int? folderId) {
    final folders = List<dynamic>.from(_foldersByParent[folderId] ?? []);
    final notes = List<dynamic>.from(_notesByFolder[folderId] ?? []);
    
    final combined = [...folders, ...notes];
    combined.sort((a, b) {
      final aPinned = (a is Note) ? a.isPinned : false;
      final bPinned = (b is Note) ? b.isPinned : false;
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      return (b as dynamic).position.compareTo((a as dynamic).position);
    });
    
    return combined;
  }

  List<dynamic> getArchivedContent() => List.from(_archivedItems);
  List<dynamic> getTrashedContent() => List.from(_trashedItems);
  
  List<Note> getAllNotes() {
    final all = <Note>[];
    for (final notes in _notesByFolder.values) {
      all.addAll(notes);
    }
    return all;
  }

  List<Note> getNotesForFolder(int? folderId) => List.from(_notesByFolder[folderId] ?? []);
  
  /// Get all image paths for a folder (for preloading)
  List<String> getImagePathsForFolder(int? folderId) {
    final notes = _notesByFolder[folderId] ?? [];
    final paths = <String>[];
    for (final note in notes) {
      if (note.imagePath != null) paths.add(note.imagePath!);
      paths.addAll(note.images);
    }
    return paths;
  }

  /// Get subfolder IDs for prefetching
  List<int> getSubfolderIds(int? parentId) {
    return (_foldersByParent[parentId] ?? []).map((f) => f.id).toList();
  }

  // ===========================================
  // OPTIMISTIC WRITES (Cache-First + Async DB)
  // ===========================================

  int generateTempId() => _tempIdCounter--;
  bool isPending(int id) => _pendingIds.contains(id);

  /// Create folder with optimistic UI
  Future<int> createFolder({
    required String name,
    int? parentId,
    int? position,
  }) async {
    // Calculate position
    final currentItems = getActiveContent(parentId);
    final newPos = position ?? LayoutService.getNewItemPosition(currentItems);
    
    // Optimistic: Add to cache immediately
    final tempId = generateTempId();
    final tempFolder = Folder(
      id: tempId,
      name: name,
      parentId: parentId,
      createdAt: DateTime.now(),
      position: newPos,
    );
    
    _addFolderToCache(tempFolder);
    _pendingIds.add(tempId);
    _notifyChange();
    
    // Persist to DB
    try {
      final realId = await _db.createFolder(name, parentId, position: newPos);
      _resolveTempId(tempId, realId, isFolder: true);
      _notifyChange(); // Notify UI to rebuild with real IDs
      return realId;
    } catch (e) {
      _rollbackTempId(tempId, isFolder: true);
      _notifyChange();
      rethrow;
    }
  }

  /// Create note with optimistic UI
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
    // Calculate position
    final currentItems = getActiveContent(folderId);
    final newPos = position ?? LayoutService.getNewItemPosition(currentItems);
    
    // DEBUG: Trace position calculation
    if (currentItems.isNotEmpty) {
      print('[DEBUG] createNote: folderId=$folderId, currentItems count=${currentItems.length}');
      print('[DEBUG] createNote: first item position=${(currentItems.first as dynamic).position}, newPos=$newPos');
    } else {
      print('[DEBUG] createNote: folderId=$folderId, no current items, newPos=$newPos');
    }
    
    // Optimistic: Add to cache immediately
    final tempId = generateTempId();
    final tempNote = Note(
      id: tempId,
      title: title.isEmpty ? 'Untitled' : title,
      content: content,
      imagePath: imagePath,
      images: images,
      fileType: fileType,
      folderId: folderId,
      createdAt: DateTime.now(),
      color: color,
      isPinned: isPinned,
      isChecklist: isChecklist,
      position: newPos,
    );
    
    _addNoteToCache(tempNote);
    _pendingIds.add(tempId);
    _notifyChange();
    
    // Persist to DB
    try {
      final realId = await _db.createNote(
        title: tempNote.title,
        content: content,
        imagePath: imagePath,
        images: images,
        fileType: fileType,
        folderId: folderId,
        color: color,
        isPinned: isPinned,
        isChecklist: isChecklist,
        position: newPos,
      );
      _resolveTempId(tempId, realId, isFolder: false);
      _notifyChange(); // Notify UI to rebuild with real IDs
      return realId;
    } catch (e) {
      _rollbackTempId(tempId, isFolder: false);
      _notifyChange();
      rethrow;
    }
  }

  /// Update note (cache-first)
  Future<void> updateNote(Note note) async {
    // Skip if note doesn't exist in cache (might be pending creation)
    if (findNote(note.id) == null) {
      // Just persist directly if it's a real ID
      if (note.id > 0) {
        await _db.updateNote(note);
      }
      return;
    }
    
    _updateNoteInCache(note);
    _notifyChange();
    
    // Only persist if it's a real ID (not temp)
    if (note.id > 0) {
      await _db.updateNote(note);
    }
  }

  /// Update folder (cache-first)
  Future<void> updateFolder(Folder folder) async {
    _updateFolderInCache(folder);
    _notifyChange();
    
    if (folder.id > 0) {
      await _db.updateFolder(folder);
    }
  }

  /// Delete note (cache-first)
  Future<void> deleteNote(int id, {bool permanent = false}) async {
    if (permanent) {
      _removeNoteFromCache(id);
    } else {
      // Move to trash
      final note = findNote(id);
      if (note != null) {
        _removeNoteFromCache(id);
        _trashedItems.add(note.copyWith(isDeleted: true));
      }
    }
    _notifyChange();
    
    if (id > 0) {
      await _db.deleteNote(id, permanent: permanent);
    }
  }

  /// Delete folder (cache-first)
  Future<void> deleteFolder(int id, {bool permanent = false}) async {
    if (permanent) {
      _removeFolderFromCache(id);
    } else {
      final folder = findFolder(id);
      if (folder != null) {
        _removeFolderFromCache(id);
        _trashedItems.add(folder.copyWith(isDeleted: true));
      }
    }
    _notifyChange();
    
    if (id > 0) {
      await _db.deleteFolder(id, permanent: permanent);
    }
  }

  /// Archive item (cache-first)
  Future<void> archiveItem(dynamic item, bool archive) async {
    if (item is Folder) {
      _removeFolderFromCache(item.id);
      if (archive) {
        _archivedItems.add(item.copyWith(isArchived: true, isDeleted: false));
      } else {
        _addFolderToCache(item.copyWith(isArchived: false, isDeleted: false));
      }
      _notifyChange();
      if (item.id > 0) await _db.archiveItem(item.id, 'folder', archive);
    } else if (item is Note) {
      _removeNoteFromCache(item.id);
      if (archive) {
        _archivedItems.add(item.copyWith(isArchived: true, isDeleted: false));
      } else {
        _addNoteToCache(item.copyWith(isArchived: false, isDeleted: false));
      }
      _notifyChange();
      if (item.id > 0) await _db.archiveItem(item.id, 'note', archive);
    }
  }

  /// Restore item from trash/archive (cache-first)
  Future<void> restoreItem(dynamic item) async {
    _trashedItems.remove(item);
    _archivedItems.remove(item);
    
    if (item is Folder) {
      _addFolderToCache(item.copyWith(isArchived: false, isDeleted: false));
      _notifyChange();
      if (item.id > 0) await _db.restoreItem(item.id, 'folder');
    } else if (item is Note) {
      _addNoteToCache(item.copyWith(isArchived: false, isDeleted: false));
      _notifyChange();
      if (item.id > 0) await _db.restoreItem(item.id, 'note');
    }
  }

  /// Move note to folder (cache-first)
  Future<void> moveNote(int noteId, int? targetFolderId) async {
    final note = findNote(noteId);
    if (note != null) {
      // Calculate new position (top of target folder)
      final activeItems = getActiveContent(targetFolderId);
      final newPos = LayoutService.getMoveToTopPosition(activeItems);

      final updatedNote = note.copyWith(
        folderId: targetFolderId,
        position: newPos,
      );

      _removeNoteFromCache(noteId);
      _addNoteToCache(updatedNote);
      _notifyChange();

      // Update full note to persist folderId and position
      if (noteId > 0) {
        try {
          await _db.moveNote(noteId, targetFolderId, newPosition: newPos);
        } catch (e) {
          // Error moving note in DB - cache already updated optimistically
        }
      }
    }
  }


  /// Move folder to parent (cache-first)
  Future<void> moveFolder(int folderId, int? targetParentId) async {
    final folder = findFolder(folderId);
    if (folder != null) {
      // Calculate new position (top of target folder)
      final activeItems = getActiveContent(targetParentId);
      final newPos = LayoutService.getMoveToTopPosition(activeItems);

      final updatedFolder = folder.copyWith(
        parentId: targetParentId,
        position: newPos,
      );

      _removeFolderFromCache(folderId);
      _addFolderToCache(updatedFolder);
      _notifyChange();

      if (folderId > 0) {
        try {
          await _db.moveFolder(folderId, targetParentId, newPosition: newPos);
        } catch (e) {
          print('Error moving folder: $e');
        }
      }
    }
  }

  /// Reorder items (batch cache + DB update)
  Future<void> reorderItems(List<dynamic> items) async {
    final updates = <({String type, int id, int position})>[];
    
    final calculatedUpdates = LayoutService.reorderItems(items);
    
    for (final update in calculatedUpdates) {
      final item = update.item;
      final newPos = update.position;
      
      if (item is Folder) {
        _updateFolderInCache(item.copyWith(position: newPos));
        if (item.id > 0) updates.add((type: 'folder', id: item.id, position: newPos));
      } else if (item is Note) {
        _updateNoteInCache(item.copyWith(position: newPos));
        if (item.id > 0) updates.add((type: 'note', id: item.id, position: newPos));
      }
    }
    
    _notifyChange();
    
    if (updates.isNotEmpty) {
      await _db.updatePositions(updates);
    }
  }

  // ===========================================
  // CACHE HELPERS
  // ===========================================

  void _addFolderToCache(Folder folder) {
    if (folder.isDeleted) {
      _trashedItems.add(folder);
    } else if (folder.isArchived) {
      _archivedItems.add(folder);
    } else {
      _foldersByParent.putIfAbsent(folder.parentId, () => []).add(folder);
      _foldersByParent[folder.parentId]!.sort((a, b) => b.position.compareTo(a.position));
    }
  }

  void _addNoteToCache(Note note) {
    if (note.isDeleted) {
      _trashedItems.add(note);
    } else if (note.isArchived) {
      _archivedItems.add(note);
    } else {
      _notesByFolder.putIfAbsent(note.folderId, () => []).add(note);
      _notesByFolder[note.folderId]!.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.position.compareTo(a.position);
      });
    }
  }

  void _removeFolderFromCache(int id) {
    for (final list in _foldersByParent.values) {
      list.removeWhere((f) => f.id == id);
    }
    _archivedItems.removeWhere((item) => item is Folder && item.id == id);
    _trashedItems.removeWhere((item) => item is Folder && item.id == id);
  }

  void _removeNoteFromCache(int id) {
    for (final list in _notesByFolder.values) {
      list.removeWhere((n) => n.id == id);
    }
    _archivedItems.removeWhere((item) => item is Note && item.id == id);
    _trashedItems.removeWhere((item) => item is Note && item.id == id);
  }

  void _updateFolderInCache(Folder folder) {
    _removeFolderFromCache(folder.id);
    _addFolderToCache(folder);
  }

  void _updateNoteInCache(Note note) {
    _removeNoteFromCache(note.id);
    _addNoteToCache(note);
  }

  Folder? findFolder(int id) {
    for (final list in _foldersByParent.values) {
      for (final f in list) {
        if (f.id == id) return f;
      }
    }
    for (final item in _archivedItems) {
      if (item is Folder && item.id == id) return item;
    }
    for (final item in _trashedItems) {
      if (item is Folder && item.id == id) return item;
    }
    return null;
  }

  Note? findNote(int id) {
    for (final list in _notesByFolder.values) {
      for (final n in list) {
        if (n.id == id) return n;
      }
    }
    for (final item in _archivedItems) {
      if (item is Note && item.id == id) return item;
    }
    for (final item in _trashedItems) {
      if (item is Note && item.id == id) return item;
    }
    return null;
  }

  void _resolveTempId(int tempId, int realId, {required bool isFolder}) {
    _pendingIds.remove(tempId);
    
    if (isFolder) {
      for (final list in _foldersByParent.values) {
        final idx = list.indexWhere((f) => f.id == tempId);
        if (idx != -1) {
          final folder = list[idx];
          list[idx] = Folder(
            id: realId,
            name: folder.name,
            parentId: folder.parentId,
            createdAt: folder.createdAt,
            position: folder.position,
            isArchived: folder.isArchived,
            isDeleted: folder.isDeleted,
          );
          return;
        }
      }
    } else {
      for (final list in _notesByFolder.values) {
        final idx = list.indexWhere((n) => n.id == tempId);
        if (idx != -1) {
          final note = list[idx];
          list[idx] = Note(
            id: realId,
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
          return;
        }
      }
    }
  }

  void _rollbackTempId(int tempId, {required bool isFolder}) {
    _pendingIds.remove(tempId);
    if (isFolder) {
      _removeFolderFromCache(tempId);
    } else {
      _removeNoteFromCache(tempId);
    }
  }

  void dispose() {
    // No cleanup needed now
  }
}

// === PROVIDER ===
final dataRepositoryProvider = Provider<DataRepository>((ref) {
  final db = ref.watch(dbProvider);
  return DataRepository(db, ref);
});
