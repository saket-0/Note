/// Selection Module - Controller
/// 
/// Handles all selection-related actions. Isolated from other dashboard logic.
/// Optimistic updates with seamless UX - no loading screens.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/data/data_repository.dart';
import '../../../../shared/domain/entities/entities.dart';
import '../../../../shared/services/folder_service.dart';
import '../providers/dashboard_state.dart';
import 'providers/selection_providers.dart';

/// Controller for selection-related actions
/// 
/// Usage: `ref.read(selectionControllerProvider).toggleSelection(item)`
final selectionControllerProvider = Provider<SelectionController>((ref) {
  return SelectionController(ref);
});

class SelectionController {
  final Ref _ref;
  
  SelectionController(this._ref);
  
  DataRepository get _repo => _ref.read(dataRepositoryProvider);
  Set<String> get selectedItems => _ref.read(selectedItemsProvider);
  bool get isSelectionMode => _ref.read(isSelectionModeProvider);
  
  // ============================================
  // SELECTION ACTIONS
  // ============================================
  
  /// Toggle selection for an item (with haptic feedback)
  void toggleSelection(dynamic item, {bool haptic = true}) {
    final key = _getItemKey(item);
    final current = _ref.read(selectedItemsProvider);
    final newSet = Set<String>.from(current);
    
    if (newSet.contains(key)) {
      newSet.remove(key);
    } else {
      newSet.add(key);
      if (haptic) HapticFeedback.selectionClick();
    }
    
    _ref.read(selectedItemsProvider.notifier).state = newSet;
  }
  
  /// Select a single item (entering selection mode)
  void selectItem(dynamic item, {bool haptic = true}) {
    final key = _getItemKey(item);
    final current = _ref.read(selectedItemsProvider);
    
    if (!current.contains(key)) {
      final newSet = Set<String>.from(current)..add(key);
      _ref.read(selectedItemsProvider.notifier).state = newSet;
      if (haptic) HapticFeedback.heavyImpact();
    }
  }
  
  /// Clear all selections (exit selection mode)
  void clearSelection() {
    _ref.read(selectedItemsProvider.notifier).state = {};
  }
  
  /// Select all items in the given list
  void selectAll(List<dynamic> items) {
    final newSet = <String>{};
    for (var item in items) {
      newSet.add(_getItemKey(item));
    }
    _ref.read(selectedItemsProvider.notifier).state = newSet;
  }
  
  /// Check if item is selected
  bool isSelected(dynamic item) {
    return selectedItems.contains(_getItemKey(item));
  }
  
  // ============================================
  // BATCH ACTIONS (Optimistic - No Loading)
  // ============================================
  
  /// Pin/Unpin all selected notes
  Future<void> pinSelectedItems(bool pin) async {
    final items = _getSelectedNotes();
    // Optimistic: Update UI immediately, then persist
    for (final note in items) {
      await _repo.updateNote(note.copyWith(isPinned: pin));
    }
    clearSelection();
  }
  
  /// Set color for all selected notes
  Future<void> setColorForSelected(int color) async {
    final items = _getSelectedNotes();
    for (final note in items) {
      await _repo.updateNote(note.copyWith(color: color));
    }
    clearSelection();
  }
  
  /// Archive all selected items (batch operation - instant UI update)
  Future<void> archiveSelectedItems(bool archive) async {
    final items = getSelectedItems();
    if (items.isEmpty) return;
    
    // Collect keys BEFORE archiving (for immediate UI removal)
    final keysToRemove = selectedItems.toSet();
    
    // Single batch call: updates cache, triggers ONE UI rebuild, then DB persist
    await _repo.archiveItems(items, archive);
    
    // Signal immediate removal from grid (only when archiving, not unarchiving)
    if (archive) {
      _ref.read(pendingRemovalKeysProvider.notifier).state = keysToRemove;
    }
    
    clearSelection();
  }
  
  /// Delete all selected items (batch operation - instant UI update)
  Future<void> deleteSelectedItems({required bool permanent}) async {
    final items = getSelectedItems();
    if (items.isEmpty) return;
    
    // Collect keys BEFORE deleting (for immediate UI removal)
    final keysToRemove = selectedItems.toSet();
    
    // Single batch call: updates cache, triggers ONE UI rebuild, then DB persist
    await _repo.deleteItems(items, permanent: permanent);
    
    // Signal immediate removal from grid
    _ref.read(pendingRemovalKeysProvider.notifier).state = keysToRemove;
    
    clearSelection();
  }
  
  // ============================================
  // HELPERS
  // ============================================
  
  /// Get all selected items (notes and folders)
  List<dynamic> getSelectedItems() {
    final items = <dynamic>[];
    for (final key in selectedItems) {
      final parsed = _parseKey(key);
      if (parsed == null) continue;
      
      dynamic item;
      if (parsed.type == 'folder') {
        item = _repo.findFolder(parsed.id);
      } else {
        item = _repo.findNote(parsed.id);
      }
      
      if (item != null) items.add(item);
    }
    return items;
  }
  
  // ============================================
  // FOLDER GROUPING
  // ============================================
  
  /// Group all selected items into a new folder.
  /// 
  /// On success: clears selection, returns folder ID
  /// On failure: keeps selection (allow retry), returns null
  Future<int?> groupSelectedIntoFolder(String folderName, int? parentId) async {
    final folderService = _ref.read(folderServiceProvider);
    final items = getSelectedItems();
    
    if (items.isEmpty) {
      return null;
    }
    
    // Collect keys BEFORE moving (for immediate UI removal)
    final keysToRemove = selectedItems.toSet();
    
    try {
      final folderId = await folderService.createFolderFromSelection(
        items: items,
        folderName: folderName,
        parentId: parentId,
      );
      
      if (folderId != null) {
        HapticFeedback.mediumImpact();
        
        // Signal immediate removal from grid
        _ref.read(pendingRemovalKeysProvider.notifier).state = keysToRemove;
        
        clearSelection();
      }
      return folderId;
    } catch (e) {
      // Error handled by FolderService, do NOT clear selection
      return null;
    }
  }
  
  String _getItemKey(dynamic item) {
    return (item is Folder) ? "folder_${item.id}" : "note_${item.id}";
  }
  
  List<Note> _getSelectedNotes() {
    final notes = <Note>[];
    for (final key in selectedItems) {
      final parsed = _parseKey(key);
      if (parsed != null && parsed.type == 'note') {
        final note = _repo.findNote(parsed.id);
        if (note != null) notes.add(note);
      }
    }
    return notes;
  }
  
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
