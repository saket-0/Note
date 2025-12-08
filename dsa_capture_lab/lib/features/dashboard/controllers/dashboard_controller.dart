import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:mime/mime.dart';
import '../../../shared/data/data_repository.dart';
import '../../../shared/domain/entities/entities.dart';
import '../../../shared/ui/page_routes.dart';
import '../../camera/camera_screen.dart';
import '../../editor/editor_screen.dart';
import '../providers/dashboard_state.dart';
import '../providers/selection_state.dart';

class DashboardController {
  final WidgetRef ref;
  final BuildContext context;

  // Selection State (In-Memory for now, or could use a Provider if we want it to persist across rebuilds better)
  // For simplicity, we'll use a StateProvider in the file or just manage it via the ref?
  // Since Controller is recreated on build, we should store state in a Provider.
  // But wait, the previous code instantiates DashboardController in build().
  // So member variables here will be lost.
  // We need to use valid Providers for selection state.
  
  DashboardController(this.context, this.ref);

  DataRepository get _repo => ref.read(dataRepositoryProvider);

  /// Helper to show toast messages with proper duration
  void _showToast(String message, {SnackBarAction? action}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: action,
        ),
      );
  }

  // Helper getters for Selection
  Set<String> get selectedItems => ref.read(selectedItemsProvider); // "note_1", "folder_2"
  bool get isSelectionMode => ref.read(isSelectionModeProvider);

  void toggleSelection(dynamic item) {
    final key = (item is Folder) ? "folder_${item.id}" : "note_${item.id}";
    final current = ref.read(selectedItemsProvider);
    final newSet = Set<String>.from(current);
    
    if (newSet.contains(key)) {
      newSet.remove(key);
    } else {
      newSet.add(key);
    }
    
    ref.read(selectedItemsProvider.notifier).state = newSet;
    ref.read(isSelectionModeProvider.notifier).state = newSet.isNotEmpty;
  }

  void clearSelection() {
    ref.read(selectedItemsProvider.notifier).state = {};
    ref.read(isSelectionModeProvider.notifier).state = false;
  }
  
  void selectAll(List<dynamic> items) {
     final newSet = <String>{};
     for (var item in items) {
        newSet.add((item is Folder) ? "folder_${item.id}" : "note_${item.id}");
     }
     ref.read(selectedItemsProvider.notifier).state = newSet;
     ref.read(isSelectionModeProvider.notifier).state = true;
  }


  /// Returns true if a move operation occurred (item left current view)
  Future<bool> handleDrop(String incomingKey, dynamic targetItem, String zone, List<dynamic> allItems) async {
    final currentId = ref.read(currentFolderProvider);
    
    // Parse Key: "folder_123" -> Type=Folder, ID=123
    final parts = incomingKey.split('_');
    final type = parts[0];
    final id = int.parse(parts[1]);
    
    // Find incoming object
    dynamic incomingObj;
    final matches = allItems.where((e) {
      if (type == 'folder') return e is Folder && e.id == id;
      return e is Note && e.id == id;
    });

    if (matches.isEmpty) return false;
    incomingObj = matches.first;

    if (zone == 'merge') {
      // MERGE LOGIC
      bool isSelf = false;
      if (incomingObj is Folder && targetItem is Folder) isSelf = incomingObj.id == targetItem.id;
      if (incomingObj is Note && targetItem is Note) isSelf = incomingObj.id == targetItem.id;
      
      if (isSelf) return false;

      if (targetItem is Folder) {
        // Move into Folder
        if (incomingObj is Note) {
          await _repo.moveNote(incomingObj.id, targetItem.id);
          return true; // Item moved out of current view
        } else if (incomingObj is Folder) {
          await _repo.moveFolder(incomingObj.id, targetItem.id);
          return true; // Item moved out of current view
        }
      } else if (targetItem is Note) {
        // File on File -> Create Group
        if (incomingObj is Note) {
          await _mergeItemsIntoFolder(incomingObj.id, targetItem);
          return true; // Both items moved into new folder
        }
      }
    }
    // REORDER or no action
    return false;
  }

  Future<void> handleReorder(List<dynamic> items) async {
    // Current list is already the desired order
    await _repo.reorderItems(items);
  }

  Future<void> _mergeItemsIntoFolder(int incomingNoteId, Note targetNote) async {
    final currentId = ref.read(currentFolderProvider);
    
    // Create folder
    final newFolderId = await _repo.createFolder(name: 'Group', parentId: currentId);
    
    // Move both items into folder
    await _repo.moveNote(incomingNoteId, newFolderId);
    await _repo.moveNote(targetNote.id, newFolderId);
    
    if (context.mounted) {
      _showToast('Group created!');
    }
  }

  Future<void> openFile(Note note) async {
    if (note.fileType == 'text' || note.fileType == 'rich_text') {
      final result = await Navigator.push(
        context,
        SlideUpPageRoute(
          page: EditorScreen(
            folderId: note.folderId,
            existingNote: note,
          ),
        ),
      );
      
      // Update cache if Note returned
      if (result is Note && context.mounted) {
        await _repo.updateNote(result);
      }
    } else if (note.imagePath != null) {
      final result = await OpenFilex.open(note.imagePath!);
      if (result.type != ResultType.done && context.mounted) {
        _showToast('Could not open file: ${result.message}');
      }
    }
  }

  Future<void> importFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final name = result.files.single.name;
      
      String type = 'other';
      final mimeType = lookupMimeType(path);
      if (mimeType != null) {
        if (mimeType.startsWith('image/')) type = 'image';
        else if (mimeType == 'application/pdf') type = 'pdf';
      }

      final currentId = ref.read(currentFolderProvider);
      
      await _repo.createNote(
        title: name,
        content: '',
        imagePath: path,
        fileType: type,
        folderId: currentId,
      );
    }
  }

  void navigateUp(int currentId) async {
    final folder = _repo.findFolder(currentId);
    if (folder != null) {
      ref.read(currentFolderProvider.notifier).state = folder.parentId;
    } else {
      ref.read(currentFolderProvider.notifier).state = null;
    }
  }

  Future<void> showCreateFolderDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Folder Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(dialogContext);
                final currentId = ref.read(currentFolderProvider);
                await _repo.createFolder(name: name, parentId: currentId);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> deleteItem(dynamic item) async {
    final selected = ref.read(selectedItemsProvider);
    final String targetKey = (item is Folder) ? "folder_${item.id}" : "note_${item.id}";
    final bool isMultiSelect = ref.read(isSelectionModeProvider) && selected.contains(targetKey);
    
    final filter = ref.read(activeFilterProvider);
    final bool isTrash = filter == DashboardFilter.trash;

    if (isMultiSelect) {
       // MULTI-DELETE
       final count = selected.length;
       final String title = isTrash 
          ? 'Permanently Delete $count items?' 
          : 'Move $count items to Trash?';
       final String content = isTrash
          ? 'These actions cannot be undone.'
          : 'Items will be moved to Trash.';
          
       final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(isTrash ? 'Delete Forever' : 'Trash'),
            ),
          ],
        ),
      );
      
      if (confirm == true) {
        for (var key in selected) {
          final parts = key.split('_');
          final String type = parts[0]; // folder or note
          final int id = int.parse(parts[1]);
          
          if (type == 'folder') {
             await _repo.deleteFolder(id, permanent: isTrash);
          } else {
             await _repo.deleteNote(id, permanent: isTrash);
          }
        }
        clearSelection();
      }

    } else {
      // SINGLE DELETE
      final bool isFolder = item is Folder;
      final String title = isTrash
          ? (isFolder ? 'Permanently Delete Folder?' : 'Permanently Delete Note?')
          : (isFolder ? 'Move to Trash?' : 'Move to Trash?');
          
      final String content = isTrash
          ? 'This will permanently delete the item. This action cannot be undone.'
          : 'Item will be moved to Trash.';

      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(isTrash ? 'Delete Forever' : 'Trash'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        if (isFolder) {
          await _repo.deleteFolder(item.id, permanent: isTrash);
        } else {
          await _repo.deleteNote(item.id, permanent: isTrash);
        }
      }
    }
  }

  Future<void> archiveItem(dynamic item, bool archive) async {
    final selected = ref.read(selectedItemsProvider);
    final String targetKey = (item is Folder) ? "folder_${item.id}" : "note_${item.id}";
    final bool isMultiSelect = ref.read(isSelectionModeProvider) && selected.contains(targetKey);

    if (isMultiSelect) {
       int successCount = 0;
       for (var key in selected) {
          final parts = key.split('_');
          final String type = parts[0];
          final int id = int.parse(parts[1]);
          
          dynamic itemToArchive;
          if (type == 'folder') {
             itemToArchive = _repo.findFolder(id);
          } else {
             itemToArchive = _repo.findNote(id);
          }
          
          if (itemToArchive != null) {
             await _repo.archiveItem(itemToArchive, archive);
             successCount++;
          }
       }
       clearSelection();
       
       if (context.mounted && successCount > 0) {
        _showToast(archive ? 'Archived $successCount items' : 'Unarchived $successCount items');
       }
    } else {
      await _repo.archiveItem(item, archive);
      
      if (context.mounted) {
        _showToast(
          archive ? 'Archived' : 'Unarchived',
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _repo.archiveItem(item, !archive);
            },
          ),
        );
      }
    }
  }

  Future<void> restoreItem(dynamic item) async {
    await _repo.restoreItem(item);
    
    if (context.mounted) {
      _showToast('Restored');
    }
  }

  bool isFolder(dynamic item) => item is Folder;

  Future<void> moveItemToParent(String incomingKey) async {
    final currentFolderId = ref.read(currentFolderProvider);
    if (currentFolderId == null) return;
    
    final currentFolder = _repo.findFolder(currentFolderId);
    final targetParentId = currentFolder?.parentId;

    final parts = incomingKey.split('_');
    final type = parts[0];
    final id = int.parse(parts[1]);

    if (type == 'folder') {
      await _repo.moveFolder(id, targetParentId);
    } else {
      await _repo.moveNote(id, targetParentId);
    }
    
    // Signal immediate removal from grid
    ref.read(pendingRemovalKeysProvider.notifier).state = {incomingKey};
    
    if (context.mounted) {
      _showToast('Moved to parent folder');
    }
  }
}
