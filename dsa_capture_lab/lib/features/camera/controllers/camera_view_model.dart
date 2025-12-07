import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dashboard/providers/dashboard_state.dart';
import '../../../shared/data/data_repository.dart';
import '../../../shared/domain/entities/entities.dart';
import '../models/batch_camera_state.dart';
export '../models/batch_camera_state.dart';

// Provider
final cameraViewModelProvider = StateNotifierProvider.autoDispose<CameraViewModel, BatchCameraState>((ref) {
  return CameraViewModel(ref);
});

// ViewModel - Uses DataRepository for cache-first operations
class CameraViewModel extends StateNotifier<BatchCameraState> {
  final Ref ref;

  CameraViewModel(this.ref) : super(BatchCameraState(isBatchMode: false, capturedItems: []));

  DataRepository get _repo => ref.read(dataRepositoryProvider);

  void toggleMode(bool isBatch) {
    state = state.copyWith(isBatchMode: isBatch);
  }

  // Instant Batch Save - OPTIMISTIC via DataRepository
  Future<void> captureBatchPhoto(String path, int? parentFolderId) async {
    // 1. Ensure Batch Folder Exists
    int folderId;
    if (state.activeBatchFolderId == null) {
      final String folderName = "Batch ${DateTime.now().hour}:${DateTime.now().minute}";
      
      // Create folder via repository (optimistic)
      final newFolderId = await _repo.createFolder(
        name: folderName,
        parentId: parentFolderId,
      );
      
      folderId = newFolderId;
      state = state.copyWith(activeBatchFolderId: newFolderId);
    } else {
      folderId = state.activeBatchFolderId!;
    }

    // 2. Create Note via repository (optimistic)
    final noteId = await _repo.createNote(
      title: "Img ${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}",
      content: "",
      imagePath: path,
      folderId: folderId,
      fileType: 'image',
    );

    // Get the created note from cache for local state
    final createdNote = _repo.findNote(noteId);
    if (createdNote != null) {
      state = state.copyWith(capturedItems: [...state.capturedItems, createdNote]);
    }
  }

  // Purely Optimistic Delete via DataRepository
  Future<void> deleteBatchPhoto(Note note) async {
    // 1. Update local UI Immediately
    final newList = List<Note>.from(state.capturedItems)..removeWhere((n) => n.id == note.id);
    state = state.copyWith(capturedItems: newList);

    // 2. Delete via repository (handles cache + DB)
    await _repo.deleteNote(note.id, permanent: true);

    // 3. Cleanup file
    try {
      File(note.imagePath!).delete();
    } catch (_) {}
  }

  Future<void> discardBatch() async {
    final itemsToDelete = List<Note>.from(state.capturedItems);
    final folderId = state.activeBatchFolderId;

    // 1. Clear UI Immediately
    state = state.copyWith(capturedItems: [], activeBatchFolderId: null);

    // 2. Background Cleanup via repository
    for (var note in itemsToDelete) {
      await _repo.deleteNote(note.id, permanent: true);
      try {
        File(note.imagePath!).delete();
      } catch (_) {}
    }
    if (folderId != null) {
      await _repo.deleteFolder(folderId, permanent: true);
    }
  }

  void endBatchSession() {
    state = state.copyWith(capturedItems: [], activeBatchFolderId: null);
  }

  // Single Save helper - OPTIMISTIC via DataRepository
  Future<int> saveSingle(String path, int? folderId) async {
    return await _repo.createNote(
      title: "Snapshot ${DateTime.now().minute}:${DateTime.now().second}",
      content: "",
      imagePath: path,
      folderId: folderId,
      fileType: 'image',
    );
  }

  Future<void> deleteNote(int id) async {
    await _repo.deleteNote(id, permanent: true);
  }
}
