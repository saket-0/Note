import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/data/data_repository.dart';
import '../../../shared/domain/entities/entities.dart';

// Re-export for backward compatibility
export '../../../shared/domain/entities/entities.dart';

// ===========================================
// FILTER & VIEW STATE
// ===========================================

enum DashboardFilter { active, archived, trash }
enum ViewMode { grid, list }

final activeFilterProvider = StateProvider<DashboardFilter>((ref) => DashboardFilter.active);
final viewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.grid);
final currentFolderProvider = StateProvider<int?>((ref) => null);

/// Tracks if the glide menu is currently open (for scroll-locking)
final isGlideMenuOpenProvider = StateProvider<bool>((ref) => false);

/// Keys of items that were just moved and should be removed from grid immediately
/// Format: {"note_123", "folder_456"}. Cleared after consumption.
final pendingRemovalKeysProvider = StateProvider<Set<String>>((ref) => {});

// ===========================================
// REACTIVE DATA PROVIDERS
// Uses version from DataRepository for automatic updates
// ===========================================

/// Version counter that triggers rebuilds on data changes
final dataVersionProvider = StateProvider<int>((ref) => 0);

/// Active content for a folder - rebuilds when version changes
final activeContentProvider = Provider.family<List<dynamic>, int?>((ref, folderId) {
  // Watch the version counter to trigger rebuilds
  ref.watch(dataVersionProvider);
  
  final repo = ref.read(dataRepositoryProvider);
  return repo.getActiveContent(folderId);
});

/// Archived content - rebuilds when version changes
final archivedContentProvider = Provider<List<dynamic>>((ref) {
  ref.watch(dataVersionProvider);
  
  final repo = ref.read(dataRepositoryProvider);
  return repo.getArchivedContent();
});

/// Trashed content - rebuilds when version changes
final trashContentProvider = Provider<List<dynamic>>((ref) {
  ref.watch(dataVersionProvider);
  
  final repo = ref.read(dataRepositoryProvider);
  return repo.getTrashedContent();
});

/// Folder details lookup
final folderDetailsProvider = Provider.family<Folder?, int>((ref, id) {
  ref.watch(dataVersionProvider);
  
  final repo = ref.read(dataRepositoryProvider);
  return repo.findFolder(id);
});

/// Get all image paths for a folder (for preloading)
final folderImagePathsProvider = Provider.family<List<String>, int?>((ref, folderId) {
  ref.watch(dataVersionProvider);
  
  final repo = ref.read(dataRepositoryProvider);
  return repo.getImagePathsForFolder(folderId);
});

/// Get subfolder IDs for prefetching
final subfolderIdsProvider = Provider.family<List<int>, int?>((ref, parentId) {
  ref.watch(dataVersionProvider);
  
  final repo = ref.read(dataRepositoryProvider);
  return repo.getSubfolderIds(parentId);
});
