import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'asset_pipeline_service.dart';

/// MemoryGovernor - Lifecycle-aware memory management
/// 
/// Responsibilities:
/// - Monitors AppLifecycleState changes
/// - On `paused`: Clears Flutter's ImageCache (Tier 1 Hot Cache)
/// - Preserves AssetPipelineService warm cache (Tier 2) for instant resume
/// - Handles didHaveMemoryPressure for emergency eviction
/// 
/// Design:
/// - Tier 1 (Flutter ImageCache) = decoded bitmaps = HIGH memory
/// - Tier 2 (Warm Cache Uint8List) = raw bytes = LOWER memory
/// - On pause: Clear expensive Tier 1, keep cheap Tier 2
/// - Result: App survives multitasking without being killed by OS
class MemoryGovernor with WidgetsBindingObserver {
  final Ref _ref;
  bool _isInitialized = false;
  
  MemoryGovernor(this._ref);
  
  /// Initialize the governor
  void initialize() {
    if (_isInitialized) return;
    
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    
    debugPrint('[MemoryGovernor] Initialized');
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _onPaused();
        break;
      case AppLifecycleState.resumed:
        _onResumed();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // No action needed
        break;
    }
  }
  
  @override
  void didHaveMemoryPressure() {
    // Emergency eviction on OS memory pressure
    debugPrint('[MemoryGovernor] Memory pressure detected!');
    
    // Clear Tier 1 (Flutter's image cache)
    _clearHotCache();
    
    // Ask pipeline to evict some Tier 2 items
    try {
      final pipeline = _ref.read(assetPipelineServiceProvider);
      pipeline.evictItems(100); // Evict 100 items to free memory
    } catch (e) {
      debugPrint('[MemoryGovernor] Pipeline not available for eviction: $e');
    }
  }
  
  /// Called when app goes to background
  void _onPaused() {
    debugPrint('[MemoryGovernor] App paused - Persistence Mode active');
    
    // === PERSISTENCE MODE ===
    // Keep Hot Cache alive for instant multitasking resume.
    // Cache will ONLY be cleared in didHaveMemoryPressure().
    // This is safe for 8GB+ RAM target devices.
    // _clearHotCache(); // DISABLED for performance-aggressive architecture
    
    // KEEP Tier 2: AssetPipelineService's Uint8List cache
    // This is cheap (raw bytes) and allows instant restore on resume
    
    debugPrint('[MemoryGovernor] Persistence Mode: ALL caches preserved for instant resume');
  }
  
  /// Called when app resumes from background
  void _onResumed() {
    debugPrint('[MemoryGovernor] App resumed - Tier 2 warm cache ready for instant decode');
    
    // Nothing to do here - the SmartImage widgets will:
    // 1. Check Tier 1 (miss - we cleared it)
    // 2. Check Tier 2 (HIT - we preserved it)
    // 3. Decode bytes to image instantly (no disk I/O needed)
  }
  
  /// Clear Flutter's native image cache (Tier 1)
  void _clearHotCache() {
    final imageCache = PaintingBinding.instance.imageCache;
    final count = imageCache.currentSize;
    final sizeBytes = imageCache.currentSizeBytes;
    
    imageCache.clear();
    imageCache.clearLiveImages();
    
    debugPrint('[MemoryGovernor] Cleared $count images (~${(sizeBytes / 1024 / 1024).toStringAsFixed(1)}MB)');
  }
  
  /// Get current cache statistics
  Map<String, dynamic> getCacheStats() {
    final imageCache = PaintingBinding.instance.imageCache;
    
    int warmCacheSize = 0;
    int warmCacheBytes = 0;
    
    try {
      final pipeline = _ref.read(assetPipelineServiceProvider);
      final warmStats = pipeline.getCacheStats();
      warmCacheSize = warmStats['itemCount'] as int;
      warmCacheBytes = warmStats['totalBytes'] as int;
    } catch (e) {
      // Pipeline not available
    }
    
    return {
      'hotCacheCount': imageCache.currentSize,
      'hotCacheBytes': imageCache.currentSizeBytes,
      'warmCacheCount': warmCacheSize,
      'warmCacheBytes': warmCacheBytes,
    };
  }
  
  /// Dispose the governor
  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
      debugPrint('[MemoryGovernor] Disposed');
    }
  }
}

/// Provider for MemoryGovernor
final memoryGovernorProvider = Provider<MemoryGovernor>((ref) {
  ref.keepAlive();
  
  final governor = MemoryGovernor(ref);
  governor.initialize();
  
  ref.onDispose(() {
    governor.dispose();
  });
  
  return governor;
});
