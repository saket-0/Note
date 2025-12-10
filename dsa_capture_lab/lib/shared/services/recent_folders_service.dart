import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// RecentFoldersService - Tracks the last N folder contexts viewed
/// 
/// === HYDRATED CONTEXT CACHING ===
/// 
/// Purpose:
/// - Maintains LRU queue of recently viewed folders
/// - Enables multi-context prefetching (warm multiple folder contexts)
/// - Enables context-aware eviction (evict oldest contexts first)
/// 
/// Used by:
/// - AssetPrefetcher: Multi-context prefetching to Tier 0
/// - MemoryGovernor: Evict by folder context on memory pressure
class RecentFoldersService {
  /// LRU queue: most recent at front, oldest at back
  /// null represents the root folder
  final _lruQueue = Queue<int?>();
  
  /// Maximum number of recent folders to track
  static const int maxRecent = 5;
  
  /// Get the recent folders (most recent first)
  List<int?> get recentFolders => _lruQueue.toList();
  
  /// Get count of recent folders
  int get count => _lruQueue.length;
  
  /// Record a folder visit
  /// - If folder is already in queue, moves it to front
  /// - If queue is full, removes oldest entry
  void recordVisit(int? folderId) {
    // Remove if already present (will re-add at front)
    _lruQueue.remove(folderId);
    
    // Add to front (most recent)
    _lruQueue.addFirst(folderId);
    
    // Evict oldest if over limit
    while (_lruQueue.length > maxRecent) {
      final evicted = _lruQueue.removeLast();
      debugPrint('[RecentFolders] Evicted oldest context: $evicted');
    }
    
    debugPrint('[RecentFolders] Visited folder: $folderId (queue: ${_lruQueue.length})');
  }
  
  /// Get folders to prefetch (all except current folder)
  /// Returns up to (maxRecent - 1) folders for multi-context warming
  List<int?> getFoldersToWarm(int? currentFolder) {
    return _lruQueue
        .where((f) => f != currentFolder)
        .take(maxRecent - 1)
        .toList();
  }
  
  /// Check if a folder is in the recent set
  bool isRecent(int? folderId) => _lruQueue.contains(folderId);
  
  /// Get the "staleness" rank of a folder (0 = most recent, higher = older)
  /// Returns -1 if folder is not in queue
  int getRank(int? folderId) {
    final list = _lruQueue.toList();
    return list.indexOf(folderId);
  }
  
  /// Get eviction order (oldest first)
  /// Used by MemoryGovernor for context-aware eviction
  List<int?> getEvictionOrder() {
    return _lruQueue.toList().reversed.toList();
  }
  
  /// Clear all tracked folders
  void clear() {
    _lruQueue.clear();
    debugPrint('[RecentFolders] Cleared all contexts');
  }
}

/// Provider for RecentFoldersService
final recentFoldersServiceProvider = Provider<RecentFoldersService>((ref) {
  ref.keepAlive();
  return RecentFoldersService();
});
