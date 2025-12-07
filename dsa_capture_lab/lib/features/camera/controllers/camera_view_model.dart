import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dashboard/providers/dashboard_state.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/cache/cache_service.dart';
import '../models/batch_camera_state.dart';
export '../models/batch_camera_state.dart';


// Provider
final cameraViewModelProvider = StateNotifierProvider.autoDispose<CameraViewModel, BatchCameraState>((ref) {
  return CameraViewModel(ref);
});

// ViewModel
class CameraViewModel extends StateNotifier<BatchCameraState> {
  final Ref ref;

  CameraViewModel(this.ref) : super(BatchCameraState(isBatchMode: false, capturedItems: []));

  void toggleMode(bool isBatch) {
    state = state.copyWith(isBatchMode: isBatch);
  }

  // Instant Batch Save - OPTIMISTIC
  Future<void> captureBatchPhoto(String path, int? parentFolderId) async {
    final db = ref.read(dbProvider);
    final cache = ref.read(cacheServiceProvider);
    
    // 1. Ensure Batch Folder Exists (optimistically if needed)
    int folderId;
    if (state.activeBatchFolderId == null) {
      final String folderName = "Batch ${DateTime.now().hour}:${DateTime.now().minute}";
      
      // Create folder optimistically
      final tempFolderId = cache.generateTempId();
      final tempFolder = Folder(
        id: tempFolderId,
        name: folderName,
        parentId: parentFolderId,
        createdAt: DateTime.now(),
        position: 999,
      );
      cache.addFolderOptimistic(tempFolder);
      
      // Use temp ID for now
      folderId = tempFolderId;
      state = state.copyWith(activeBatchFolderId: tempFolderId);
      
      // Background: Create real folder and update ID
      db.createFolder(folderName, parentFolderId).then((realId) {
        cache.resolveTempId(tempFolderId, realId, isFolder: true);
        state = state.copyWith(activeBatchFolderId: realId);
      });
    } else {
      folderId = state.activeBatchFolderId!;
    }

    // 2. Create Note optimistically
    final tempNoteId = cache.generateTempId();
    final tempNote = Note(
      id: tempNoteId,
      title: "Img ${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}",
      content: "",
      imagePath: path,
      folderId: folderId,
      createdAt: DateTime.now(),
      fileType: 'image',
      position: 999,
    );
    
    // Add to MAIN CACHE for instant display on dashboard
    cache.addNoteOptimistic(tempNote);
    
    // Add to local batch state for camera preview
    state = state.copyWith(capturedItems: [...state.capturedItems, tempNote]);
    ref.read(refreshTriggerProvider.notifier).state++;
    
    // 3. Persist to DB in background
    db.createNote(
      title: tempNote.title,
      content: "",
      imagePath: path,
      folderId: folderId,
      fileType: 'image'
    ).then((realId) {
      cache.resolveTempId(tempNoteId, realId, isFolder: false);
      // Update local state with real ID
      final updatedItems = state.capturedItems.map((n) {
        if (n.id == tempNoteId) {
          return Note(
            id: realId,
            title: n.title,
            content: n.content,
            imagePath: n.imagePath,
            folderId: n.folderId,
            createdAt: n.createdAt,
            fileType: n.fileType,
          );
        }
        return n;
      }).toList();
      state = state.copyWith(capturedItems: updatedItems);
    });
  }

  // Purely Optimistic Delete
  Future<void> deleteBatchPhoto(Note note) async {
    // 1. Update UI Immediately
    final newList = List<Note>.from(state.capturedItems)..removeWhere((n) => n.id == note.id);
    state = state.copyWith(capturedItems: newList);
    
    // 2. Process in Background
    final db = ref.read(dbProvider);
    await db.deleteNote(note.id);
    // Cleanup file? usually beneficial but optional for speed.
    try { File(note.imagePath!).delete(); } catch (_) {}
    
    ref.read(refreshTriggerProvider.notifier).state++;
  }

  Future<void> discardBatch() async {
    final itemsToDelete = List<Note>.from(state.capturedItems);
    final folderId = state.activeBatchFolderId;

    // 1. Clear UI Immediately
    state = state.copyWith(capturedItems: [], activeBatchFolderId: null);

    // 2. Background Cleanup
    final db = ref.read(dbProvider);
    for (var note in itemsToDelete) {
       await db.deleteNote(note.id);
       try { File(note.imagePath!).delete(); } catch (_) {}
    }
    if (folderId != null) {
      await db.deleteFolder(folderId);
    }
    
    ref.read(refreshTriggerProvider.notifier).state++;
  }

  void endBatchSession() {
    state = state.copyWith(capturedItems: [], activeBatchFolderId: null);
  }
  
  // Single Save helper - OPTIMISTIC (Returns temp ID immediately)
  Future<int> saveSingle(String path, int? folderId) async {
    final db = ref.read(dbProvider);
    final cache = ref.read(cacheServiceProvider);
    
    // 1. Generate Temp ID & Add to MAIN CACHE immediately
    final tempId = cache.generateTempId();
    final tempNote = Note(
      id: tempId,
      title: "Snapshot ${DateTime.now().minute}:${DateTime.now().second}",
      content: "",
      imagePath: path,
      folderId: folderId,
      createdAt: DateTime.now(),
      fileType: 'image',
      position: 999,
    );
    
    // Add to cache IMMEDIATELY - dashboard will see it instantly
    cache.addNoteOptimistic(tempNote);
    ref.read(refreshTriggerProvider.notifier).state++;
    
    // 2. Persist to DB in background
    final realId = await db.createNote(
      title: tempNote.title,
      content: "",
      imagePath: path,
      folderId: folderId,
      fileType: 'image'
    );
    
    // 3. Resolve temp ID to real ID
    cache.resolveTempId(tempId, realId, isFolder: false);
    
    return realId;
  }

  Future<void> deleteNote(int id) async {
    final db = ref.read(dbProvider);
    final cache = ref.read(cacheServiceProvider);
    
    // Cache-first delete for instant UI
    cache.removeNote(id);
    ref.read(refreshTriggerProvider.notifier).state++;
    
    // Background DB delete
    await db.deleteNote(id);
  }
}
