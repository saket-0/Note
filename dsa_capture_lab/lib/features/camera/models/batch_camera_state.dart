
import '../../../core/database/app_database.dart';

class BatchCameraState {
  final bool isBatchMode;
  final List<Note> capturedItems;
  final int? activeBatchFolderId;

  BatchCameraState({
    required this.isBatchMode, 
    required this.capturedItems,
    this.activeBatchFolderId,
  });

  BatchCameraState copyWith({
    bool? isBatchMode, 
    List<Note>? capturedItems,
    int? activeBatchFolderId,
  }) {
    return BatchCameraState(
      isBatchMode: isBatchMode ?? this.isBatchMode,
      capturedItems: capturedItems ?? this.capturedItems,
      activeBatchFolderId: activeBatchFolderId ?? this.activeBatchFolderId,
    );
  }
}
