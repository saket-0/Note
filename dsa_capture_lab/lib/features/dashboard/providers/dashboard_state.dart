import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/cache/cache_service.dart';

// Filter Enum
enum DashboardFilter { active, archived, trash }

// View Mode Enum
enum ViewMode { grid, list }

// Current Filter Provider
final activeFilterProvider = StateProvider<DashboardFilter>((ref) => DashboardFilter.active);

// View Mode Provider (grid by default)
final viewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.grid);

// Tracks the current folder ID (null = root)
final currentFolderProvider = StateProvider<int?>((ref) => null);

// Trigger to force refresh (incremented to trigger rebuilds)
final refreshTriggerProvider = StateProvider<int>((ref) => 0);

// --- MEMORY-FIRST PROVIDERS ---
// These read directly from CacheService (SYNCHRONOUS!)

/// Active content for a specific folder (hierarchical)
final activeContentProvider = Provider.family<List<dynamic>, int?>((ref, folderId) {
  // Watch refresh trigger to rebuild when data changes
  ref.watch(refreshTriggerProvider);
  
  final cache = ref.read(cacheServiceProvider);
  return cache.getActiveContent(folderId);
});

/// All archived items (flat list)
final archivedContentProvider = Provider<List<dynamic>>((ref) {
  ref.watch(refreshTriggerProvider);
  
  final cache = ref.read(cacheServiceProvider);
  return cache.getArchivedContent();
});

/// All trashed items (flat list)
final trashContentProvider = Provider<List<dynamic>>((ref) {
  ref.watch(refreshTriggerProvider);
  
  final cache = ref.read(cacheServiceProvider);
  return cache.getTrashedContent();
});

// Cache the Folder Object itself
final folderDetailsProvider = FutureProvider.family<Folder?, int>((ref, id) async {
  final db = ref.watch(dbProvider);
  return await db.getFolder(id);
});

