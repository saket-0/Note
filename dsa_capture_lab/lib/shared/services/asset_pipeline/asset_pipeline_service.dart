import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'asset_worker.dart';

/// AssetPipelineService - Central coordinator for the 4-tier cache system
/// 
/// Tier 0 (Texture Registry): Pre-decoded ui.Image objects (GPU-ready, 1GB limit)
/// Tier 1 (Hot Cache): Flutter's native ImageCache - managed by MemoryGovernor
/// Tier 2 (Warm Cache): This service's _warmCache (Uint8List raw bytes)
/// Tier 3 (Cold Cache): Disk - accessed via AssetWorker isolate
/// 
/// Design Philosophy:
/// - Tier 0: GPU-ready textures for ZERO-STUTTER 120Hz scrolling
/// - Tier 2: Raw bytes (3-4x more efficient than decoded bitmaps)
/// - On Tier 2 hit: Image.memory() decodes instantly (microseconds)
/// - Memory-based LRU eviction to prevent OOM
/// 
/// === RAM-FIRST, DISK-LATER ARCHITECTURE ===
/// - ingestImmediate(): Inject bytes → Decode → Async disk write
/// - Zero-latency image previews for 8GB+ RAM devices
/// - Fortress Mode: Preserve all caches during multitasking
class AssetPipelineService {
  // ignore: unused_field
  final Ref _ref;
  final AssetWorker _worker = AssetWorker();
  
  // === TEXTURE REGISTRY (Tier 0) ===
  // Pre-decoded ui.Image objects for ZERO-STUTTER 120Hz scrolling
  // These are GPU-ready textures - no decoding needed on render
  // 
  // MEMORY SAFETY: We do NOT call dispose() on evicted images.
  // Reason: If a SmartImage widget is still displaying the image,
  // disposing it causes "underlying data released" crash.
  // Instead, we let Dart GC clean up images when no longer referenced.
  final LinkedHashMap<String, ui.Image> _textureRegistry = LinkedHashMap();
  int _textureBytes = 0;
  // 350MB limit for decoded textures (safe for 2GB free heap on 8GB device)
  static const int _maxTextureBytes = 350 * 1024 * 1024;
  
  // === WARM CACHE (Tier 2) ===
  // Stores raw bytes, NOT decoded images
  // LinkedHashMap maintains access order for LRU eviction
  final LinkedHashMap<String, Uint8List> _warmCache = LinkedHashMap();
  
  // === PENDING DISK WRITES (for confirmation tracking) ===
  // Tracks ingestImmediate calls waiting for disk write confirmation
  final Map<String, Completer<bool>> _pendingDiskWrites = {};
  
  // === ADAPTIVE LRU CONFIGURATION ===
  // High-end device limits (8GB+ RAM target)
  late final int _maxItems;
  late final int _maxBytes;
  
  // High-performance limits for 8GB+ devices (tuned for 2GB free heap)
  static const int _highEndMaxItems = 1000;
  static const int _highEndMaxBytes = 200 * 1024 * 1024; // 200MB
  
  // Conservative limits for low-end devices (fallback)
  static const int _lowEndMaxItems = 500;
  static const int _lowEndMaxBytes = 50 * 1024 * 1024; // 50MB
  
  // RAM threshold for high-perf mode (6GB to be safe)
  static const int _highPerfRamThresholdMB = 6000;
  
  int _currentBytes = 0;
  
  // Pending requests (avoid duplicate loads)
  final Set<String> _pendingRequests = {};
  
  // Track paths that were requested via prefetch() for texture warming
  final Set<String> _prefetchedPaths = {};
  
  // Reactive notification for cache updates
  final ValueNotifier<int> cacheUpdateNotifier = ValueNotifier(0);
  
  // Worker response subscription
  StreamSubscription<AssetWorkerResponse>? _workerSubscription;
  
  bool _isInitialized = false;
  
  // Initialization lock to prevent race conditions
  Completer<void>? _initCompleter;
  
  // Queue of paths to load once initialized
  final List<String> _pendingLoadQueue = [];
  
  AssetPipelineService(this._ref) {
    _configureAdaptiveLimits();
  }
  
  /// Configure cache limits based on device RAM
  void _configureAdaptiveLimits() {
    try {
      // Get device physical memory
      final ramBytes = Platform.isAndroid || Platform.isIOS 
          ? _getDeviceRamMB() 
          : 8000; // Default to high-perf on desktop
      
      if (ramBytes >= _highPerfRamThresholdMB) {
        _maxItems = _highEndMaxItems;
        _maxBytes = _highEndMaxBytes;
        debugPrint('[AssetPipeline] HIGH-PERF MODE: ${_maxBytes ~/ 1024 ~/ 1024}MB / $_maxItems items');
      } else {
        _maxItems = _lowEndMaxItems;
        _maxBytes = _lowEndMaxBytes;
        debugPrint('[AssetPipeline] CONSERVATIVE MODE: ${_maxBytes ~/ 1024 ~/ 1024}MB / $_maxItems items');
      }
    } catch (e) {
      // Default to high-perf on error (target device is 8GB)
      _maxItems = _highEndMaxItems;
      _maxBytes = _highEndMaxBytes;
      debugPrint('[AssetPipeline] RAM detection failed, defaulting to HIGH-PERF: $e');
    }
  }
  
  /// Get device RAM in megabytes
  /// Returns approximate value based on ProcessInfo
  int _getDeviceRamMB() {
    try {
      // Use ProcessInfo for cross-platform RAM detection
      // On mobile, this gives us the maximum RSS which correlates with device RAM
      // Note: ProcessInfo.currentRss gives current usage, not total RAM
      // Estimate total RAM as ~8x current RSS (heuristic for mobile apps)
      // More reliable: use device_info_plus package for exact values
      // For now, default to high-perf since target is 8GB Realme Narzo 70 Turbo
      return 8000; // Assume high-end device for now
    } catch (e) {
      return 8000; // Default to high-end
    }
  }
  
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
      debugPrint('[AssetPipeline] Initialized - RAM-First Architecture Active');
      
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
  
  // ============================================================
  // === TEXTURE REGISTRY (TIER 0) - GPU-READY TEXTURES ===
  // ============================================================
  
  /// Check if decoded texture exists (synchronous, for UI thread lookup)
  /// Returns null if not cached - caller should fallback to bytes cache
  ui.Image? getTexture(String path) {
    if (!_textureRegistry.containsKey(path)) return null;
    
    // Move to end (most recently used) - LRU touch
    final img = _textureRegistry.remove(path)!;
    _textureRegistry[path] = img;
    
    return img;
  }
  
  /// Check if texture is cached (synchronous)
  bool hasTexture(String path) => _textureRegistry.containsKey(path);
  
  /// Add decoded texture to registry with memory-based LRU eviction
  void _addTexture(String path, ui.Image image) {
    // Estimate texture memory: width * height * 4 bytes (RGBA)
    final imageBytes = image.width * image.height * 4;
    
    // Already cached? Just update LRU
    if (_textureRegistry.containsKey(path)) {
      final existing = _textureRegistry.remove(path)!;
      _textureRegistry[path] = existing;
      return;
    }
    
    // Evict if necessary (memory-based, not count-based)
    while (_textureBytes + imageBytes > _maxTextureBytes && _textureRegistry.isNotEmpty) {
      _evictOldestTexture();
    }
    
    _textureRegistry[path] = image;
    _textureBytes += imageBytes;
    
    debugPrint('[AssetPipeline] Texture cached: $path (${imageBytes ~/ 1024}KB, total: ${_textureBytes ~/ 1024 ~/ 1024}MB)');
  }
  
  /// Evict oldest texture (LRU)
  /// MEMORY SAFETY: Does NOT call dispose() - let GC handle cleanup
  void _evictOldestTexture() {
    if (_textureRegistry.isEmpty) return;
    
    final oldestPath = _textureRegistry.keys.first;
    final oldestImage = _textureRegistry.remove(oldestPath)!;
    final imageBytes = oldestImage.width * oldestImage.height * 4;
    _textureBytes -= imageBytes;
    
    // DO NOT dispose - image may still be displayed by SmartImage widget
    // GC will clean it up when no longer referenced
    
    debugPrint('[AssetPipeline] Texture evicted (GC-safe): $oldestPath');
  }
  
  /// Pre-decode an image into GPU-ready texture (Tier 0).
  /// Call this BEFORE widget builds for zero-stutter scrolling.
  /// 
  /// This is the PUBLIC API for explicit texture preheating.
  /// Use when you know an image will be displayed soon.
  Future<void> prewarm(String path) async {
    // Already in texture registry?
    if (_textureRegistry.containsKey(path)) return;
    
    // Try to get bytes from warm cache first
    final bytes = _warmCache[path];
    if (bytes != null) {
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _addTexture(path, frame.image);
        codec.dispose();
        debugPrint('[AssetPipeline] Prewarmed: $path');
      } catch (e) {
        debugPrint('[AssetPipeline] Prewarm decode failed: $path - $e');
      }
      return;
    }
    
    // Not in bytes cache - load from disk first, then decode
    final diskBytes = await fetchImage(path, priority: true);
    if (diskBytes != null) {
      try {
        final codec = await ui.instantiateImageCodec(diskBytes);
        final frame = await codec.getNextFrame();
        _addTexture(path, frame.image);
        codec.dispose();
        debugPrint('[AssetPipeline] Prewarmed from disk: $path');
      } catch (e) {
        debugPrint('[AssetPipeline] Prewarm decode failed: $path - $e');
      }
    }
  }
  
  /// Prewarm multiple paths in parallel (with concurrency limit)
  Future<void> prewarmBatch(List<String> paths, {int concurrency = 4}) async {
    final queue = [...paths];
    final active = <Future<void>>[];
    
    while (queue.isNotEmpty || active.isNotEmpty) {
      while (queue.isNotEmpty && active.length < concurrency) {
        final path = queue.removeAt(0);
        final future = prewarm(path);
        active.add(future);
        // Schedule removal after completion
        future.then((_) => active.remove(future));
      }
      if (active.isNotEmpty) {
        await Future.any(active);
      }
    }
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
      case FileSavedResponse():
        // Complete pending disk write confirmation
        final completer = _pendingDiskWrites.remove(response.path);
        if (completer != null && !completer.isCompleted) {
          completer.complete(response.success);
        }
        debugPrint('[AssetPipeline] Disk write ${response.success ? "confirmed" : "FAILED"}: ${response.path}');
        break;
    }
  }
  
  /// Called when image bytes are loaded from disk
  void _onImageLoaded(String path, Uint8List bytes) {
    _pendingRequests.remove(path);
    
    // Add to warm cache
    _addToCache(path, bytes);
    
    // === TEXTURE WARMING ===
    // If this was a prefetch request, pre-decode into Flutter's ImageCache
    // This ensures zero-stutter scrolling by having decoded textures ready
    if (_prefetchedPaths.contains(path)) {
      _prefetchedPaths.remove(path);
      _prewarmTexture(bytes, path);
    }
    
    // Notify listeners
    cacheUpdateNotifier.value++;
    
    debugPrint('[AssetPipeline] Loaded: $path (${bytes.length} bytes)');
  }
  
  /// Pre-decode image into Flutter's ImageCache (Tier 1) for zero-stutter scrolling
  /// 
  /// This decodes the image bytes on a background thread and puts the result
  /// into Flutter's native ImageCache. When the UI later displays this image,
  /// it will find it already decoded and ready to render.
  Future<void> _prewarmTexture(Uint8List bytes, String key) async {
    try {
      // Decode the image codec asynchronously (this is CPU-intensive)
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      // Decode at least one frame to fully warm the texture
      await codec.getNextFrame();
      
      // Create a MemoryImage provider for caching
      final memoryImage = MemoryImage(bytes);
      const config = ImageConfiguration.empty;
      
      // Resolve the image - this triggers Flutter's internal caching mechanism
      // The ImageStream will cache the decoded image in Flutter's ImageCache
      final ImageStream stream = memoryImage.resolve(config);
      
      // Add a listener to ensure the image is fully loaded into cache
      final completer = Completer<void>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          // Image is now cached in Flutter's ImageCache
          stream.removeListener(listener);
          if (!completer.isCompleted) completer.complete();
        },
        onError: (exception, stackTrace) {
          stream.removeListener(listener);
          if (!completer.isCompleted) completer.complete();
        },
      );
      stream.addListener(listener);
      
      // Wait for caching to complete (with timeout)
      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          stream.removeListener(listener);
        },
      );
      
      // Clean up the codec
      codec.dispose();
      
      debugPrint('[AssetPipeline] Prewarmed texture: $key');
    } catch (e) {
      debugPrint('[AssetPipeline] Prewarm failed for $key: $e');
    }
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
  
  /// Evict a specific texture from Tier 0 (TextureRegistry)
  /// Called by MemoryGovernor for context-aware eviction
  /// MEMORY SAFETY: Does NOT dispose - let GC handle cleanup
  void evictTexture(String path) {
    final image = _textureRegistry.remove(path);
    if (image != null) {
      final bytes = image.width * image.height * 4;
      _textureBytes -= bytes;
      // DO NOT dispose - image may still be in use by UI
    }
  }
  
  /// Evict specific bytes from Tier 2 (WarmCache)
  /// Called by MemoryGovernor for context-aware eviction
  void evictBytes(String path) {
    final bytes = _warmCache.remove(path);
    if (bytes != null) {
      _currentBytes -= bytes.length;
    }
  }
  
  // ============================================================
  // === RAM-FIRST, DISK-LATER API ===
  // ============================================================
  
  /// Zero-latency write-through ingestion for newly captured images.
  /// 
  /// This method implements the "RAM-First, Disk-Later" pattern:
  /// 1. RAM Injection - Immediately inject rawBytes into Tier 2 _warmCache
  /// 2. Instant Pre-warming - Trigger _prewarmTexture to decode into Tier 1
  /// 3. Async Persistence - Offload disk write to background worker
  /// 
  /// Result: UI reads from RAM (Tier 1) instantly, before file exists on disk.
  /// 
  /// [path] - The intended file path where the image will be saved
  /// [rawBytes] - Raw image bytes (from camera or other source)
  /// 
  /// Returns: Future<bool> that completes when disk write is confirmed
  ///          true = success, false = failure
  Future<bool> ingestImmediate(String path, Uint8List rawBytes) async {
    // 1. RAM Injection - Add to Tier 2 immediately (synchronous)
    _addToCache(path, rawBytes);
    _prefetchedPaths.add(path);
    
    // 2. Instant Pre-warming - Decode into Tier 1 (fire and forget)
    unawaited(_prewarmTexture(rawBytes, path));
    
    // 3. Async Persistence with confirmation tracking
    final completer = Completer<bool>();
    _pendingDiskWrites[path] = completer;
    
    if (_isInitialized) {
      _worker.writeToDisk(path, rawBytes);
    } else {
      // If worker not ready, write synchronously (fallback)
      try {
        await File(path).writeAsBytes(rawBytes);
        completer.complete(true);
      } catch (e) {
        debugPrint('[AssetPipeline] Fallback write failed: $e');
        completer.complete(false);
      }
    }
    
    cacheUpdateNotifier.value++;
    debugPrint('[AssetPipeline] Ingested (RAM-First): $path (${rawBytes.length} bytes)');
    
    // Return the confirmation future
    return completer.future;
  }
  
  /// Revalidates visible assets after app resume.
  /// 
  /// Checks if paths are still in Tier 1 ImageCache, re-decodes if evicted by OS.
  /// Called by MemoryGovernor on AppLifecycleState.resumed.
  Future<void> revalidateViewport(List<String> visiblePaths) async {
    if (visiblePaths.isEmpty) return;
    
    debugPrint('[AssetPipeline] Revalidating ${visiblePaths.length} viewport assets');
    
    for (final path in visiblePaths) {
      final bytes = _warmCache[path];
      if (bytes != null) {
        // Re-decode into Tier 1 if it was evicted by OS
        await _prewarmTexture(bytes, path);
      }
    }
    
    debugPrint('[AssetPipeline] Viewport revalidation complete');
  }
  
  /// Inject bytes directly into cache (for write-through caching)
  /// Call this when saving images to avoid subsequent disk reads
  /// @deprecated Use ingestImmediate() instead for zero-latency ingestion
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
  
  /// Prefetch a list of paths in background WITH texture warming
  /// Images loaded via prefetch() will also be pre-decoded (texture warming)
  void prefetch(List<String> paths) {
    for (final path in paths) {
      if (!_warmCache.containsKey(path) && !_pendingRequests.contains(path)) {
        _pendingRequests.add(path);
        _prefetchedPaths.add(path); // Mark for texture warming on load complete
        
        // Queue if not yet initialized
        if (!_isInitialized) {
          _pendingLoadQueue.add(path);
        } else {
          _worker.loadImage(path, priority: false);
        }
      }
    }
  }
  
  /// Prefetch paths into Tier 2 (bytes) only - NO texture warming
  /// Use for distant/unlikely-to-view items to save CPU cycles
  void prefetchBytesOnly(List<String> paths) {
    for (final path in paths) {
      if (!_warmCache.containsKey(path) && !_pendingRequests.contains(path)) {
        _pendingRequests.add(path);
        // Do NOT add to _prefetchedPaths - skips texture warming
        
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
      // Tier 0 (Texture Registry)
      'textureCount': _textureRegistry.length,
      'textureBytes': _textureBytes,
      'maxTextureBytes': _maxTextureBytes,
      // Tier 2 (Warm Cache)
      'itemCount': _warmCache.length,
      'totalBytes': _currentBytes,
      'maxItems': _maxItems,
      'maxBytes': _maxBytes,
      'pendingCount': _pendingRequests.length,
      'isHighPerfMode': _maxItems == _highEndMaxItems,
    };
  }
  
  /// Clear entire warm cache and texture registry
  /// MEMORY SAFETY: Does NOT dispose textures - let GC handle cleanup
  void clearCache() {
    // Clear texture registry without disposing
    // Images may still be referenced by SmartImage widgets
    _textureRegistry.clear();
    _textureBytes = 0;
    
    // Clear warm cache
    _warmCache.clear();
    _currentBytes = 0;
    
    cacheUpdateNotifier.value++;
    debugPrint('[AssetPipeline] All caches cleared (GC-safe)');
  }
  
  /// Dispose the service
  /// Note: We do NOT dispose textures here either - widgets may still reference them
  void dispose() {
    _workerSubscription?.cancel();
    _worker.dispose();
    
    // Clear registries without disposing images
    // GC will clean up when app is fully terminated
    _textureRegistry.clear();
    _textureBytes = 0;
    
    _warmCache.clear();
    cacheUpdateNotifier.dispose();
    _isInitialized = false;
    debugPrint('[AssetPipeline] Disposed (GC-safe)');
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
