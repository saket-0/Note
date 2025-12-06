import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dashboard/providers/dashboard_state.dart';
import '../../../core/database/app_database.dart';

// State Class
class BatchCameraState {
  final bool isBatchMode;
  final List<String> capturedPaths;

  BatchCameraState({required this.isBatchMode, required this.capturedPaths});

  BatchCameraState copyWith({bool? isBatchMode, List<String>? capturedPaths}) {
    return BatchCameraState(
      isBatchMode: isBatchMode ?? this.isBatchMode,
      capturedPaths: capturedPaths ?? this.capturedPaths,
    );
  }
}

// Provider
final cameraViewModelProvider = StateNotifierProvider.autoDispose<CameraViewModel, BatchCameraState>((ref) {
  return CameraViewModel(ref);
});

// ViewModel
class CameraViewModel extends StateNotifier<BatchCameraState> {
  final Ref ref;

  CameraViewModel(this.ref) : super(BatchCameraState(isBatchMode: false, capturedPaths: []));

  void toggleMode(bool isBatch) {
    state = state.copyWith(isBatchMode: isBatch);
    // If switching OFF batch mode, we technically clear the queue? 
    // Or we keep it until 'discard' or 'save' is pressed. 
    // Let's keep it safe: Don't clear automatically to avoid data loss.
  }

  void addPhoto(String path) {
    state = state.copyWith(capturedPaths: [...state.capturedPaths, path]);
  }

  void removePhoto(String path) {
    final newList = List<String>.from(state.capturedPaths)..remove(path);
    state = state.copyWith(capturedPaths: newList);
    // Also delete file
    try { File(path).delete(); } catch (_) {} 
  }

  void clearBatch() {
    // Delete all temporary files if they weren't saved?
    // This method assumes Discard All.
    for (var path in state.capturedPaths) {
      try { File(path).delete(); } catch (_) {}
    }
    state = state.copyWith(capturedPaths: []);
  }

  Future<void> saveBatch(int? currentFolderId) async {
    if (state.capturedPaths.isEmpty) return;

    final db = ref.read(dbProvider);
    
    // 1. Create Folder
    final String folderName = "Capture ${DateTime.now().toString().substring(0, 16)}"; // e.g., "Capture 2023-10-27 10:30"
    final int newFolderId = await db.createFolder(folderName, currentFolderId);

    // 2. Save All Photos into this folder
    for (var path in state.capturedPaths) {
      await db.createNote(
        title: "Img ${DateTime.now().millisecondsSinceEpoch}", 
        content: "", 
        imagePath: path,
        folderId: newFolderId,
        fileType: 'image'
      );
    }

    // 3. Clear State
    state = state.copyWith(capturedPaths: []);
    ref.read(refreshTriggerProvider.notifier).state++;
  }
  
  // Single Save helper
  Future<void> saveSingle(String path, int? folderId) async {
    final db = ref.read(dbProvider);
    await db.createNote(
      title: "Snapshot ${DateTime.now().minute}:${DateTime.now().second}",
      content: "",
      imagePath: path,
      folderId: folderId,
      fileType: 'image'
    );
    ref.read(refreshTriggerProvider.notifier).state++;
  }
}
