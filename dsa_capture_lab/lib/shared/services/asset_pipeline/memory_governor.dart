import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/dashboard/providers/dashboard_state.dart';
import '../../data/data_repository.dart';
import '../hydrated_state.dart';
import '../recent_folders_service.dart';
import 'asset_pipeline_service.dart';
import 'asset_prefetcher.dart';

/// MemoryGovernor - Lifecycle-aware memory management with "Fortress Mode"
/// 
/// Responsibilities:
/// - Monitors AppLifecycleState changes
/// - Implements "Fortress Mode" for 8GB+ RAM devices
/// - Preserves ALL caches during multitasking for instant resume
/// - Handles didHaveMemoryPressure for emergency eviction only
/// 
/// === FORTRESS MODE ARCHITECTURE ===
/// - On `paused`: Do NOT clear any caches
/// - On `resumed`: Revalidate viewport to restore OS-evicted textures
/// - On `memoryPressure`: Only then evict caches (OS signal)
/// 
/// Design:
/// - Tier 1 (Flutter ImageCache) = decoded bitmaps = HIGH memory
/// - Tier 2 (Warm Cache Uint8List) = raw bytes = LOWER memory
/// - Result: App survives multitasking with zero UI latency on resume
class MemoryGovernor with WidgetsBindingObserver {
  final Ref _ref;
  bool _isInitialized = false;
  bool _isAppInBackground = false;
  
  MemoryGovernor(this._ref);
  
  /// Initialize the governor
  void initialize() {
    if (_isInitialized) return;
    
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    
    debugPrint('[MemoryGovernor] Initialized - Fortress Mode active');
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
    debugPrint('[MemoryGovernor] ⚠️ Memory pressure detected!');
    
    // === GC-SAFE CACHE CLEARING ===
    // Since we removed dispose() calls from AssetPipelineService,
    // clearing the cache is now safe even if images are displayed.
    // The cache is cleared (future lookups will reload) but
    // currently displayed images survive until GC collects them.
    try {
      final pipeline = _ref.read(assetPipelineServiceProvider);
      
      if (_isAppInBackground) {
        // App in background - full cache clear
        debugPrint('[MemoryGovernor] App in background - clearing all caches');
        pipeline.clearCache();
      } else {
        // App in foreground - partial eviction to preserve UX
        debugPrint('[MemoryGovernor] App in foreground - partial eviction');
        _evictByFolderContext(aggressive: false);
      }
    } catch (e) {
      debugPrint('[MemoryGovernor] Cache eviction failed: $e');
    }
  }
  
  /// Context-aware eviction: evict oldest folder contexts first
  /// This is smarter than random LRU - preserves recently viewed folders
  /// MEMORY SAFETY: All eviction methods are now GC-safe (no dispose calls)
  void _evictByFolderContext({required bool aggressive}) {
    try {
      final recentService = _ref.read(recentFoldersServiceProvider);
      final pipeline = _ref.read(assetPipelineServiceProvider);
      final repo = _ref.read(dataRepositoryProvider);
      
      // Get eviction order (oldest/5th folder first)
      final evictionOrder = recentService.getEvictionOrder();
      
      if (evictionOrder.isEmpty) {
        // No recent folders tracked, fall back to simple eviction
        pipeline.evictItems(aggressive ? 100 : 25);
        return;
      }
      
      // How many folders to evict
      final foldersToEvict = aggressive ? 3 : 1;
      
      for (int i = 0; i < foldersToEvict && i < evictionOrder.length; i++) {
        final folderId = evictionOrder[i];
        final paths = repo.getImagePathsForFolder(folderId);
        
        // Evict Tier 0 (TextureRegistry) for this folder - GC-safe
        for (final path in paths) {
          pipeline.evictTexture(path);
        }
        
        // Evict Tier 2 (bytes) for this folder
        for (final path in paths) {
          pipeline.evictBytes(path);
        }
        
        debugPrint('[MemoryGovernor] Evicted context for folder $folderId (${paths.length} images)');
      }
      
      // Log remaining cache status
      final stats = pipeline.getCacheStats();
      debugPrint('[MemoryGovernor] After eviction: ${stats['textureBytes'] ~/ 1024 ~/ 1024}MB textures, ${stats['totalBytes'] ~/ 1024 ~/ 1024}MB bytes');
    } catch (e) {
      debugPrint('[MemoryGovernor] Context eviction failed: $e');
    }
  }
  
  /// Called when app goes to background
  void _onPaused() {
    _isAppInBackground = true;
    
    // === PHOENIX PROTOCOL: Save state before OS potentially kills us ===
    _savePhoenixState();
    
    debugPrint('[MemoryGovernor] App paused - FORTRESS MODE + Phoenix State saved');
    
    // === FORTRESS MODE ===
    // Do NOT clear imageCache (Tier 1)
    // Do NOT evict Tier 2
    // Caches will ONLY be cleared if OS sends didHaveMemoryPressure
    // This is safe for 8GB+ RAM target devices (Realme Narzo 70 Turbo)
    //
    // DISABLED: _clearHotCache();
    // 
    // Result: When user returns from multitasking, images are INSTANTLY visible
  }
  
  /// Phoenix Protocol: Persist current navigation state for restoration
  void _savePhoenixState() {
    try {
      final currentFolderId = _ref.read(currentFolderProvider);
      final scrollOffset = _ref.read(scrollPositionProvider);
      
      final state = HydratedState(
        currentFolderId: currentFolderId,
        scrollOffset: scrollOffset,
      );
      
      // Fire-and-forget async save
      state.save();
    } catch (e) {
      debugPrint('[MemoryGovernor] Phoenix save failed: $e');
    }
  }
  
  /// Called when app resumes from background
  void _onResumed() {
    _isAppInBackground = false;
    debugPrint('[MemoryGovernor] App resumed - Running viewport revalidation');
    
    // === VIEWPORT REVALIDATION ===
    // Check if OS killed any of our decoded textures while we were away
    // If so, re-decode them immediately before user interacts
    _revalidateViewport();
  }
  
  /// Revalidates the currently visible assets
  /// Checks if visible paths are still in Tier 1, re-decodes if OS evicted them
  void _revalidateViewport() {
    try {
      final pipeline = _ref.read(assetPipelineServiceProvider);
      final prefetcher = _ref.read(assetPrefetcherProvider);
      
      // Get paths of currently visible assets
      final visiblePaths = prefetcher.getVisibleAssetPaths();
      
      if (visiblePaths.isNotEmpty) {
        debugPrint('[MemoryGovernor] Revalidating ${visiblePaths.length} visible assets');
        pipeline.revalidateViewport(visiblePaths);
      } else {
        debugPrint('[MemoryGovernor] No visible assets to revalidate');
      }
    } catch (e) {
      debugPrint('[MemoryGovernor] Viewport revalidation failed: $e');
    }
  }
  
  /// Clear Flutter's native image cache (Tier 1)
  /// Only called during memory pressure when app is backgrounded
  void _clearHotCache() {
    final imageCache = PaintingBinding.instance.imageCache;
    final count = imageCache.currentSize;
    final sizeBytes = imageCache.currentSizeBytes;
    
    imageCache.clear();
    imageCache.clearLiveImages();
    
    debugPrint('[MemoryGovernor] Cleared $count images (~${(sizeBytes / 1024 / 1024).toStringAsFixed(1)}MB)');
  }
  
  /// Force clear all caches (manual trigger, e.g., for debugging)
  void forceEvictAll() {
    debugPrint('[MemoryGovernor] Force evicting all caches');
    _clearHotCache();
    
    try {
      final pipeline = _ref.read(assetPipelineServiceProvider);
      pipeline.clearCache();
    } catch (e) {
      debugPrint('[MemoryGovernor] Pipeline not available: $e');
    }
  }
  
  /// Get current cache statistics
  Map<String, dynamic> getCacheStats() {
    final imageCache = PaintingBinding.instance.imageCache;
    
    int warmCacheSize = 0;
    int warmCacheBytes = 0;
    bool isHighPerfMode = false;
    
    try {
      final pipeline = _ref.read(assetPipelineServiceProvider);
      final warmStats = pipeline.getCacheStats();
      warmCacheSize = warmStats['itemCount'] as int;
      warmCacheBytes = warmStats['totalBytes'] as int;
      isHighPerfMode = warmStats['isHighPerfMode'] as bool;
    } catch (e) {
      // Pipeline not available
    }
    
    return {
      'hotCacheCount': imageCache.currentSize,
      'hotCacheBytes': imageCache.currentSizeBytes,
      'warmCacheCount': warmCacheSize,
      'warmCacheBytes': warmCacheBytes,
      'isHighPerfMode': isHighPerfMode,
      'isAppInBackground': _isAppInBackground,
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
