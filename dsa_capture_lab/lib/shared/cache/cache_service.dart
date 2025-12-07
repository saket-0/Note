import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../domain/entities/entities.dart';

/// In-Memory Cache for instant data access.
/// All UI reads from here. Database is only for persistence.
class CacheService {
  // Folders grouped by parentId (null = root)
  final Map<int?, List<Folder>> _foldersByParent = {};
  
  // Notes grouped by folderId (null = root)
  final Map<int?, List<Note>> _notesByFolder = {};
  
  // All archived items (flat list)
  final List<dynamic> _archivedItems = [];
  
  // All trashed items (flat list)
  final List<dynamic> _trashedItems = [];
  
  // Temp ID counter (negative to avoid collision with real DB IDs)
  int _tempIdCounter = -1;
  
  // Pending operations tracking (tempId -> pending status)
  final Set<int> _pendingIds = {};
  
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  /// Load ALL data from database into memory.
  /// Called once at app startup.
  Future<void> load(AppDatabase db) async {
    // Clear existing
    _foldersByParent.clear();
    _notesByFolder.clear();
    _archivedItems.clear();
    _trashedItems.clear();
    
    // 1. Load ALL active folders
    final allFolders = await db.getAllFolders();
    for (var folder in allFolders) {
      if (folder.isDeleted) {
        _trashedItems.add(folder);
      } else if (folder.isArchived) {
        _archivedItems.add(folder);
      } else {
        _foldersByParent.putIfAbsent(folder.parentId, () => []).add(folder);
      }
    }
    
    // 2. Load ALL active notes
    final allNotes = await db.getAllNotes();
    for (var note in allNotes) {
      if (note.isDeleted) {
        _trashedItems.add(note);
      } else if (note.isArchived) {
        _archivedItems.add(note);
      } else {
        _notesByFolder.putIfAbsent(note.folderId, () => []).add(note);
      }
    }
    
    // Sort each list
    _sortAllLists();
    
    _isLoaded = true;
  }
  
  void _sortAllLists() {
    for (var list in _foldersByParent.values) {
      list.sort((a, b) => a.position.compareTo(b.position));
    }
    for (var list in _notesByFolder.values) {
      list.sort((a, b) {
        // Pinned first, then position
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.position.compareTo(b.position);
      });
    }
  }

  // --- READ Operations (Synchronous!) ---
  
  List<dynamic> getActiveContent(int? folderId) {
    // 1. Get from Active Maps
    final activeFolders = _foldersByParent[folderId] ?? [];
    final activeNotes = _notesByFolder[folderId] ?? [];
    
    // 2. Get from Archive (Linear search, but cache is in-memory so fast enough for now)
    final archivedFolders = _archivedItems.where((i) => i is Folder && i.parentId == folderId);
    final archivedNotes = _archivedItems.where((i) => i is Note && i.folderId == folderId);
    
    // 3. Get from Trash
    final trashFolders = _trashedItems.where((i) => i is Folder && i.parentId == folderId);
    final trashNotes = _trashedItems.where((i) => i is Note && i.folderId == folderId);
    
    final combined = [
      ...activeFolders, ...activeNotes,
      ...archivedFolders, ...archivedNotes,
      ...trashFolders, ...trashNotes
    ];
    
    // Sort combined list:
    // 1. Pinned Notes Top
    // 2. Position Ascending (respects user reordering)
    combined.sort((a, b) {
      final bool aPinned = (a is Note) ? a.isPinned : false;
      final bool bPinned = (b is Note) ? b.isPinned : false;
      
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      
      // Both pinned or both not pinned: Sort by position
      final int aPos = (a as dynamic).position;
      final int bPos = (b as dynamic).position;
      return aPos.compareTo(bPos); // Ascending
    });
    
    return combined;
  }
  
  List<dynamic> getArchivedContent() => List.from(_archivedItems);
  
  List<dynamic> getTrashedContent() => List.from(_trashedItems);
  
  /// Get ALL notes across all folders (for search)
  List<Note> getAllNotes() {
    final List<Note> all = [];
    for (final notes in _notesByFolder.values) {
      all.addAll(notes);
    }
    return all;
  }

  // --- WRITE Operations (Update cache, return for UI) ---
  
  void addFolder(Folder folder) {
    if (folder.isDeleted) {
      _trashedItems.add(folder);
    } else if (folder.isArchived) {
      _archivedItems.add(folder);
    } else {
      _foldersByParent.putIfAbsent(folder.parentId, () => []).add(folder);
    }
  }
  
  void addNote(Note note) {
    if (note.isDeleted) {
      _trashedItems.add(note);
    } else if (note.isArchived) {
      _archivedItems.add(note);
    } else {
      _notesByFolder.putIfAbsent(note.folderId, () => []).add(note);
    }
  }
  
  void removeFolder(int folderId) {
    for (var list in _foldersByParent.values) {
      list.removeWhere((f) => f.id == folderId);
    }
    _archivedItems.removeWhere((item) => item is Folder && item.id == folderId);
    _trashedItems.removeWhere((item) => item is Folder && item.id == folderId);
  }
  
  void removeNote(int noteId) {
    for (var list in _notesByFolder.values) {
      list.removeWhere((n) => n.id == noteId);
    }
    _archivedItems.removeWhere((item) => item is Note && item.id == noteId);
    _trashedItems.removeWhere((item) => item is Note && item.id == noteId);
  }
  
  void updateFolder(Folder updated) {
    removeFolder(updated.id);
    addFolder(updated);
  }
  
  void updateNote(Note updated) {
    removeNote(updated.id);
    addNote(updated);
  }
  
  /// Move item between states (active <-> archived <-> trash)
  void moveToTrash(dynamic item) {
    if (item is Folder) {
      removeFolder(item.id);
      _trashedItems.add(item.copyWith(isDeleted: true));
    } else if (item is Note) {
      removeNote(item.id);
      _trashedItems.add(item.copyWith(isDeleted: true));
    }
  }
  
  void moveToArchive(dynamic item) {
    if (item is Folder) {
      removeFolder(item.id);
      _archivedItems.add(item.copyWith(isArchived: true, isDeleted: false));
    } else if (item is Note) {
      removeNote(item.id);
      _archivedItems.add(item.copyWith(isArchived: true, isDeleted: false));
    }
  }
  
  void restoreToActive(dynamic item) {
    if (item is Folder) {
      removeFolder(item.id);
      addFolder(item.copyWith(isArchived: false, isDeleted: false));
    } else if (item is Note) {
      removeNote(item.id);
      addNote(item.copyWith(isArchived: false, isDeleted: false));
    }
  }
  
  void permanentlyDelete(dynamic item) {
    if (item is Folder) {
      removeFolder(item.id);
    } else if (item is Note) {
      removeNote(item.id);
    }
  }

  // ===========================================
  // OPTIMISTIC UI METHODS
  // ===========================================

  /// Generate a temporary ID for optimistic UI updates
  /// Uses negative numbers to avoid collision with real DB IDs
  int generateTempId() => _tempIdCounter--;

  /// Add note optimistically with temp ID for instant display
  int addNoteOptimistic(Note note) {
    addNote(note);
    _pendingIds.add(note.id);
    return note.id;
  }

  /// Add folder optimistically with temp ID for instant display
  int addFolderOptimistic(Folder folder) {
    addFolder(folder);
    _pendingIds.add(folder.id);
    return folder.id;
  }

  /// Check if an ID is pending (temp ID not yet resolved)
  bool isPending(int id) => _pendingIds.contains(id);

  /// Swap temp ID with real DB ID after successful persistence
  void resolveTempId(int tempId, int realId, {required bool isFolder}) {
    _pendingIds.remove(tempId);
    
    if (isFolder) {
      for (var list in _foldersByParent.values) {
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
      for (var list in _notesByFolder.values) {
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

  /// Rollback: Remove item if DB operation failed
  void rollbackTempId(int tempId, {required bool isFolder}) {
    _pendingIds.remove(tempId);
    if (isFolder) {
      removeFolder(tempId);
    } else {
      removeNote(tempId);
    }
  }

  // ===========================================
  // PREFETCHING HELPERS
  // ===========================================

  /// Get subfolder IDs for a parent (for prefetching)
  List<int> getSubfolderIds(int? parentId) {
    return (_foldersByParent[parentId] ?? []).map((f) => f.id).toList();
  }

  /// Get notes for a specific folder (for prefetching)
  List<Note> getNotesForFolder(int? folderId) {
    return List.from(_notesByFolder[folderId] ?? []);
  }

  /// Get all image paths for a folder (for image preloading)
  List<String> getImagePathsForFolder(int? folderId) {
    final notes = _notesByFolder[folderId] ?? [];
    final paths = <String>[];
    for (final note in notes) {
      if (note.imagePath != null) paths.add(note.imagePath!);
      paths.addAll(note.images);
    }
    return paths;
  }
}

// --- Riverpod Provider ---
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});
