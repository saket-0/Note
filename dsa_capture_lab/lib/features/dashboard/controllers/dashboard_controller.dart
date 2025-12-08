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

class DashboardController {
  final WidgetRef ref;
  final BuildContext context;

  DashboardController(this.context, this.ref);

  DataRepository get _repo => ref.read(dataRepositoryProvider);

  Future<void> handleDrop(String incomingKey, dynamic targetItem, String zone, List<dynamic> allItems) async {
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

    if (matches.isEmpty) return;
    incomingObj = matches.first;

    if (zone == 'merge') {
      // MERGE LOGIC
      bool isSelf = false;
      if (incomingObj is Folder && targetItem is Folder) isSelf = incomingObj.id == targetItem.id;
      if (incomingObj is Note && targetItem is Note) isSelf = incomingObj.id == targetItem.id;
      
      if (isSelf) return;

      if (targetItem is Folder) {
        // Move into Folder
        if (incomingObj is Note) {
          await _repo.moveNote(incomingObj.id, targetItem.id);
        } else if (incomingObj is Folder) {
          await _repo.moveFolder(incomingObj.id, targetItem.id);
        }
      } else if (targetItem is Note) {
        // File on File -> Create Group
        if (incomingObj is Note) {
          await _mergeItemsIntoFolder(incomingObj.id, targetItem);
        }
      }
    } else {
      // REORDER
      // If we are using Local State Reordering (Keep Style), the "allItems" passed here 
      // might already be the reordered list if we update it optimistically?
      // Actually, if we use OnDragEnd to commit, we don't need to do anything here for reordering
      // because the list is already reordered in the UI, we just need to save it.
      
      // However, if DragTarget 'onAccept' is triggered, it means we dropped ON something.
      // For Keep style, we drop "in the hole".
      // We rely on 'onDragEnd' in DashboardContent to commit the final state of the list.
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group created!')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${result.message}')),
        );
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
    final bool isFolder = item is Folder;
    final filter = ref.read(activeFilterProvider);
    final bool isTrash = filter == DashboardFilter.trash;

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

  Future<void> archiveItem(dynamic item, bool archive) async {
    await _repo.archiveItem(item, archive);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(archive ? 'Archived' : 'Unarchived'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _repo.archiveItem(item, !archive);
            },
          ),
        ),
      );
    }
  }

  Future<void> restoreItem(dynamic item) async {
    await _repo.restoreItem(item);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restored')),
      );
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
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moved to parent folder')),
      );
    }
  }
}
