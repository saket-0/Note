import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/data_repository.dart';
import '../../features/dashboard/providers/dashboard_state.dart';

/// HardwareCacheEngine V4 - "Unkillable" Singleton with Hardware-Native Optimization
/// 
/// Key Design Decisions:
/// 1. **NO BuildContext dependency** - truly singleton, never rebuilds
/// 2. **ref.listen (not ref.watch)** - react to folder changes without provider rebuild
/// 3. **_memoryCache persists ENTIRE app lifecycle** - only cleared on OS memory warning
/// 4. **patchCache()** - write-through for batch save (inject before UI refresh)
/// 5. **Isolate-based folder scanning** - compute() for 60fps during file listing
/// 
/// Fixes:
/// - Cache wipes on refresh (was: Provider.family rebuilt on folder change)
/// - First load jitter (was: file system scanning on UI thread)
/// - Batch save flickering (was: images not in cache when UI rebuilds)
class HardwareCacheEngine {
  final Ref _ref;
  
  // Job versioning for cancellation
  int _currentJobVersion = 0;
  
  // Ancestor folder hierarchy for pinning (current + all parents)
  final Set<int?> _ancestorFolderIds = {};
  
  // Mapping: image path -> folder ID it belongs to
  final Map<String, int?> _pathToFolderId = {};
  
  // CRITICAL: ImageProvider memory cache - NEVER cleared except on memory warning
  final Map<String, ImageProvider> _memoryCache = {};
  
  // LRU tracking (V5: 5000 images for flagship devices)
  static const int _maxCacheSize = 5000;
  final LinkedHashMap<String, DateTime> _accessOrder = LinkedHashMap();
  
  // Yield-based loading queue
  final Queue<String> _loadQueue = Queue();
  bool _isProcessing = false;
  
  // Reactive notification for cache updates
  final ValueNotifier<int> cacheUpdateNotifier = ValueNotifier(0);
  
  // Track if we've been initialized
  bool _isInitialized = false;
  
  HardwareCacheEngine(this._ref) {
    _initialize();
  }
  
  void _initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    
    // CRITICAL: Use ref.listen (NOT ref.watch) to react to folder changes
    // This allows the engine to respond without being rebuilt/disposed
    _ref.listen<int?>(currentFolderProvider, (previous, next) {
      _onFolderChanged(next);
    });
    
    // Start with root folder
    _updateAncestorHierarchy(null);
    _queueFolderImagesAsync(null);
  }
  
  // === PUBLIC API ===
  
  /// Get cached ImageProvider (synchronous, instant)
  ImageProvider? getProvider(String path) {
    if (_memoryCache.containsKey(path)) {
      _trackAccess(path);
      return _memoryCache[path];
    }
    return null;
  }
  
  /// Check if path is cached
  bool isCached(String path) => _memoryCache.containsKey(path);
  
  /// Get cache size
  int get cacheSize => _memoryCache.length;
  
  /// WRITE-THROUGH: Inject image data directly from memory (for batch save)
  /// Call this BEFORE UI rebuilds to ensure instant display
  void patchCache(String path, Uint8List data, {int? folderId}) {
    final provider = MemoryImage(data);
    _memoryCache[path] = provider;
    _trackAccess(path);
    
    if (folderId != null) {
      _pathToFolderId[path] = folderId;
    }
    
    // Notify listeners immediately
    cacheUpdateNotifier.value++;
  }
  
  /// WRITE-THROUGH: Batch patch multiple images at once
  void patchCacheBatch(List<String> paths, List<Uint8List> data, {int? folderId}) {
    assert(paths.length == data.length, 'paths and data must have same length');
    
    for (int i = 0; i < paths.length; i++) {
      final provider = MemoryImage(data[i]);
      _memoryCache[paths[i]] = provider;
      _trackAccess(paths[i]);
      
      if (folderId != null) {
        _pathToFolderId[paths[i]] = folderId;
      }
    }
    
    // Single notification for all
    cacheUpdateNotifier.value++;
  }
  
  /// WRITE-THROUGH: Inject an already-created ImageProvider
  void injectProvider(String path, ImageProvider provider, {int? folderId}) {
    _memoryCache[path] = provider;
    _trackAccess(path);
    
    if (folderId != null) {
      _pathToFolderId[path] = folderId;
    }
    
    cacheUpdateNotifier.value++;
  }
  
  /// Prioritize loading a specific path (for on-screen items)
  void prioritize(String path) {
    if (_memoryCache.containsKey(path)) return;
    
    // Add to front of queue
    final list = _loadQueue.toList();
    _loadQueue.clear();
    _loadQueue.add(path);
    for (final p in list) {
      if (p != path) _loadQueue.add(p);
    }
    
    _startProcessing();
  }
  
  /// Pre-warm cache for specific folders (call on app launch)
  Future<void> preWarmFolders(List<int?> folderIds) async {
    for (final folderId in folderIds) {
      await _queueFolderImagesAsync(folderId);
    }
    _startProcessing();
  }
  
  /// V5: Scroll-Idle Pre-Fetch
  /// Called when scroll stops - preload next 50 images
  /// This creates the "warm-start" effect where images appear instantly when scrolling resumes
  void onScrollIdle(int currentVisibleIndex, List<String> allFolderPaths) {
    if (allFolderPaths.isEmpty) return;
    
    final startIdx = currentVisibleIndex;
    final endIdx = (startIdx + 50).clamp(0, allFolderPaths.length);
    
    int added = 0;
    for (int i = startIdx; i < endIdx; i++) {
      final path = allFolderPaths[i];
      if (!_memoryCache.containsKey(path) && !_loadQueue.contains(path)) {
        _loadQueue.add(path);
        added++;
      }
    }
    
    if (added > 0) {
      debugPrint('[HardwareCacheEngine] Scroll-idle prefetch: queued $added images');
      _startProcessing();
    }
  }
  
  /// Get all image paths currently in queue (for debugging)
  int get queueLength => _loadQueue.length;
  
  // === INTERNAL ===
  
  void _onFolderChanged(int? newFolderId) {
    _currentJobVersion++;
    
    // Update ancestor hierarchy for pinning
    _updateAncestorHierarchy(newFolderId);
    
    // Queue new folder images (doesn't clear existing cache!)
    _queueFolderImagesAsync(newFolderId);
    
    // Schedule background pre-load for nearby folders
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
  
  /// Queue folder images using Isolate for file system scanning
  Future<void> _queueFolderImagesAsync(int? folderId) async {
    final repo = _ref.read(dataRepositoryProvider);
    final notes = repo.getNotesForFolder(folderId);
    
    // Collect all image paths that need loading
    final pathsToQueue = <String>[];
    
    for (final note in notes) {
      for (final imagePath in note.images) {
        _pathToFolderId[imagePath] = folderId;
        if (!_memoryCache.containsKey(imagePath)) {
          pathsToQueue.add(imagePath);
        }
      }
      if (note.imagePath != null && note.imagePath!.isNotEmpty) {
        _pathToFolderId[note.imagePath!] = folderId;
        if (!_memoryCache.containsKey(note.imagePath!)) {
          pathsToQueue.add(note.imagePath!);
        }
      }
    }
    
    // Use Isolate to verify which files exist (avoids UI thread I/O)
    if (pathsToQueue.isNotEmpty) {
      final existingPaths = await _verifyPathsInIsolate(pathsToQueue);
      for (final path in existingPaths) {
        if (!_loadQueue.contains(path)) {
          _loadQueue.add(path);
        }
      }
      _startProcessing();
    }
  }
  
  /// Verify file existence in an Isolate (60fps friendly)
  Future<List<String>> _verifyPathsInIsolate(List<String> paths) async {
    try {
      return await Isolate.run(() {
        final existing = <String>[];
        for (final path in paths) {
          if (File(path).existsSync()) {
            existing.add(path);
          }
        }
        return existing;
      });
    } catch (e) {
      // Fallback to sync check if Isolate fails
      return paths.where((p) => File(p).existsSync()).toList();
    }
  }
  
  void _scheduleSubfolderPreload(int? currentFolderId) {
    final version = _currentJobVersion;
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (version != _currentJobVersion) return;
      
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
      if (!_memoryCache.containsKey(imagePath) && !_loadQueue.contains(imagePath)) {
        _loadQueue.add(imagePath);
      }
    }
    if (note.imagePath != null && note.imagePath!.isNotEmpty) {
      _pathToFolderId[note.imagePath!] = folderId;
      if (!_memoryCache.containsKey(note.imagePath!) && !_loadQueue.contains(note.imagePath!)) {
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
    
    final path = _loadQueue.removeFirst();
    
    if (_memoryCache.containsKey(path)) {
      await Future.delayed(Duration.zero);
      _processNextItem();
      return;
    }
    
    await _loadImage(path);
    await Future.delayed(Duration.zero); // Yield to UI thread
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
      
      // Precache using rootBundle context (no BuildContext needed)
      // We'll resolve the image manually
      final ImageStream stream = provider.resolve(ImageConfiguration.empty);
      final Completer<void> completer = Completer();
      
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          if (!completer.isCompleted) {
            completer.complete();
          }
          stream.removeListener(listener);
        },
        onError: (exception, stackTrace) {
          if (!completer.isCompleted) {
            completer.complete();
          }
          stream.removeListener(listener);
        },
      );
      
      stream.addListener(listener);
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          stream.removeListener(listener);
        },
      );
      
      _memoryCache[path] = provider;
      _trackAccess(path);
      
      cacheUpdateNotifier.value++;
    } catch (e) {
      // Silently ignore failures
      debugPrint('[HardwareCacheEngine] Failed to load $path: $e');
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
      _memoryCache.remove(evictCandidate);
      _pathToFolderId.remove(evictCandidate);
    }
  }
  
  /// Clear cache on memory warning (called from OS)
  void onMemoryWarning() {
    debugPrint('[HardwareCacheEngine] Memory warning - clearing ${_memoryCache.length} images');
    _memoryCache.clear();
    _accessOrder.clear();
    _pathToFolderId.clear();
    cacheUpdateNotifier.value++;
  }
  
  void dispose() {
    cacheUpdateNotifier.dispose();
  }
}

/// Provider for HardwareCacheEngine - TRUE SINGLETON (keepAlive)
/// 
/// CRITICAL: This provider does NOT use .family or BuildContext dependency.
/// The engine persists for the entire app lifecycle.
final hardwareCacheEngineProvider = Provider<HardwareCacheEngine>((ref) {
  // KEEP ALIVE: Engine persists for entire app session
  ref.keepAlive();
  
  final engine = HardwareCacheEngine(ref);
  
  ref.onDispose(() {
    engine.dispose();
  });
  
  return engine;
});
