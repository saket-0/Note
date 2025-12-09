import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/data_repository.dart';
import '../../features/dashboard/providers/dashboard_state.dart';

/// SmartCacheEngine - A robust bi-directional image caching engine.
/// 
/// Features:
/// - **Priority-based caching**: Current → Parent → Subfolders
/// - **Job cancellation**: Aborts stale work when folder changes mid-processing
/// - **Debouncing**: 300ms pause prevents wasted work during rapid navigation
/// - **Throttling**: 50ms delay between subfolders yields to UI thread
/// 
/// This engine observes [currentFolderProvider] and automatically optimizes
/// the image cache based on the user's navigation state. No manual intervention
/// required - just watch the provider to activate it.
class SmartCacheEngine {
  final Ref _ref;
  final BuildContext _context;
  
  // Job versioning for cancellation
  int _currentJobVersion = 0;
  
  // Debouncing
  Timer? _debounceTimer;
  static const _debounceDelay = Duration(milliseconds: 300);
  
  // Throttling delay between subfolder processing
  static const _throttleDelay = Duration(milliseconds: 50);
  
  // Track preloaded paths to avoid duplicate work
  final Set<String> _preloadedPaths = {};
  
  // Track "priority" paths that should be retained (parent folder)
  final Set<String> _priorityPaths = {};
  
  SmartCacheEngine(this._ref, this._context) {
    // Start observing folder changes
    _ref.listen<int?>(currentFolderProvider, (previous, next) {
      _onFolderChanged(next);
    });
    
    // Initial cache optimization for root folder
    _scheduleOptimization(null);
  }
  
  /// Called when the current folder changes.
  /// Increments job version to cancel any in-progress work,
  /// then schedules new optimization after debounce delay.
  void _onFolderChanged(int? newFolderId) {
    // Cancel any in-progress work
    _currentJobVersion++;
    
    // Schedule new optimization with debouncing
    _scheduleOptimization(newFolderId);
  }
  
  /// Schedule cache optimization with debouncing.
  /// Waits for navigation to settle before starting heavy work.
  void _scheduleOptimization(int? folderId) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      final version = _currentJobVersion;
      _optimizeCache(folderId, version);
    });
  }
  
  /// Main optimization routine with priority-based caching.
  /// 
  /// Priority 1: Current folder (immediate, no delay)
  /// Priority 2: Parent folder (backward navigation support)
  /// Priority 3: Subfolders (forward navigation, with throttling)
  Future<void> _optimizeCache(int? currentFolderId, int version) async {
    if (!_context.mounted) return;
    
    final repo = _ref.read(dataRepositoryProvider);
    
    // === PRIORITY 1: Current folder (immediate) ===
    final currentNotes = repo.getNotesForFolder(currentFolderId);
    await _cacheNotes(currentNotes, version);
    if (version != _currentJobVersion) return;
    
    // === PRIORITY 2: Parent folder (backward navigation) ===
    final parentId = _getParentId(currentFolderId, repo);
    // Cache parent if we're in a subfolder, or root if we're at non-root
    if (currentFolderId != null || parentId != null) {
      // Mark parent paths as priority (should be retained)
      final parentNotes = repo.getNotesForFolder(parentId);
      _priorityPaths.clear();
      for (final note in parentNotes) {
        if (note.imagePath != null) _priorityPaths.add(note.imagePath!);
        _priorityPaths.addAll(note.images);
      }
      
      await _cacheNotes(parentNotes, version);
      if (version != _currentJobVersion) return;
    }
    
    // === PRIORITY 3: Subfolders (forward navigation, throttled) ===
    final subfolderIds = repo.getSubfolderIds(currentFolderId);
    for (final subfolderId in subfolderIds) {
      // Check for cancellation before each subfolder
      if (version != _currentJobVersion) return;
      if (!_context.mounted) return;
      
      final subNotes = repo.getNotesForFolder(subfolderId);
      await _cacheNotes(subNotes, version);
      
      // Yield to UI thread to prevent frame drops
      await Future.delayed(_throttleDelay);
    }
  }
  
  /// Get the parent folder ID for a given folder.
  /// Returns null for root folder.
  int? _getParentId(int? folderId, DataRepository repo) {
    if (folderId == null) return null;
    
    final folder = repo.findFolder(folderId);
    return folder?.parentId;
  }
  
  /// Cache images for a list of notes.
  /// Skips already-cached paths to avoid redundant work.
  Future<void> _cacheNotes(List<Note> notes, int version) async {
    for (final note in notes) {
      if (version != _currentJobVersion) return;
      if (!_context.mounted) return;
      
      await _cacheNote(note);
    }
  }
  
  /// Cache images for a single note.
  Future<void> _cacheNote(Note note) async {
    // Cache images list
    for (final imagePath in note.images) {
      await _cacheImage(imagePath);
    }
    
    // Cache single image path if present
    if (note.imagePath != null && note.imagePath!.isNotEmpty) {
      await _cacheImage(note.imagePath!);
    }
  }
  
  /// Cache a single image into Flutter's image cache.
  Future<void> _cacheImage(String path) async {
    // Skip if already cached
    if (_preloadedPaths.contains(path)) return;
    if (!_context.mounted) return;
    
    try {
      final file = File(path);
      if (await file.exists()) {
        final imageProvider = ResizeImage(
          FileImage(file),
          width: 400, // Match the cacheWidth used in display
        );
        
        await precacheImage(imageProvider, _context);
        _preloadedPaths.add(path);
      }
    } catch (e) {
      // Silently ignore cache failures
    }
  }
  
  /// Dispose resources when engine is no longer needed.
  void dispose() {
    _debounceTimer?.cancel();
  }
}

/// Provider for SmartCacheEngine.
/// 
/// Usage: `ref.watch(smartCacheEngineProvider(context))` in your widget's build method.
/// The engine will automatically observe folder changes and optimize the cache.
/// 
/// Note: Using `.family` with BuildContext because precacheImage requires context.
final smartCacheEngineProvider = Provider.family<SmartCacheEngine, BuildContext>((ref, context) {
  final engine = SmartCacheEngine(ref, context);
  
  ref.onDispose(() {
    engine.dispose();
  });
  
  return engine;
});
