import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/data_repository.dart';
import '../../features/dashboard/providers/dashboard_state.dart';

/// SmoothCacheEngine V3.1 - With Write-Through Caching & Ancestral Pinning
/// 
/// Features:
/// - **Yield-based scheduler**: 1 image → yield → next (60fps friendly)
/// - **Write-through cache**: Inject memory data directly (no disk read)
/// - **Ancestral pinning**: Never evict parent folder images
/// - **ImageProvider cache**: Reuse hydrated streams, no re-decoding
/// - **Predictive pre-load**: Subfolders loaded on idle
class SmoothCacheEngine {
  final Ref _ref;
  final BuildContext _context;
  
  // Job versioning for cancellation
  int _currentJobVersion = 0;
  
  // Ancestor folder hierarchy for pinning (current + all parents)
  final Set<int?> _ancestorFolderIds = {};
  
  // Mapping: image path -> folder ID it belongs to
  final Map<String, int?> _pathToFolderId = {};
  
  // Yield-based loading queue
  final Queue<String> _loadQueue = Queue();
  bool _isProcessing = false;
  
  // CRITICAL: ImageProvider memory cache
  final Map<String, ImageProvider> _providerCache = {};
  
  // LRU tracking
  static const int _maxCacheSize = 300;
  final LinkedHashMap<String, DateTime> _accessOrder = LinkedHashMap();
  
  // Reactive notification
  final ValueNotifier<int> cacheUpdateNotifier = ValueNotifier(0);
  
  SmoothCacheEngine(this._ref, this._context) {
    _ref.listen<int?>(currentFolderProvider, (previous, next) {
      _onFolderChanged(next);
    });
    
    // Start loading root folder
    _updateAncestorHierarchy(null);
    _queueFolderImages(null);
    _startProcessing();
  }
  
  // === PUBLIC API ===
  
  /// Get cached ImageProvider (synchronous, instant)
  ImageProvider? getProvider(String path) {
    if (_providerCache.containsKey(path)) {
      _trackAccess(path);
      return _providerCache[path];
    }
    return null;
  }
  
  /// Check if path is cached
  bool isCached(String path) => _providerCache.containsKey(path);
  
  /// WRITE-THROUGH: Inject image data directly from memory
  /// Call this during batch save to avoid disk reads
  void injectMemoryCache(String path, Uint8List data, {int? folderId}) {
    final provider = MemoryImage(data);
    _providerCache[path] = provider;
    _trackAccess(path);
    
    if (folderId != null) {
      _pathToFolderId[path] = folderId;
    }
    
    // Notify listeners immediately
    cacheUpdateNotifier.value++;
  }
  
  /// WRITE-THROUGH: Inject an already-created ImageProvider
  void injectProvider(String path, ImageProvider provider, {int? folderId}) {
    _providerCache[path] = provider;
    _trackAccess(path);
    
    if (folderId != null) {
      _pathToFolderId[path] = folderId;
    }
    
    cacheUpdateNotifier.value++;
  }
  
  /// Prioritize loading a specific path (for on-screen items)
  void prioritize(String path) {
    if (_providerCache.containsKey(path)) return;
    
    // Add to front of queue
    final list = _loadQueue.toList();
    _loadQueue.clear();
    _loadQueue.add(path);
    for (final p in list) {
      if (p != path) _loadQueue.add(p);
    }
    
    _startProcessing();
  }
  
  // === INTERNAL ===
  
  void _onFolderChanged(int? newFolderId) {
    _currentJobVersion++;
    
    // Update ancestor hierarchy for pinning
    _updateAncestorHierarchy(newFolderId);
    
    // Clear queue and reload for new folder
    _loadQueue.clear();
    _queueFolderImages(newFolderId);
    _startProcessing();
    
    // Schedule background pre-load
    _scheduleSubfolderPreload(newFolderId);
  }
  
  /// Build the ancestor hierarchy for pinning
  void _updateAncestorHierarchy(int? folderId) {
    _ancestorFolderIds.clear();
    _ancestorFolderIds.add(folderId); // Current folder
    
    if (folderId == null) return;
    
    final repo = _ref.read(dataRepositoryProvider);
    int? currentId = folderId;
    
    // Walk up the tree
    while (currentId != null) {
      final folder = repo.findFolder(currentId);
      if (folder == null) break;
      
      _ancestorFolderIds.add(folder.parentId);
      currentId = folder.parentId;
    }
  }
  
  void _queueFolderImages(int? folderId) {
    final repo = _ref.read(dataRepositoryProvider);
    final notes = repo.getNotesForFolder(folderId);
    
    for (final note in notes) {
      for (final imagePath in note.images) {
        _pathToFolderId[imagePath] = folderId;
        if (!_providerCache.containsKey(imagePath)) {
          _loadQueue.add(imagePath);
        }
      }
      if (note.imagePath != null && note.imagePath!.isNotEmpty) {
        _pathToFolderId[note.imagePath!] = folderId;
        if (!_providerCache.containsKey(note.imagePath!)) {
          _loadQueue.add(note.imagePath!);
        }
      }
    }
  }
  
  void _scheduleSubfolderPreload(int? currentFolderId) {
    final version = _currentJobVersion;
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (version != _currentJobVersion) return;
      if (!_context.mounted) return;
      
      final repo = _ref.read(dataRepositoryProvider);
      
      // Parent folder (IMPORTANT: pre-load for back navigation)
      if (currentFolderId != null) {
        final folder = repo.findFolder(currentFolderId);
        if (folder != null) {
          final parentNotes = repo.getNotesForFolder(folder.parentId);
          for (final note in parentNotes) {
            _addToQueueIfNeeded(note, folder.parentId);
          }
        }
      }
      
      // Subfolders (first 5 items each)
      final subfolderIds = repo.getSubfolderIds(currentFolderId);
      for (final subfolderId in subfolderIds) {
        final subNotes = repo.getNotesForFolder(subfolderId);
        for (final note in subNotes.take(5)) {
          _addToQueueIfNeeded(note, subfolderId);
        }
      }
      
      _startProcessing();
    });
  }
  
  void _addToQueueIfNeeded(Note note, int? folderId) {
    for (final imagePath in note.images) {
      _pathToFolderId[imagePath] = folderId;
      if (!_providerCache.containsKey(imagePath) && !_loadQueue.contains(imagePath)) {
        _loadQueue.add(imagePath);
      }
    }
    if (note.imagePath != null && note.imagePath!.isNotEmpty) {
      _pathToFolderId[note.imagePath!] = folderId;
      if (!_providerCache.containsKey(note.imagePath!) && !_loadQueue.contains(note.imagePath!)) {
        _loadQueue.add(note.imagePath!);
      }
    }
  }
  
  void _startProcessing() {
    if (_isProcessing) return;
    _isProcessing = true;
    _processNextItem();
  }
  
  Future<void> _processNextItem() async {
    if (_loadQueue.isEmpty) {
      _isProcessing = false;
      return;
    }
    
    if (!_context.mounted) {
      _isProcessing = false;
      return;
    }
    
    final path = _loadQueue.removeFirst();
    
    if (_providerCache.containsKey(path)) {
      await Future.delayed(Duration.zero);
      _processNextItem();
      return;
    }
    
    await _loadImage(path);
    await Future.delayed(Duration.zero);
    _processNextItem();
  }
  
  Future<void> _loadImage(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;
      
      final provider = ResizeImage(
        FileImage(file),
        width: 400,
      );
      
      if (!_context.mounted) return;
      
      await precacheImage(provider, _context);
      
      _providerCache[path] = provider;
      _trackAccess(path);
      
      cacheUpdateNotifier.value++;
    } catch (e) {
      // Silently ignore failures
    }
  }
  
  void _trackAccess(String path) {
    _accessOrder.remove(path);
    _accessOrder[path] = DateTime.now();
    
    // ANCESTRAL PINNING: Only evict non-ancestor images
    while (_accessOrder.length > _maxCacheSize) {
      String? evictCandidate;
      
      // Find first non-ancestor image to evict
      for (final candidatePath in _accessOrder.keys) {
        final folderId = _pathToFolderId[candidatePath];
        
        // NEVER evict images from ancestor folders
        if (!_ancestorFolderIds.contains(folderId)) {
          evictCandidate = candidatePath;
          break;
        }
      }
      
      if (evictCandidate == null) {
        // All images are from ancestor folders, can't evict
        break;
      }
      
      _accessOrder.remove(evictCandidate);
      _providerCache.remove(evictCandidate);
      _pathToFolderId.remove(evictCandidate);
    }
  }
  
  void dispose() {
    cacheUpdateNotifier.dispose();
  }
}

/// Provider for SmoothCacheEngine with keepAlive for session persistence
final smoothCacheEngineProvider = Provider.family<SmoothCacheEngine, BuildContext>((ref, context) {
  // KEEP ALIVE: Cache persists for entire app session
  ref.keepAlive();
  
  final engine = SmoothCacheEngine(ref, context);
  
  ref.onDispose(() {
    engine.dispose();
  });
  
  return engine;
});
