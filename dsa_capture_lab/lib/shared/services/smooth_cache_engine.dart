import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/data_repository.dart';
import '../../features/dashboard/providers/dashboard_state.dart';

/// SmoothCacheEngine - V3 "Smooth-Stream" Architecture
/// 
/// Design: Non-blocking, yield-based loading that respects UI frame budget.
/// 
/// Features:
/// - **Yield-based scheduler**: 1 image → yield → next (60fps friendly)
/// - **ImageProvider cache**: Reuse hydrated streams, no re-decoding
/// - **Predictive pre-load**: Subfolders loaded on idle
/// - **LRU eviction**: Bounded memory growth
class SmoothCacheEngine {
  final Ref _ref;
  final BuildContext _context;
  
  // Job versioning for cancellation
  int _currentJobVersion = 0;
  
  // Yield-based loading queue
  final Queue<String> _loadQueue = Queue();
  bool _isProcessing = false;
  
  // CRITICAL: ImageProvider memory cache
  // Stores hydrated FileImage instances for instant reuse
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
    
    // Clear queue and reload for new folder
    _loadQueue.clear();
    _queueFolderImages(newFolderId);
    _startProcessing();
    
    // Schedule background pre-load for subfolders after current folder is done
    _scheduleSubfolderPreload(newFolderId);
  }
  
  void _queueFolderImages(int? folderId) {
    final repo = _ref.read(dataRepositoryProvider);
    final notes = repo.getNotesForFolder(folderId);
    
    for (final note in notes) {
      for (final imagePath in note.images) {
        if (!_providerCache.containsKey(imagePath)) {
          _loadQueue.add(imagePath);
        }
      }
      if (note.imagePath != null && note.imagePath!.isNotEmpty) {
        if (!_providerCache.containsKey(note.imagePath!)) {
          _loadQueue.add(note.imagePath!);
        }
      }
    }
  }
  
  void _scheduleSubfolderPreload(int? currentFolderId) {
    final version = _currentJobVersion;
    
    // Wait for current folder to finish loading
    Future.delayed(const Duration(milliseconds: 500), () {
      if (version != _currentJobVersion) return;
      if (!_context.mounted) return;
      
      final repo = _ref.read(dataRepositoryProvider);
      
      // Parent folder
      if (currentFolderId != null) {
        final folder = repo.findFolder(currentFolderId);
        if (folder != null) {
          final parentNotes = repo.getNotesForFolder(folder.parentId);
          for (final note in parentNotes.take(5)) {
            _addToQueueIfNeeded(note);
          }
        }
      }
      
      // Subfolders (first 5 items each)
      final subfolderIds = repo.getSubfolderIds(currentFolderId);
      for (final subfolderId in subfolderIds) {
        final subNotes = repo.getNotesForFolder(subfolderId);
        for (final note in subNotes.take(5)) {
          _addToQueueIfNeeded(note);
        }
      }
      
      _startProcessing();
    });
  }
  
  void _addToQueueIfNeeded(Note note) {
    for (final imagePath in note.images) {
      if (!_providerCache.containsKey(imagePath) && !_loadQueue.contains(imagePath)) {
        _loadQueue.add(imagePath);
      }
    }
    if (note.imagePath != null && note.imagePath!.isNotEmpty) {
      if (!_providerCache.containsKey(note.imagePath!) && !_loadQueue.contains(note.imagePath!)) {
        _loadQueue.add(note.imagePath!);
      }
    }
  }
  
  /// YIELD-BASED CHAIN LOADER
  /// Processes 1 item at a time, yielding to UI between each
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
    
    // Skip if already cached
    if (_providerCache.containsKey(path)) {
      // Yield to UI, then continue
      await Future.delayed(Duration.zero);
      _processNextItem();
      return;
    }
    
    // Load single image
    await _loadImage(path);
    
    // CRITICAL: Yield to UI thread (frame budget respect)
    await Future.delayed(Duration.zero);
    
    // Continue chain
    _processNextItem();
  }
  
  Future<void> _loadImage(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;
      
      // Create and cache the ImageProvider
      final provider = ResizeImage(
        FileImage(file),
        width: 400,
      );
      
      if (!_context.mounted) return;
      
      // Precache to decode the image
      await precacheImage(provider, _context);
      
      // Store in memory cache
      _providerCache[path] = provider;
      _trackAccess(path);
      
      // Notify listeners
      cacheUpdateNotifier.value++;
    } catch (e) {
      // Silently ignore failures
    }
  }
  
  void _trackAccess(String path) {
    _accessOrder.remove(path);
    _accessOrder[path] = DateTime.now();
    
    // LRU eviction
    while (_accessOrder.length > _maxCacheSize) {
      final oldest = _accessOrder.keys.first;
      _accessOrder.remove(oldest);
      _providerCache.remove(oldest);
    }
  }
  
  void dispose() {
    cacheUpdateNotifier.dispose();
  }
}

/// Provider for SmoothCacheEngine
final smoothCacheEngineProvider = Provider.family<SmoothCacheEngine, BuildContext>((ref, context) {
  final engine = SmoothCacheEngine(ref, context);
  
  ref.onDispose(() {
    engine.dispose();
  });
  
  return engine;
});
