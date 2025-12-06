import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:mime/mime.dart';
import '../../../core/database/app_database.dart';
import '../../camera/camera_screen.dart';
import '../../editor/editor_screen.dart';
import '../providers/dashboard_state.dart';

class DashboardController {
  final WidgetRef ref;
  final BuildContext context;

  DashboardController(this.context, this.ref);

  Future<void> handleDrop(String incomingKey, dynamic targetItem, String zone, List<dynamic> allItems) async {
    final db = ref.read(dbProvider);
    
    // Parse Key: "folder_123" -> Type=Folder, ID=123
    final parts = incomingKey.split('_');
    final type = parts[0];
    final id = int.parse(parts[1]);
    
    // Find Strategy
    dynamic incomingObj;
    final matches = allItems.where((e) {
      if (type == 'folder') return e is Folder && e.id == id;
      return e is Note && e.id == id;
    });

    if (matches.isEmpty) return;
    incomingObj = matches.first;

    if (incomingObj == null) return;

    print("DEBUG: handleDrop zone=$zone incoming=$incomingKey target=${targetItem.runtimeType}(${targetItem.id})");

    if (zone == 'merge') {
      // MERGE LOGIC
      // Check ID equality manually to be safe across instances
      bool isSelf = false;
      if (incomingObj is Folder && targetItem is Folder) isSelf = incomingObj.id == targetItem.id;
      if (incomingObj is Note && targetItem is Note) isSelf = incomingObj.id == targetItem.id;
      
      if (isSelf) {
        print("DEBUG: Dropped on self (merge)");
        return; 
      }

      if (targetItem is Folder) {
        print("DEBUG: Target is Folder");
        // Move into Folder
        if (incomingObj is Note) {
           print("DEBUG: Moving Note to Folder");
           await db.moveNote(incomingObj.id, targetItem.id);
        } else if (incomingObj is Folder) {
           // Move folder into folder
        }
      } else if (targetItem is Note) {
        print("DEBUG: Target is Note");
        // File on File -> Group
        if (incomingObj is Note) {
          print("DEBUG: Merging Note into Note -> Group");
          await _mergeItemsIntoFolder(incomingObj.id, targetItem);
        } else {
           print("DEBUG: Incoming is not Note (it is ${incomingObj.runtimeType})");
        }
      }
    } else {
      // REORDER LOGIC
      int oldIndex = allItems.indexOf(incomingObj);
      int newIndex = allItems.indexOf(targetItem);
      if (oldIndex == -1 || newIndex == -1) return; // safety
      
      if (zone == 'right') newIndex++; 

      final sortedList = List.from(allItems);
      sortedList.removeAt(oldIndex);
      
      if (newIndex > oldIndex) newIndex--; 
      
      if (newIndex < 0) newIndex = 0;
      if (newIndex > sortedList.length) newIndex = sortedList.length;
      
      sortedList.insert(newIndex, incomingObj);
      
      // Update DB
      for (int i = 0; i < sortedList.length; i++) {
        final obj = sortedList[i];
        if (obj is Folder) {
          await db.updateFolderPosition(obj.id, i);
        } else if (obj is Note) {
          await db.updateNotePosition(obj.id, i);
        }
      }
    }
    
    ref.read(refreshTriggerProvider.notifier).state++;
  }

  Future<void> _mergeItemsIntoFolder(int incomingNoteId, Note targetNote) async {
    // 1. Create a new folder named "Group"
    final db = ref.read(dbProvider);
    final currentId = ref.read(currentFolderProvider);
    final newFolderId = await db.createFolder("Group", currentId);

    // 2. Move BOTH items into the new folder
    await db.moveNote(incomingNoteId, newFolderId); // dragged item
    await db.moveNote(targetNote.id, newFolderId);  // target item
    
    // 3. Refresh UI
    ref.read(refreshTriggerProvider.notifier).state++;
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Group created!")),
      );
    }
  }

  Future<void> openFile(Note note) async {
    if (note.fileType == 'text') {
      // Open Editor
      await Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (_) => EditorScreen(
            folderId: note.folderId,
            existingNote: note,
          )
        )
      );
      ref.read(refreshTriggerProvider.notifier).state++;
    } else if (note.imagePath != null) {
      // Open External File WITH OPEN_FILEX
       final result = await OpenFilex.open(note.imagePath!);
       if (result.type != ResultType.done) {
         if(context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not open file: ${result.message}")));
         }
       }
    }
  }

  Future<void> importFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final name = result.files.single.name;
      
      // Determine type
      String type = 'other';
      final mimeType = lookupMimeType(path);
      if (mimeType != null) {
        if (mimeType.startsWith('image/')) type = 'image';
        else if (mimeType == 'application/pdf') type = 'pdf';
      }

      final db = ref.read(dbProvider);
      final currentId = ref.read(currentFolderProvider);
      
      await db.createNote(
        title: name,
        content: '',
        imagePath: path, // Storing file path here
        fileType: type,
        folderId: currentId
      );
      ref.read(refreshTriggerProvider.notifier).state++;
    }
  }

  void navigateUp(int currentId) async {
    final db = ref.read(dbProvider);
    final currentFolder = await db.getFolder(currentId);
    if (currentFolder != null) {
        ref.read(currentFolderProvider.notifier).state = currentFolder.parentId;
    } else {
        ref.read(currentFolderProvider.notifier).state = null;
    }
  }

  Future<void> showCreateFolderDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Folder"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Folder Name"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final db = ref.read(dbProvider);
                final currentId = ref.read(currentFolderProvider);
                await db.createFolder(name, currentId);
                ref.read(refreshTriggerProvider.notifier).state++; // Trigger refresh
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }
  Future<void> deleteItem(dynamic item) async {
    final bool isFolder = item is Folder;
    final String title = isFolder ? "Delete Folder?" : "Delete Note?";
    final String content = isFolder 
        ? "This will delete the folder '${item.name}' and all its contents.\nThis action cannot be undone." 
        : "Are you sure you want to delete '${item.title}'?";

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text("Cancel")
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = ref.read(dbProvider);
      if (isFolder) {
        await db.deleteFolder(item.id);
      } else if (item is Note) {
        await db.deleteNote(item.id);
      }
      ref.read(refreshTriggerProvider.notifier).state++;
    }
  }
}
