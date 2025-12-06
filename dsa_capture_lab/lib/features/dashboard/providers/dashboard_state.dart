import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';

// Tracks the current folder ID (null = root)
final currentFolderProvider = StateProvider<int?>((ref) => null);

// Trigger to force refresh
final refreshTriggerProvider = StateProvider<int>((ref) => 0);

// Unified Content Provider (Folders + Files)
final contentProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  print("DEBUG: contentProvider fetching data...");
  final db = ref.watch(dbProvider);
  final currentFolderId = ref.watch(currentFolderProvider);
  ref.watch(refreshTriggerProvider); // Watch trigger
  
  try {
    // Fetch both
    final folders = await db.getFolders(currentFolderId);
    final notes = await db.getNotes(currentFolderId);
    print("DEBUG: fetched ${folders.length} folders and ${notes.length} notes");
    
    // Combine (Folders first, then Files)
    return [...folders, ...notes];
  } catch (e, stack) {
    print("DEBUG: contentProvider ERROR: $e");
    print(stack);
    rethrow;
  }
});

final currentFolderObjProvider = FutureProvider.autoDispose<Folder?>((ref) async {
  final db = ref.watch(dbProvider);
  final id = ref.watch(currentFolderProvider);
  if (id == null) return null;
  return await db.getFolder(id);
});
