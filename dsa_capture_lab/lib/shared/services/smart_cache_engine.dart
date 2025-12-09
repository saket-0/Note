import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/data_repository.dart';
import '../../features/dashboard/providers/dashboard_state.dart';

/// SmartCacheEngine v2 - "Open World" Asset Streaming Engine
/// 
/// Features:
/// - **Immediate fetch**: No debounce for current folder (0ms delay)
/// - **High concurrency**: 15 parallel fetches for fast local I/O
/// - **Reactive API**: ValueNotifier for cache updates
/// - **LRU eviction**: Keeps last 500 images
/// - **Priority queue**: On-screen images get fetched first
class SmartCacheEngine {
  final Ref _ref;
  final BuildContext _context;
  
  // Job versioning for cancellation
  int _currentJobVersion = 0;
  
  // Debouncing only for background (speculative) fetches
  Timer? _debounceTimer;
  static const _backgroundDebounceDelay = Duration(milliseconds: 300);
  
  // Throttling delay between subfolder processing
  static const _throttleDelay = Duration(milliseconds: 30);
  
  // LRU cache configuration
  static const int _maxCacheSize = 500;
  
  // LRU tracking: LinkedHashMap maintains insertion order
  final LinkedHashMap<String, DateTime> _accessOrder = LinkedHashMap();
  
  // Track preloaded paths
  final Set<String> _preloadedPaths = {};
  
  // Track priority paths (parent folder, shouldn't be evicted)
  final Set<String> _priorityPaths = {};
  
  // HIGH CONCURRENCY: 15 parallel fetches for fast local I/O
  static const int _maxConcurrent = 15;
  int _activeFetches = 0;
  final Queue<_PendingFetch> _pendingQueue = Queue();
  
  // Priority queue for on-screen images
  final Queue<_PendingFetch> _priorityQueue = Queue();
  
  // Reactive notification for cache updates
  final ValueNotifier<Set<String>> cachedPathsNotifier = ValueNotifier({});
  
  SmartCacheEngine(this._ref, this._context) {
    // Start observing folder changes
    _ref.listen<int?>(currentFolderProvider, (previous, next) {
      _onFolderChanged(next);
    });
    
    // IMMEDIATE: Start caching root folder now (no debounce)
    _cacheCurrentFolderImmediately(null);
  }
  
  // === PUBLIC API ===
  
  /// Check if an image path is already cached (synchronous lookup)
  bool isCached(String path) => _preloadedPaths.contains(path);
  
  /// Get count of cached images
  int get cacheSize => _preloadedPaths.length;
  
  /// Prioritize loading a specific path (called by LazyImage when on-screen)
  void prioritize(String path) {
    if (_preloadedPaths.contains(path)) return;
    
    // Add to priority queue (front of line)
    final completer = Completer<void>();
    _priorityQueue.add(_PendingFetch(path, completer, isPriority: true));
    _processQueue();
  }
  
  // === INTERNAL ===
  
  void _onFolderChanged(int? newFolderId) {
    // Cancel in-progress background work
    _currentJobVersion++;
    _debounceTimer?.cancel();
    
    // IMMEDIATE: Cache current folder with 0ms delay
    _cacheCurrentFolderImmediately(newFolderId);
    
    // DEBOUNCED: Background fetch for parent/subfolders
    _debounceTimer = Timer(_backgroundDebounceDelay, () {
      final version = _currentJobVersion;
      _cacheBackgroundFolders(newFolderId, version);
    });
  }
  
  /// Cache current folder IMMEDIATELY (no debounce)
  Future<void> _cacheCurrentFolderImmediately(int? folderId) async {
    if (!_context.mounted) return;
    
    final repo = _ref.read(dataRepositoryProvider);
    final notes = repo.getNotesForFolder(folderId);
    
    // Fire off all fetches in parallel (up to concurrency limit)
    for (final note in notes) {
      for (final imagePath in note.images) {
        _cacheImage(imagePath);
      }
      if (note.imagePath != null && note.imagePath!.isNotEmpty) {
        _cacheImage(note.imagePath!);
      }
    }
  }
  
  /// Cache parent and subfolders in background (debounced)
  Future<void> _cacheBackgroundFolders(int? currentFolderId, int version) async {
    if (!_context.mounted) return;
    if (version != _currentJobVersion) return;
    
    final repo = _ref.read(dataRepositoryProvider);
    
    // Parent folder
    final parentId = _getParentId(currentFolderId, repo);
    if (currentFolderId != null) {
      final parentNotes = repo.getNotesForFolder(parentId);
      _priorityPaths.clear();
      for (final note in parentNotes) {
        if (note.imagePath != null) _priorityPaths.add(note.imagePath!);
        _priorityPaths.addAll(note.images);
      }
      await _cacheNotes(parentNotes, version);
      if (version != _currentJobVersion) return;
    }
    
    // Subfolders
    final subfolderIds = repo.getSubfolderIds(currentFolderId);
    for (final subfolderId in subfolderIds) {
      if (version != _currentJobVersion) return;
      if (!_context.mounted) return;
      
      final subNotes = repo.getNotesForFolder(subfolderId);
      await _cacheNotes(subNotes, version);
      await Future.delayed(_throttleDelay);
    }
  }
  
  int? _getParentId(int? folderId, DataRepository repo) {
    if (folderId == null) return null;
    final folder = repo.findFolder(folderId);
    return folder?.parentId;
  }
  
  Future<void> _cacheNotes(List<Note> notes, int version) async {
    for (final note in notes) {
      if (version != _currentJobVersion) return;
      if (!_context.mounted) return;
      
      for (final imagePath in note.images) {
        _cacheImage(imagePath);
      }
      if (note.imagePath != null && note.imagePath!.isNotEmpty) {
        _cacheImage(note.imagePath!);
      }
    }
  }
  
  /// Cache a single image (non-blocking, respects concurrency)
  void _cacheImage(String path) {
    if (_preloadedPaths.contains(path)) {
      _trackAccess(path);
      return;
    }
    
    // Add to regular queue
    final completer = Completer<void>();
    _pendingQueue.add(_PendingFetch(path, completer, isPriority: false));
    _processQueue();
  }
  
  /// Process queues (priority first, then regular)
  void _processQueue() {
    while (_activeFetches < _maxConcurrent) {
      _PendingFetch? pending;
      
      // Priority queue first
      if (_priorityQueue.isNotEmpty) {
        pending = _priorityQueue.removeFirst();
      } else if (_pendingQueue.isNotEmpty) {
        pending = _pendingQueue.removeFirst();
      } else {
        break;
      }
      
      // Skip if already cached
      if (_preloadedPaths.contains(pending.path)) {
        pending.completer.complete();
        continue;
      }
      
      _executeFetch(pending);
    }
  }
  
  Future<void> _executeFetch(_PendingFetch pending) async {
    _activeFetches++;
    
    try {
      final file = File(pending.path);
      if (await file.exists()) {
        final imageProvider = ResizeImage(
          FileImage(file),
          width: 400,
        );
        
        if (_context.mounted) {
          await precacheImage(imageProvider, _context);
          _preloadedPaths.add(pending.path);
          _trackAccess(pending.path);
          
          // Notify listeners of cache update
          cachedPathsNotifier.value = Set.from(_preloadedPaths);
        }
      }
      pending.completer.complete();
    } catch (e) {
      pending.completer.complete();
    } finally {
      _activeFetches--;
      _processQueue();
    }
  }
  
  void _trackAccess(String path) {
    _accessOrder.remove(path);
    _accessOrder[path] = DateTime.now();
    
    while (_accessOrder.length > _maxCacheSize) {
      final oldest = _accessOrder.keys.first;
      
      if (_priorityPaths.contains(oldest)) {
        _accessOrder.remove(oldest);
        _accessOrder[oldest] = DateTime.now();
        continue;
      }
      
      _accessOrder.remove(oldest);
      _preloadedPaths.remove(oldest);
    }
  }
  
  void dispose() {
    _debounceTimer?.cancel();
    cachedPathsNotifier.dispose();
  }
}

/// Provider for SmartCacheEngine
final smartCacheEngineProvider = Provider.family<SmartCacheEngine, BuildContext>((ref, context) {
  final engine = SmartCacheEngine(ref, context);
  
  ref.onDispose(() {
    engine.dispose();
  });
  
  return engine;
});

/// Helper class for pending fetch queue
class _PendingFetch {
  final String path;
  final Completer<void> completer;
  final bool isPriority;
  
  _PendingFetch(this.path, this.completer, {this.isPriority = false});
}
