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
/// - Lazy loading: Notes loaded on-demand per folder (not all at startup)
class DataRepository {
  final AppDatabase _db;
  final Ref _ref;
  
  // === IN-MEMORY CACHE ===
  // Folders by parentId (null = root) - loaded at startup
  final Map<int?, List<Folder>> _foldersByParent = {};
  // Notes by folderId (null = root) - LAZY LOADED on-demand
  final Map<int?, List<Note>> _notesByFolder = {};
  // Track which folders have been loaded from DB
  final Set<int?> _loadedNotesFolders = {};
  // LRU order for note folders (oldest first)
  final List<int?> _notesFolderLRU = [];
  // Maximum number of folders to keep notes cached for
  static const int _maxCachedFolders = 15;
  
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

  /// Load folder tree and archive/trash from DB into memory cache.
  /// Notes are lazy-loaded per folder on first access.
  /// Call once at app startup.
  Future<void> initialize() async {
    if (_isLoaded) return;
    
    // Clear existing
    _foldersByParent.clear();
    _notesByFolder.clear();
    _loadedNotesFolders.clear();
    _notesFolderLRU.clear();
    _archivedItems.clear();
    _trashedItems.clear();
    
    // Load only folders at startup (notes are lazy-loaded)
    final allFolders = await _db.getAllFolders();
    
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
    
    // Load archived/trashed notes (for trash/archive view)
    final archivedNotes = await _db.getArchivedNotes();
    final trashedNotes = await _db.getTrashedNotes();
    
    for (final note in archivedNotes) {
      _archivedItems.add(note);
    }
    for (final note in trashedNotes) {
      _trashedItems.add(note);
    }
    
    // Sort folder lists
    _sortFolderLists();
    _isLoaded = true;
    
    // Pre-load root folder notes for instant display
    await _ensureNotesLoaded(null);
  }
  
  /// Lazy load notes for a specific folder from DB
  Future<void> _ensureNotesLoaded(int? folderId) async {
    if (_loadedNotesFolders.contains(folderId)) {
      // Already loaded - just update LRU
      _updateNotesLRU(folderId);
      return;
    }
    
    // Load from DB
    final notes = await _db.getNotesForFolder(folderId);
    _notesByFolder[folderId] = notes;
    _loadedNotesFolders.add(folderId);
    _notesFolderLRU.add(folderId);
    
    // Sort the new list
    _sortNotesList(folderId);
    
    // Evict oldest if over limit
    _evictOldNotesFolders();
  }
  
  void _updateNotesLRU(int? folderId) {
    _notesFolderLRU.remove(folderId);
    _notesFolderLRU.add(folderId);
  }
  
  void _evictOldNotesFolders() {
    while (_notesFolderLRU.length > _maxCachedFolders) {
      final oldestFolderId = _notesFolderLRU.removeAt(0);
      // Only evict if no pending writes for this folder
      final notes = _notesByFolder[oldestFolderId] ?? [];
      final hasPending = notes.any((n) => _pendingIds.contains(n.id));
      if (!hasPending) {
        _notesByFolder.remove(oldestFolderId);
        _loadedNotesFolders.remove(oldestFolderId);
      } else {
        // Has pending, put back at end
        _notesFolderLRU.add(oldestFolderId);
      }
    }
  }

  void _sortFolderLists() {
    for (final list in _foldersByParent.values) {
      list.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.position.compareTo(a.position);
      });
    }
  }
  
  void _sortNotesList(int? folderId) {
    final list = _notesByFolder[folderId];
    if (list != null) {
      list.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.position.compareTo(a.position);
      });
    }
  }

  void _notifyChange() {
    // Increment version counter to trigger provider rebuilds
    final newVersion = _ref.read(dataVersionProvider.notifier).state + 1;
    _ref.read(dataVersionProvider.notifier).state = newVersion;
    print('[REPO] _notifyChange: version now = $newVersion');
    
    // Force invalidation of content providers to ensure fresh data
    _ref.invalidate(activeContentProvider);
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
      final aPinned = (a is Note) ? a.isPinned : (a is Folder ? a.isPinned : false);
      final bPinned = (b is Note) ? b.isPinned : (b is Folder ? b.isPinned : false);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      return (b as dynamic).position.compareTo((a as dynamic).position);
    });
    
    // Debug: Show first 3 items with pinned state
    for (int i = 0; i < combined.length && i < 3; i++) {
      final item = combined[i];
      if (item is Note) {
        print('[REPO] getActiveContent[$i]: Note id=${item.id}, isPinned=${item.isPinned}');
      } else if (item is Folder) {
        print('[REPO] getActiveContent[$i]: Folder id=${item.id}, isPinned=${item.isPinned}');
      }
    }
    
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
    print('[REPO] updateNote called for id=${note.id}, isPinned=${note.isPinned}');
    
    // Skip if note doesn't exist in cache (might be pending creation)
    final existingNote = findNote(note.id);
    if (existingNote == null) {
      print('[REPO] updateNote: Note NOT found in cache, skipping cache update');
      // Just persist directly if it's a real ID
      if (note.id > 0) {
        await _db.updateNote(note);
      }
      return;
    }
    
    print('[REPO] updateNote: Found existing note isPinned=${existingNote.isPinned}, updating to isPinned=${note.isPinned}');
    _updateNoteInCache(note);
    _notifyChange();
    
    // Only persist if it's a real ID (not temp)
    if (note.id > 0) {
      await _db.updateNote(note);
    }
    print('[REPO] updateNote: Complete');
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
      // Move to trash - also unpin the item
      final note = findNote(id);
      if (note != null) {
        _removeNoteFromCache(id);
        _trashedItems.add(note.copyWith(isDeleted: true, isPinned: false));
      }
    }
    _notifyChange();
    
    if (id > 0) {
      await _db.deleteNote(id, permanent: permanent, unpin: !permanent);
    }
  }

  /// Delete folder (cache-first)
  Future<void> deleteFolder(int id, {bool permanent = false}) async {
    if (permanent) {
      _removeFolderFromCache(id);
    } else {
      // Move to trash - also unpin the item
      final folder = findFolder(id);
      if (folder != null) {
        _removeFolderFromCache(id);
        _trashedItems.add(folder.copyWith(isDeleted: true, isPinned: false));
      }
    }
    _notifyChange();
    
    if (id > 0) {
      await _db.deleteFolder(id, permanent: permanent, unpin: !permanent);
    }
  }

  /// Archive item (cache-first)
  /// When archiving, also unpins the item so it doesn't reappear as pinned on restore.
  Future<void> archiveItem(dynamic item, bool archive) async {
    if (item is Folder) {
      _removeFolderFromCache(item.id);
      if (archive) {
        // Unpin when archiving
        _archivedItems.add(item.copyWith(isArchived: true, isDeleted: false, isPinned: false));
      } else {
        _addFolderToCache(item.copyWith(isArchived: false, isDeleted: false));
      }
      _notifyChange();
      if (item.id > 0) await _db.archiveItem(item.id, 'folder', archive, unpin: archive);
    } else if (item is Note) {
      _removeNoteFromCache(item.id);
      if (archive) {
        // Unpin when archiving
        _archivedItems.add(item.copyWith(isArchived: true, isDeleted: false, isPinned: false));
      } else {
        _addNoteToCache(item.copyWith(isArchived: false, isDeleted: false));
      }
      _notifyChange();
      if (item.id > 0) await _db.archiveItem(item.id, 'note', archive, unpin: archive);
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
  /// When moving to a different folder, the item is automatically unpinned.
  Future<void> moveNote(int noteId, int? targetFolderId) async {
    final note = findNote(noteId);
    if (note != null) {
      // Calculate new position (top of target folder)
      final activeItems = getActiveContent(targetFolderId);
      final newPos = LayoutService.getMoveToTopPosition(activeItems);

      // Unpin when moving to a different folder
      final updatedNote = note.copyWith(
        folderId: targetFolderId,
        position: newPos,
        isPinned: false,
      );

      _removeNoteFromCache(noteId);
      _addNoteToCache(updatedNote);
      _notifyChange();

      // Update full note to persist folderId, position, and isPinned
      if (noteId > 0) {
        try {
          await _db.moveNote(noteId, targetFolderId, newPosition: newPos, unpin: true);
        } catch (e) {
          // Error moving note in DB - cache already updated optimistically
        }
      }
    }
  }


  /// Move folder to parent (cache-first)
  /// When moving to a different parent, the folder is automatically unpinned.
  Future<void> moveFolder(int folderId, int? targetParentId) async {
    final folder = findFolder(folderId);
    if (folder != null) {
      // Calculate new position (top of target folder)
      final activeItems = getActiveContent(targetParentId);
      final newPos = LayoutService.getMoveToTopPosition(activeItems);

      // Unpin when moving to a different folder
      final updatedFolder = folder.copyWith(
        parentId: targetParentId,
        position: newPos,
        isPinned: false,
      );

      _removeFolderFromCache(folderId);
      _addFolderToCache(updatedFolder);
      _notifyChange();

      if (folderId > 0) {
        try {
          await _db.moveFolder(folderId, targetParentId, newPosition: newPos, unpin: true);
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
  // BATCH OPERATIONS (Single UI Rebuild)
  // ===========================================

  /// Archive multiple items atomically.
  /// 
  /// Cache-first: Updates all items in cache, triggers ONE UI rebuild,
  /// then persists to DB in a single transaction.
  /// 
  /// Reusable for: selection bar archive, bulk archive, automation, etc.
  Future<void> archiveItems(List<dynamic> items, bool archive) async {
    if (items.isEmpty) return;
    
    final dbUpdates = <({int id, String type})>[];
    
    // Step 1: Update cache for ALL items
    for (final item in items) {
      if (item is Folder) {
        _removeFolderFromCache(item.id);
        if (archive) {
          _archivedItems.add(item.copyWith(isArchived: true, isDeleted: false));
        } else {
          _addFolderToCache(item.copyWith(isArchived: false, isDeleted: false));
        }
        if (item.id > 0) dbUpdates.add((id: item.id, type: 'folder'));
      } else if (item is Note) {
        _removeNoteFromCache(item.id);
        if (archive) {
          _archivedItems.add(item.copyWith(isArchived: true, isDeleted: false));
        } else {
          _addNoteToCache(item.copyWith(isArchived: false, isDeleted: false));
        }
        if (item.id > 0) dbUpdates.add((id: item.id, type: 'note'));
      }
    }
    
    // Step 2: Single UI notification
    _notifyChange();
    
    // Step 3: Batch DB persist
    if (dbUpdates.isNotEmpty) {
      await _db.archiveItemsBatch(dbUpdates, archive);
    }
  }

  /// Delete multiple items atomically.
  /// 
  /// Cache-first: Updates all items in cache, triggers ONE UI rebuild,
  /// then persists to DB in a single transaction.
  /// 
  /// Reusable for: selection bar delete, bulk cleanup, etc.
  Future<void> deleteItems(List<dynamic> items, {required bool permanent}) async {
    if (items.isEmpty) return;
    
    final dbUpdates = <({int id, String type})>[];
    
    // Step 1: Update cache for ALL items
    for (final item in items) {
      if (item is Folder) {
        if (permanent) {
          _removeFolderFromCache(item.id);
        } else {
          _removeFolderFromCache(item.id);
          _trashedItems.add(item.copyWith(isDeleted: true));
        }
        if (item.id > 0) dbUpdates.add((id: item.id, type: 'folder'));
      } else if (item is Note) {
        if (permanent) {
          _removeNoteFromCache(item.id);
        } else {
          _removeNoteFromCache(item.id);
          _trashedItems.add(item.copyWith(isDeleted: true));
        }
        if (item.id > 0) dbUpdates.add((id: item.id, type: 'note'));
      }
    }
    
    // Step 2: Single UI notification
    _notifyChange();
    
    // Step 3: Batch DB persist
    if (dbUpdates.isNotEmpty) {
      await _db.deleteItemsBatch(dbUpdates, permanent: permanent);
    }
  }

  /// Move multiple items to a target folder atomically.
  /// 
  /// Cache-first: Calculates stacked positions, updates all items in cache,
  /// triggers ONE UI rebuild, then persists to DB in a single transaction.
  /// 
  /// Reusable for: grouping into folder, bulk reorganization, etc.
  Future<void> moveItems(List<dynamic> items, int? targetFolderId) async {
    if (items.isEmpty) return;
    
    final dbUpdates = <({int id, String type, int position})>[];
    
    // Calculate positions: first item gets highest position (top), then stacked below
    final existingItems = getActiveContent(targetFolderId);
    int basePosition = LayoutService.getMoveToTopPosition(existingItems);
    const positionSpacing = 1000; // Space between stacked items
    
    // Step 1: Update cache for ALL items with stacked positions
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      // First item at top (highest position), subsequent items below
      final newPos = basePosition + ((items.length - 1 - i) * positionSpacing);
      
      if (item is Folder) {
        _removeFolderFromCache(item.id);
        _addFolderToCache(item.copyWith(parentId: targetFolderId, position: newPos));
        if (item.id > 0) dbUpdates.add((id: item.id, type: 'folder', position: newPos));
      } else if (item is Note) {
        _removeNoteFromCache(item.id);
        _addNoteToCache(item.copyWith(folderId: targetFolderId, position: newPos));
        if (item.id > 0) dbUpdates.add((id: item.id, type: 'note', position: newPos));
      }
    }
    
    // Step 2: Single UI notification
    _notifyChange();
    
    // Step 3: Batch DB persist
    if (dbUpdates.isNotEmpty) {
      await _db.moveItemsBatch(dbUpdates, targetFolderId);
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
      _foldersByParent[folder.parentId]!.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.position.compareTo(a.position);
      });
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
