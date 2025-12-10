import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/dashboard/providers/dashboard_state.dart';
import '../../data/data_repository.dart';
import 'asset_pipeline_service.dart';

/// AssetPrefetcher - Predictive Loading Engine
/// 
/// Philosophy: Load images BEFORE navigation completes.
/// 
/// Behavior:
/// 1. Watches currentFolderProvider for navigation changes
/// 2. On change: Immediately prefetch ALL images in target folder
/// 3. Lookahead: Prefetch first 3 images from each of the first 5 subfolders
/// 
/// Result: Grid appears with images already in cache = 0 frames of placeholder
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
    
    debugPrint('[AssetPrefetcher] Initialized');
  }
  
  /// Called when user navigates to a new folder
  void _onFolderChanged(int? folderId) {
    // Skip if already prefetched this folder
    if (folderId == _lastPrefetchedFolder) return;
    
    _lastPrefetchedFolder = folderId;
    
    // Prefetch current folder (HIGH PRIORITY)
    _prefetchFolder(folderId);
    
    // Prefetch parent folder (for back navigation)
    _prefetchParent(folderId);
    
    // Lookahead: Prefetch first 3 images from first 5 subfolders
    _prefetchSubfolders(folderId);
  }
  
  /// Prefetch all images in a folder
  void _prefetchFolder(int? folderId) {
    final repo = _ref.read(dataRepositoryProvider);
    final pipeline = _ref.read(assetPipelineServiceProvider);
    
    final paths = repo.getImagePathsForFolder(folderId);
    
    if (paths.isEmpty) return;
    
    debugPrint('[AssetPrefetcher] Prefetching ${paths.length} images for folder $folderId');
    pipeline.prefetch(paths);
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
  
  /// Lookahead: Prefetch first 3 images from first 5 subfolders
  void _prefetchSubfolders(int? parentId) {
    final repo = _ref.read(dataRepositoryProvider);
    final pipeline = _ref.read(assetPipelineServiceProvider);
    
    final subfolderIds = repo.getSubfolderIds(parentId);
    
    // Take only first 5 subfolders
    for (final subfolderId in subfolderIds.take(5)) {
      final notes = repo.getNotesForFolder(subfolderId);
      
      // Collect first 3 images from this subfolder
      final paths = <String>[];
      for (final note in notes.take(3)) {
        if (note.imagePath != null && note.imagePath!.isNotEmpty) {
          paths.add(note.imagePath!);
        }
        paths.addAll(note.images.take(3 - paths.length));
        if (paths.length >= 3) break;
      }
      
      if (paths.isNotEmpty) {
        debugPrint('[AssetPrefetcher] Lookahead: ${paths.length} images for subfolder $subfolderId');
        pipeline.prefetch(paths);
      }
    }
  }
  
  /// Manual prefetch trigger (for tap-down prediction)
  void prefetchFolderNow(int? folderId) {
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
