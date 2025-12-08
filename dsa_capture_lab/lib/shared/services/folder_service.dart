/// Folder Service - Isolated Module for Folder Operations
/// 
/// Handles all folder-related business logic, decoupled from UI.
/// All operations are wrapped in try-catch with proper error handling.
/// 
/// Features:
/// - Move items (notes/folders) into existing folders
/// - Create folders from selection (batch operation)
/// - Optimistic UI support via DataRepository integration
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/data_repository.dart';
import '../domain/entities/entities.dart';

/// Provider for FolderService
final folderServiceProvider = Provider<FolderService>((ref) {
  return FolderService(ref.read(dataRepositoryProvider));
});

/// Dedicated service for folder operations.
/// 
/// Modularity Guarantee:
/// - If any method throws, UI widgets continue to render
/// - All DB calls wrapped in try-catch with error logging
/// - Returns success/failure status for UI feedback
class FolderService {
  final DataRepository _repo;
  
  FolderService(this._repo);
  
  // ============================================
  // MOVE OPERATIONS
  // ============================================
  
  /// Move an item (Note or Folder) into an existing folder.
  /// 
  /// Validates:
  /// - Target must be a Folder
  /// - Cannot move a folder into itself
  /// - Cannot move a folder into its own descendant (prevents cycles)
  /// 
  /// Returns: true on success, false on failure (with error logging)
  Future<bool> moveItemToFolder({
    required dynamic item,
    required int targetFolderId,
  }) async {
    try {
      // Validate target exists and is a folder
      final targetFolder = _repo.findFolder(targetFolderId);
      if (targetFolder == null) {
        debugPrint('[FolderService] Target folder $targetFolderId not found');
        return false;
      }
      
      if (item is Note) {
        await _repo.moveNote(item.id, targetFolderId);
        debugPrint('[FolderService] Moved note ${item.id} to folder $targetFolderId');
        return true;
      } else if (item is Folder) {
        // Prevent moving folder into itself
        if (item.id == targetFolderId) {
          debugPrint('[FolderService] Cannot move folder into itself');
          return false;
        }
        
        // Prevent moving folder into its own descendant
        if (_isDescendantOf(targetFolderId, item.id)) {
          debugPrint('[FolderService] Cannot move folder into its own descendant');
          return false;
        }
        
        await _repo.moveFolder(item.id, targetFolderId);
        debugPrint('[FolderService] Moved folder ${item.id} to folder $targetFolderId');
        return true;
      }
      
      debugPrint('[FolderService] Unknown item type: ${item.runtimeType}');
      return false;
    } catch (e, stack) {
      debugPrint('[FolderService] Error moving item: $e');
      debugPrint('[FolderService] Stack: $stack');
      return false;
    }
  }
  
  /// Move item by parsing drag key (e.g., "note_123" or "folder_456")
  /// 
  /// This is the primary interface for DragTarget drop handling.
  Future<bool> moveItemByKey({
    required String itemKey,
    required int targetFolderId,
  }) async {
    try {
      final parsed = _parseKey(itemKey);
      if (parsed == null) {
        debugPrint('[FolderService] Invalid item key: $itemKey');
        return false;
      }
      
      dynamic item;
      if (parsed.type == 'folder') {
        item = _repo.findFolder(parsed.id);
      } else if (parsed.type == 'note') {
        item = _repo.findNote(parsed.id);
      }
      
      if (item == null) {
        debugPrint('[FolderService] Item not found for key: $itemKey');
        return false;
      }
      
      return moveItemToFolder(item: item, targetFolderId: targetFolderId);
    } catch (e, stack) {
      debugPrint('[FolderService] Error in moveItemByKey: $e');
      debugPrint('[FolderService] Stack: $stack');
      return false;
    }
  }
  
  // ============================================
  // GROUP OPERATIONS
  // ============================================
  
  /// Create a new folder and move all selected items into it.
  /// 
  /// Batch operation for instant UI update:
  /// - Creates folder first
  /// - Then moves all items in single batch call (one UI rebuild)
  /// 
  /// Returns: folder ID on success, null on failure
  /// On failure: caller should NOT clear selection (allow retry)
  Future<int?> createFolderFromSelection({
    required List<dynamic> items,
    required String folderName,
    int? parentId,
  }) async {
    if (items.isEmpty) {
      debugPrint('[FolderService] Cannot create folder: no items selected');
      return null;
    }
    
    try {
      // Step 1: Create the new folder
      final folderId = await _repo.createFolder(
        name: folderName,
        parentId: parentId,
      );
      
      debugPrint('[FolderService] Created folder $folderId: "$folderName"');
      
      // Step 2: Move all items in single batch (instant UI update)
      await _repo.moveItems(items, folderId);
      
      debugPrint('[FolderService] Moved ${items.length} items to folder $folderId');
      
      return folderId;
    } catch (e, stack) {
      debugPrint('[FolderService] Error creating folder from selection: $e');
      debugPrint('[FolderService] Stack: $stack');
      return null;
    }
  }
  
  // ============================================
  // HELPERS
  // ============================================
  
  /// Check if potentialDescendant is a descendant of ancestorId
  /// Used to prevent circular folder references
  bool _isDescendantOf(int potentialDescendantId, int ancestorId) {
    final folder = _repo.findFolder(potentialDescendantId);
    if (folder == null) return false;
    
    int? currentParentId = folder.parentId;
    int depth = 0;
    const maxDepth = 100; // Prevent infinite loops
    
    while (currentParentId != null && depth < maxDepth) {
      if (currentParentId == ancestorId) {
        return true;
      }
      final parent = _repo.findFolder(currentParentId);
      currentParentId = parent?.parentId;
      depth++;
    }
    
    return false;
  }
  
  /// Parse a drag key like "note_123" or "folder_456"
  _ParsedKey? _parseKey(String key) {
    try {
      final parts = key.split('_');
      if (parts.length != 2) return null;
      return _ParsedKey(type: parts[0], id: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }
}

class _ParsedKey {
  final String type;
  final int id;
  _ParsedKey({required this.type, required this.id});
}
