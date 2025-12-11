import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/data/notes_repository.dart';
import '../../../shared/database/drift/app_database.dart';

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

/// Tracks if user is scrolling at high velocity (for pausing image loads)
/// When true, SmartImage shows placeholders instead of triggering decodes
/// Threshold: 2000 pixels per second (set in DashboardContent)
final isHighVelocityScrollProvider = StateProvider<bool>((ref) => false);

// ===========================================
// REACTIVE STREAM PROVIDERS (Drift-powered)
// ===========================================

/// Active content stream for current folder - auto-updates when DB changes
/// This replaces the old version-counter approach with true reactivity.
final activeContentStreamProvider = StreamProvider.family<List<dynamic>, int?>((ref, folderId) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchActiveContent(folderId);
});

/// Archived content stream - auto-updates when DB changes
final archivedContentStreamProvider = StreamProvider<List<dynamic>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchArchivedContent();
});

/// Trashed content stream - auto-updates when DB changes
final trashedContentStreamProvider = StreamProvider<List<dynamic>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchTrashedContent();
});

/// Folders stream for a parent - auto-updates when DB changes
final foldersStreamProvider = StreamProvider.family<List<Folder>, int?>((ref, parentId) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchFolders(parentId);
});

/// Notes stream for a folder - auto-updates when DB changes
final notesStreamProvider = StreamProvider.family<List<Note>, int?>((ref, folderId) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchNotes(folderId);
});

// ===========================================
// LEGACY SYNC PROVIDERS (for backward compatibility)
// These use FutureProvider to bridge async lookups
// ===========================================

/// Folder details lookup (async)
final folderDetailsProvider = FutureProvider.family<Folder?, int>((ref, id) async {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.getFolder(id);
});

/// Get all image paths for a folder (for preloading)
final folderImagePathsProvider = FutureProvider.family<List<String>, int?>((ref, folderId) async {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.getImagePathsForFolder(folderId);
});

/// Get subfolder IDs for prefetching
final subfolderIdsProvider = FutureProvider.family<List<int>, int?>((ref, parentId) async {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.getSubfolderIds(parentId);
});

// ===========================================
// CONVENIENCE PROVIDERS
// ===========================================

/// Current folder's content based on active filter
/// Returns the appropriate stream based on filter selection
final currentContentProvider = Provider<AsyncValue<List<dynamic>>>((ref) {
  final filter = ref.watch(activeFilterProvider);
  final folderId = ref.watch(currentFolderProvider);
  
  switch (filter) {
    case DashboardFilter.active:
      return ref.watch(activeContentStreamProvider(folderId));
    case DashboardFilter.archived:
      return ref.watch(archivedContentStreamProvider);
    case DashboardFilter.trash:
      return ref.watch(trashedContentStreamProvider);
  }
});
