import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dashboard/providers/dashboard_state.dart';
import '../../../core/database/app_database.dart';
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
    // Persist session across toggles? For now, we keep it.
  }

  // Instant Batch Save
  Future<void> captureBatchPhoto(String path, int? parentFolderId) async {
    final db = ref.read(dbProvider);
    
    // 1. Ensure Batch Folder Exists
    int folderId;
    if (state.activeBatchFolderId == null) {
      final String folderName = "Batch ${DateTime.now().hour}:${DateTime.now().minute}"; 
      folderId = await db.createFolder(folderName, parentFolderId);
      state = state.copyWith(activeBatchFolderId: folderId);
    } else {
      folderId = state.activeBatchFolderId!;
    }

    // 2. Save Photo Immediately
    final int noteId = await db.createNote(
      title: "Img ${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}", 
      content: "", 
      imagePath: path,
      folderId: folderId,
      fileType: 'image'
    );
    
    // 3. Create Note Object for Local State (Optimistic/Confirmed)
    final newNote = Note(
      id: noteId, 
      title: "Img...", 
      content: "", 
      imagePath: path, 
      folderId: folderId, 
      createdAt: DateTime.now(), 
      fileType: 'image'
    );

    state = state.copyWith(capturedItems: [...state.capturedItems, newNote]);
    ref.read(refreshTriggerProvider.notifier).state++;
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
  
  // Single Save helper (Returns Note ID)
  Future<int> saveSingle(String path, int? folderId) async {
    final db = ref.read(dbProvider);
    final id = await db.createNote(
      title: "Snapshot ${DateTime.now().minute}:${DateTime.now().second}",
      content: "",
      imagePath: path,
      folderId: folderId,
      fileType: 'image'
    );
    ref.read(refreshTriggerProvider.notifier).state++;
    return id;
  }

  Future<void> deleteNote(int id) async {
    final db = ref.read(dbProvider);
    await db.deleteNote(id);
    ref.read(refreshTriggerProvider.notifier).state++;
  }
}
