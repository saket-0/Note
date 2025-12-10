import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'asset_worker.dart';

/// AssetPipelineService - Central coordinator for the 3-tier cache system
/// 
/// Tier 1 (Hot Cache): Flutter's native ImageCache - managed by MemoryGovernor
/// Tier 2 (Warm Cache): This service's _warmCache (Uint8List raw bytes)
/// Tier 3 (Cold Cache): Disk - accessed via AssetWorker isolate
/// 
/// Design Philosophy:
/// - Store RAW BYTES (Uint8List), not decoded bitmaps
/// - Raw bytes use ~3-4x less memory than decoded RGBA bitmaps
/// - On cache hit: Image.memory() decodes instantly (microseconds)
/// - LRU eviction with hard limits to prevent OOM
class AssetPipelineService {
  final Ref _ref;
  final AssetWorker _worker = AssetWorker();
  
  // === WARM CACHE (Tier 2) ===
  // Stores raw bytes, NOT decoded images
  // LinkedHashMap maintains access order for LRU eviction
  final LinkedHashMap<String, Uint8List> _warmCache = LinkedHashMap();
  
  // LRU configuration
  static const int _maxItems = 500;
  static const int _maxBytes = 50 * 1024 * 1024; // 50MB
  int _currentBytes = 0;
  
  // Pending requests (avoid duplicate loads)
  final Set<String> _pendingRequests = {};
  
  // Reactive notification for cache updates
  final ValueNotifier<int> cacheUpdateNotifier = ValueNotifier(0);
  
  // Worker response subscription
  StreamSubscription<AssetWorkerResponse>? _workerSubscription;
  
  bool _isInitialized = false;
  
  // Initialization lock to prevent race conditions
  Completer<void>? _initCompleter;
  
  // Queue of paths to load once initialized
  final List<String> _pendingLoadQueue = [];
  
  AssetPipelineService(this._ref);
  
  /// Initialize the service
  /// Uses a Completer lock to prevent double initialization
  Future<void> initialize() async {
    // Already initialized
    if (_isInitialized) return;
    
    // Initialization in progress - wait for it
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    
    // Start initialization with lock
    _initCompleter = Completer<void>();
    
    try {
      await _worker.initialize();
      
      // Listen to worker responses
      _workerSubscription = _worker.responses.listen(_handleWorkerResponse);
      
      _isInitialized = true;
      debugPrint('[AssetPipeline] Initialized');
      
      // Process any queued commands
      for (final path in _pendingLoadQueue) {
        _worker.loadImage(path, priority: false);
      }
      _pendingLoadQueue.clear();
      
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('[AssetPipeline] Initialization failed: $e');
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }
  
  /// Check if bytes are cached (synchronous)
  bool isCached(String path) => _warmCache.containsKey(path);
  
  /// Get cached bytes (synchronous, returns null if not cached)
  Uint8List? getCached(String path) {
    if (!_warmCache.containsKey(path)) return null;
    
    // Move to end (most recently used)
    final bytes = _warmCache.remove(path)!;
    _warmCache[path] = bytes;
    
    debugPrint('[AssetPipeline] Cache Hit: $path');
    return bytes;
  }
  
  /// Fetch image bytes (async)
  /// Returns cached bytes immediately if available, otherwise requests from worker
  Future<Uint8List?> fetchImage(String path, {bool priority = false}) async {
    // Check warm cache first
    final cached = getCached(path);
    if (cached != null) return cached;
    
    // Already pending?
    if (_pendingRequests.contains(path)) {
      // Wait for existing request
      return _waitForPath(path);
    }
    
    // Request from worker
    _pendingRequests.add(path);
    _worker.loadImage(path, priority: priority);
    
    // Wait for response
    return _waitForPath(path);
  }
  
  /// Wait for a specific path to be loaded
  Future<Uint8List?> _waitForPath(String path) async {
    // Poll with timeout
    const maxWait = Duration(seconds: 5);
    const pollInterval = Duration(milliseconds: 50);
    
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < maxWait) {
      if (_warmCache.containsKey(path)) {
        return getCached(path);
      }
      
      if (!_pendingRequests.contains(path)) {
        // Request completed but failed
        return null;
      }
      
      await Future.delayed(pollInterval);
    }
    
    debugPrint('[AssetPipeline] Timeout waiting for: $path');
    _pendingRequests.remove(path);
    return null;
  }
  
  /// Handle responses from the worker isolate
  void _handleWorkerResponse(AssetWorkerResponse response) {
    switch (response) {
      case ImageLoadedResponse():
        _onImageLoaded(response.path, response.bytes);
        break;
      case AssetErrorResponse():
        _onImageError(response.path, response.error);
        break;
      case ThumbnailGeneratedResponse():
        // Future: Handle thumbnail generation
        break;
    }
  }
  
  /// Called when image bytes are loaded from disk
  void _onImageLoaded(String path, Uint8List bytes) {
    _pendingRequests.remove(path);
    
    // Add to warm cache
    _addToCache(path, bytes);
    
    // Notify listeners
    cacheUpdateNotifier.value++;
    
    debugPrint('[AssetPipeline] Loaded: $path (${bytes.length} bytes)');
  }
  
  /// Called when image load fails
  void _onImageError(String path, String error) {
    _pendingRequests.remove(path);
    debugPrint('[AssetPipeline] Error: $path - $error');
  }
  
  /// Add bytes to warm cache with LRU eviction
  void _addToCache(String path, Uint8List bytes) {
    // Already cached?
    if (_warmCache.containsKey(path)) {
      // Move to end (most recently used)
      final existing = _warmCache.remove(path)!;
      _warmCache[path] = existing;
      return;
    }
    
    final bytesSize = bytes.length;
    
    // Evict if necessary
    while ((_warmCache.length >= _maxItems || _currentBytes + bytesSize > _maxBytes) 
           && _warmCache.isNotEmpty) {
      _evictOldest();
    }
    
    // Add to cache
    _warmCache[path] = bytes;
    _currentBytes += bytesSize;
  }
  
  /// Evict the oldest (least recently used) item
  void _evictOldest() {
    if (_warmCache.isEmpty) return;
    
    final oldestPath = _warmCache.keys.first;
    final oldestBytes = _warmCache.remove(oldestPath)!;
    _currentBytes -= oldestBytes.length;
    
    debugPrint('[AssetPipeline] Evicted: $oldestPath');
  }
  
  /// Evict N items (called by MemoryGovernor on memory pressure)
  void evictItems(int count) {
    for (int i = 0; i < count && _warmCache.isNotEmpty; i++) {
      _evictOldest();
    }
    cacheUpdateNotifier.value++;
  }
  
  /// Inject bytes directly into cache (for write-through caching)
  /// Call this when saving images to avoid subsequent disk reads
  void injectBytes(String path, Uint8List bytes) {
    _addToCache(path, bytes);
    cacheUpdateNotifier.value++;
    debugPrint('[AssetPipeline] Injected: $path (${bytes.length} bytes)');
  }
  
  /// Prioritize loading a specific path (for on-screen items)
  void prioritize(String path) {
    if (_warmCache.containsKey(path)) return;
    if (_pendingRequests.contains(path)) return;
    
    _pendingRequests.add(path);
    
    // Queue if not yet initialized
    if (!_isInitialized) {
      _pendingLoadQueue.add(path);
      return;
    }
    
    _worker.loadImage(path, priority: true);
  }
  
  /// Prefetch a list of paths in background
  void prefetch(List<String> paths) {
    for (final path in paths) {
      if (!_warmCache.containsKey(path) && !_pendingRequests.contains(path)) {
        _pendingRequests.add(path);
        
        // Queue if not yet initialized
        if (!_isInitialized) {
          _pendingLoadQueue.add(path);
        } else {
          _worker.loadImage(path, priority: false);
        }
      }
    }
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'itemCount': _warmCache.length,
      'totalBytes': _currentBytes,
      'maxItems': _maxItems,
      'maxBytes': _maxBytes,
      'pendingCount': _pendingRequests.length,
    };
  }
  
  /// Clear entire warm cache
  void clearCache() {
    _warmCache.clear();
    _currentBytes = 0;
    cacheUpdateNotifier.value++;
    debugPrint('[AssetPipeline] Cache cleared');
  }
  
  /// Dispose the service
  void dispose() {
    _workerSubscription?.cancel();
    _worker.dispose();
    _warmCache.clear();
    cacheUpdateNotifier.dispose();
    _isInitialized = false;
    debugPrint('[AssetPipeline] Disposed');
  }
}

/// Provider for AssetPipelineService
final assetPipelineServiceProvider = Provider<AssetPipelineService>((ref) {
  ref.keepAlive();
  
  final service = AssetPipelineService(ref);
  
  // Initialize asynchronously
  service.initialize();
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});
