import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/dashboard/providers/dashboard_state.dart';
import '../../data/data_repository.dart';
import 'asset_pipeline_service.dart';

/// AssetPrefetcher - Predictive Loading Engine with Horizon Decoding
/// 
/// Philosophy: Load images BEFORE navigation completes.
/// 
/// === ZERO-LATENCY ARCHITECTURE ===
/// 1. Watches currentFolderProvider for navigation changes
/// 2. On change: Immediately prefetch ALL images in target folder (Tier 1 + Tier 2)
/// 3. Horizon Prefetching: Pre-decode first 12 items from next-likely folders
/// 4. Bulk Prefetch: Load remaining items into Tier 2 only (bytes, no decode)
/// 
/// Result: Grid appears with images already decoded = 0 frames of placeholder
class AssetPrefetcher {
  final Ref _ref;
  int? _lastPrefetchedFolder;
  bool _isInitialized = false;
  
  AssetPrefetcher(this._ref);
  
  /// Initialize and start watching folder changes
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    
    // Watch folder changes
    _ref.listen<int?>(currentFolderProvider, (previous, next) {
      _onFolderChanged(next);
    });
    
    // Prefetch root folder immediately
    _prefetchFolder(null);
    
    debugPrint('[AssetPrefetcher] Initialized - Horizon Decoding active');
  }
  
  /// Get paths of currently visible assets
  /// Used by MemoryGovernor for viewport revalidation on resume
  List<String> getVisibleAssetPaths() {
    final repo = _ref.read(dataRepositoryProvider);
    return repo.getImagePathsForFolder(_lastPrefetchedFolder);
  }
  
  /// Called when user navigates to a new folder
  void _onFolderChanged(int? folderId) {
    // Skip if already prefetched this folder
    if (folderId == _lastPrefetchedFolder) return;
    
    _lastPrefetchedFolder = folderId;
    
    // Prefetch current folder (HIGH PRIORITY) - Full Tier 1 decode
    _prefetchFolder(folderId);
    
    // Prefetch parent folder (for back navigation) - Full Tier 1 decode
    _prefetchParent(folderId);
    
    // Horizon Prefetching: Pre-decode visible subfolders
    _prefetchSubfoldersWithHorizon(folderId);
  }
  
  /// Prefetch all images in a folder with full Tier 1 decode
  void _prefetchFolder(int? folderId) {
    final repo = _ref.read(dataRepositoryProvider);
    final pipeline = _ref.read(assetPipelineServiceProvider);
    
    final paths = repo.getImagePathsForFolder(folderId);
    
    if (paths.isEmpty) return;
    
    debugPrint('[AssetPrefetcher] Prefetching ${paths.length} images for folder $folderId');
    pipeline.prefetch(paths); // Full Tier 1 + Tier 2 prefetch
  }
  
  /// Prefetch parent folder (for back navigation)
  void _prefetchParent(int? folderId) {
    if (folderId == null) return;
    
    final repo = _ref.read(dataRepositoryProvider);
    final folder = repo.findFolder(folderId);
    
    if (folder != null) {
      _prefetchFolder(folder.parentId);
    }
  }
  
  /// Horizon Prefetching with differential decoding strategy
  /// 
  /// For each visible subfolder:
  /// - First 12 items: Full horizon decode (Tier 1 + Tier 2)
  /// - Remaining items: Tier 2 only (bytes prefetch, no CPU-intensive decode)
  /// 
  /// Goal: If a folder is visible, immediately navigating into it shows instant images
  void _prefetchSubfoldersWithHorizon(int? parentId) {
    final repo = _ref.read(dataRepositoryProvider);
    final pipeline = _ref.read(assetPipelineServiceProvider);
    
    final subfolderIds = repo.getSubfolderIds(parentId);
    
    // === HORIZON PREFETCHING ===
    // Take first 8 subfolders (visible grid items)
    for (int i = 0; i < subfolderIds.length && i < 8; i++) {
      final subfolderId = subfolderIds[i];
      final paths = repo.getImagePathsForFolder(subfolderId);
      
      if (paths.isEmpty) continue;
      
      // === DIFFERENTIAL DECODING STRATEGY ===
      // First 12 items: Full horizon decode (user likely to see these)
      // Remaining: Tier 2 bytes only (save CPU, ready for instant decode on navigation)
      
      const horizonCount = 12;
      
      if (paths.length <= horizonCount) {
        // Small folder: full decode everything
        pipeline.prefetch(paths);
        debugPrint('[AssetPrefetcher] Horizon: ${paths.length} images (full) for subfolder $subfolderId');
      } else {
        // Large folder: horizon decode first 12, bytes-only for rest
        final horizonPaths = paths.sublist(0, horizonCount);
        final bulkPaths = paths.sublist(horizonCount);
        
        pipeline.prefetch(horizonPaths); // Tier 1 + Tier 2
        pipeline.prefetchBytesOnly(bulkPaths); // Tier 2 only
        
        debugPrint('[AssetPrefetcher] Horizon: $horizonCount decoded + ${bulkPaths.length} bytes-only for subfolder $subfolderId');
      }
    }
  }
  
  /// Manual prefetch trigger (for tap-down prediction)
  /// Call this when user's finger touches a folder (before tap completes)
  void prefetchFolderNow(int? folderId) {
    _prefetchFolder(folderId);
    _prefetchSubfoldersWithHorizon(folderId);
  }
  
  /// Prefetch a specific folder for prediction
  /// Used for tap-down hints - starts loading before navigation
  void predictNavigation(int? folderId) {
    if (folderId == _lastPrefetchedFolder) return;
    
    debugPrint('[AssetPrefetcher] Prediction: Pre-loading folder $folderId');
    _prefetchFolder(folderId);
  }
}

/// Provider for AssetPrefetcher
final assetPrefetcherProvider = Provider<AssetPrefetcher>((ref) {
  ref.keepAlive();
  
  final prefetcher = AssetPrefetcher(ref);
  prefetcher.initialize();
  
  return prefetcher;
});
