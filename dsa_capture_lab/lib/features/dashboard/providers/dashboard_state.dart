import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';

// Tracks the current folder ID (null = root)
final currentFolderProvider = StateProvider<int?>((ref) => null);

// Trigger to force refresh
final refreshTriggerProvider = StateProvider<int>((ref) => 0);

// Unified Content Provider (StateNotifier for Optimistic Updates)
final contentProvider = StateNotifierProvider.family<ContentViewModel, AsyncValue<List<dynamic>>, int?>((ref, folderId) {
  return ContentViewModel(ref, folderId);
});

class ContentViewModel extends StateNotifier<AsyncValue<List<dynamic>>> {
  final Ref ref;
  final int? folderId;

  ContentViewModel(this.ref, this.folderId) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) state = const AsyncValue.loading();
    try {
      final db = ref.read(dbProvider);
      final folders = await db.getFolders(folderId);
      final notes = await db.getNotes(folderId);
      final allItems = [...folders, ...notes];
      _sortItems(allItems);
      state = AsyncValue.data(allItems);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  // Optimistic Reorder
  Future<void> reorderItem(dynamic item, int newPosition, {String zone = 'merge'}) async {
     // If merge (folder creation), we rely on full reload for now as structure changes complexly
     if (zone == 'merge') {
       // Logic handled by controller, then it calls load()
       return; 
     }
     
     // For simple reordering (if implemented later) or UI feedback
     // Currently handleDrop mostly merges. 
     // If we implement pure reordering:
     final currentList = state.value ?? [];
     // ... logic ...
     // For now, let's allow external reload.
  }

  // Optimistic Delete
  void removeItem(dynamic item) {
    if (state.value == null) return;
    final currentList = List<dynamic>.from(state.value!);
    currentList.removeWhere((element) => element.id == item.id && element.runtimeType == item.runtimeType);
    state = AsyncValue.data(currentList);
  }

  // Optimistic List Update (For Reordering)
  void updateList(List<dynamic> newItems) {
    state = AsyncValue.data(newItems);
  }

  void _sortItems(List<dynamic> items) {
     items.sort((a, b) {
      final aPinned = (a is Note && a.isPinned);
      final bPinned = (b is Note && b.isPinned);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      
      int posA = (a is Folder) ? a.position : (a as Note).position;
      int posB = (b is Folder) ? b.position : (b as Note).position;
      
      return posA.compareTo(posB);
    });
  }
}

// Cache the Folder Object itself
final folderDetailsProvider = FutureProvider.family<Folder?, int>((ref, id) async {
  final db = ref.watch(dbProvider);
  return await db.getFolder(id);
});
