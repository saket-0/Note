import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';

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
    
    // Combine ALL (Function is "getContent", filtering is done by Dashboard View if needed? 
    // Wait, if I am in "Active" filter, I only want active items.
    // If I am in "Archive" filter, I want archived items? 
    // actually, if I am navigating INSIDE a folder, the folder itself dictates the context?
    // User said: "open a folder in the archive section".
    // If a folder is archived, its children are effectively hidden even if they are not explicitly marked "archived" in DB? 
    // Or does "Archive Folder" cascade archive children? DB logic says "No cascade" usually unless explicit.
    // Let's assume children might still be "active" but just inside an archived folder.
    // OR children are also archived.
    // To support "Navigation inside archive", we should probably show EVERYTHING inside that folder.
    
    final combined = [
      ...activeFolders, ...activeNotes,
      ...archivedFolders, ...archivedNotes,
      ...trashFolders, ...trashNotes
    ];
    
    // Sort combined list:
    // 1. Pinned Notes Top
    // 2. CreatedAt Descending (Newest First)
    combined.sort((a, b) {
      final bool aPinned = (a is Note) ? a.isPinned : false;
      final bool bPinned = (b is Note) ? b.isPinned : false;
      
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      
      // Both pinned or both not pinned: Sort by Date
      final DateTime aDate = (a as dynamic).createdAt;
      final DateTime bDate = (b as dynamic).createdAt;
      return bDate.compareTo(aDate); // Descending
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
}

// --- Riverpod Provider ---
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});
