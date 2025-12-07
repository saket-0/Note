import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:mime/mime.dart';
import '../../../core/database/app_database.dart';
import '../../../core/cache/cache_service.dart';
import '../../../core/ui/page_routes.dart';
import '../../camera/camera_screen.dart';
import '../../editor/editor_screen.dart';
import '../providers/dashboard_state.dart';

class DashboardController {
  final WidgetRef ref;
  final BuildContext context;

  DashboardController(this.context, this.ref);

  Future<void> handleDrop(String incomingKey, dynamic targetItem, String zone, List<dynamic> allItems) async {
    final db = ref.read(dbProvider);
    final cache = ref.read(cacheServiceProvider);
    final currentId = ref.read(currentFolderProvider);
    
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
      bool isSelf = false;
      if (incomingObj is Folder && targetItem is Folder) isSelf = incomingObj.id == targetItem.id;
      if (incomingObj is Note && targetItem is Note) isSelf = incomingObj.id == targetItem.id;
      
      if (isSelf) return; 

      if (targetItem is Folder) {
        // Move into Folder: Update cache + DB
        if (incomingObj is Note) {
           cache.removeNote(incomingObj.id);
           cache.addNote(incomingObj.copyWith(folderId: targetItem.id));
           await db.moveNote(incomingObj.id, targetItem.id);
        } else if (incomingObj is Folder) {
           cache.removeFolder(incomingObj.id);
           cache.addFolder(incomingObj.copyWith(parentId: targetItem.id));
           await db.database.then((d) => d.update(
             'folders', 
             {'parent_id': targetItem.id}, 
             where: 'id = ?', 
             whereArgs: [incomingObj.id]
           ));
        }
      } else if (targetItem is Note) {
        // File on File -> Group
        if (incomingObj is Note) {
          await _mergeItemsIntoFolder(incomingObj.id, targetItem);
          return; // _merge handles refresh
        }
      }
      ref.read(refreshTriggerProvider.notifier).state++;
    } else {
      // REORDER: Just update DB, cache doesn't track position granularly yet
      int oldIndex = allItems.indexOf(incomingObj);
      int newIndex = allItems.indexOf(targetItem);
      if (oldIndex == -1 || newIndex == -1) return; 
      
      if (zone == 'right') newIndex++; 
      if (newIndex > oldIndex) newIndex--; 
      if (newIndex < 0) newIndex = 0;
      if (newIndex > allItems.length - 1) newIndex = allItems.length - 1;
      
      // Update DB positions in background
      for (int i = 0; i < allItems.length; i++) {
        final obj = allItems[i];
        if (obj is Folder) {
          await db.updateFolderPosition(obj.id, i);
        } else if (obj is Note) {
          await db.updateNotePosition(obj.id, i);
        }
      }
      ref.read(refreshTriggerProvider.notifier).state++;
    }
  }

  Future<void> _mergeItemsIntoFolder(int incomingNoteId, Note targetNote) async {
    final db = ref.read(dbProvider);
    final cache = ref.read(cacheServiceProvider);
    final currentId = ref.read(currentFolderProvider);
    
    // 1. Create folder
    final newFolderId = await db.createFolder("Group", currentId);
    final newFolder = Folder(id: newFolderId, name: "Group", parentId: currentId, createdAt: DateTime.now());
    cache.addFolder(newFolder);

    // 2. Move BOTH items into the new folder
    cache.removeNote(incomingNoteId);
    cache.removeNote(targetNote.id);
    await db.moveNote(incomingNoteId, newFolderId);
    await db.moveNote(targetNote.id, newFolderId);
    
    // 3. Refresh UI
    ref.read(refreshTriggerProvider.notifier).state++;
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Group created!")),
      );
    }
  }

  Future<void> openFile(Note note) async {
    if (note.fileType == 'text' || note.fileType == 'rich_text') {
      // Open Editor
      final result = await Navigator.push(
        context, 
        SlideUpPageRoute(
          page: EditorScreen(
            folderId: note.folderId,
            existingNote: note,
          ),
        ),
      );
      
      // OPTIMISTIC UPDATE: Update cache if Note returned
      if (result is Note && context.mounted) {
         final cache = ref.read(cacheServiceProvider);
         cache.updateNote(result);
         ref.read(refreshTriggerProvider.notifier).state++;
      }
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
      final cache = ref.read(cacheServiceProvider);
      final currentId = ref.read(currentFolderProvider);
      
      final newId = await db.createNote(
        title: name,
        content: '',
        imagePath: path,
        fileType: type,
        folderId: currentId
      );
      
      // Update cache
      final newNote = Note(id: newId, title: name, content: '', imagePath: path, fileType: type, folderId: currentId, createdAt: DateTime.now());
      cache.addNote(newNote);
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
                final cache = ref.read(cacheServiceProvider);
                final currentId = ref.read(currentFolderProvider);

                // 1. Persist to DB first to get ID
                final newId = await db.createFolder(name, currentId);
                
                // 2. Create Folder object
                final newFolder = Folder(
                  id: newId, 
                  name: name, 
                  parentId: currentId, 
                  createdAt: DateTime.now()
                );
                
                // 3. Update Cache & Trigger Refresh
                cache.addFolder(newFolder);
                ref.read(refreshTriggerProvider.notifier).state++;
                
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
    final filter = ref.read(activeFilterProvider);
    final bool isTrash = filter == DashboardFilter.trash;

    final String title = isTrash 
        ? (isFolder ? "Permanently Delete Folder?" : "Permanently Delete Note?") 
        : (isFolder ? "Move to Trash?" : "Move to Trash?");
        
    final String content = isTrash
        ? "This will permanently delete the item. This action cannot be undone."
        : "Item will be moved to Trash.";

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
            child: Text(isTrash ? "Delete Forever" : "Trash"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = ref.read(dbProvider);
      final cache = ref.read(cacheServiceProvider);
      
      // CACHE-FIRST UPDATES
      if (isTrash) {
        // Permanent Delete
        cache.permanentlyDelete(item);
        
        if (isFolder) {
          await db.deleteFolder(item.id, permanent: true);
        } else {
          await db.deleteNote(item.id, permanent: true);
        }
      } else {
        // Soft Delete: Move to Trash
        cache.moveToTrash(item);
        
        // DB Update
        if (isFolder) {
          await db.deleteFolder(item.id, permanent: false);
        } else {
          await db.deleteNote(item.id, permanent: false);
        }
      }
      
      // Trigger UI rebuild
      ref.read(refreshTriggerProvider.notifier).state++;
    }
  }

  Future<void> archiveItem(dynamic item, bool archive) async {
    final db = ref.read(dbProvider);
    final cache = ref.read(cacheServiceProvider);
    
    // Cache-first update
    if (archive) {
      cache.moveToArchive(item);
    } else {
      cache.restoreToActive(item);
    }
    
    // Trigger UI rebuild
    ref.read(refreshTriggerProvider.notifier).state++;
    
    // DB Update
    final type = item is Folder ? 'folder' : 'note';
    await db.archiveItem(item.id, type, archive);
    
    if (context.mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text(archive ? "Archived" : "Unarchived"), 
           action: SnackBarAction(label: "Undo", onPressed: () async {
              await archiveItem(item, !archive);
           })
         )
       );
    }
  }

  Future<void> restoreItem(dynamic item) async {
    final db = ref.read(dbProvider);
    final cache = ref.read(cacheServiceProvider);
    
    // Cache-first update
    cache.restoreToActive(item);
    
    // Trigger UI rebuild
    ref.read(refreshTriggerProvider.notifier).state++;

    final type = item is Folder ? 'folder' : 'note';
    await db.restoreItem(item.id, type);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Restored")));
    }
  }

  bool isFolder(dynamic item) => item is Folder;
  
  Future<void> moveItemToParent(String incomingKey) async {
    final db = ref.read(dbProvider);
    final cache = ref.read(cacheServiceProvider);
    final currentFolderId = ref.read(currentFolderProvider);
    
    // Check if we are actually inside a folder
    if (currentFolderId == null) return;
    
    // Get parent logic
    final currentFolderObj = await db.getFolder(currentFolderId);
    final targetParentId = currentFolderObj?.parentId;

    // Parse Key
    final parts = incomingKey.split('_');
    final type = parts[0];
    final id = int.parse(parts[1]);

    // Cache-first update
    if (type == 'folder') {
      final folder = await db.getFolder(id);
      if (folder != null) {
        cache.removeFolder(id);
        cache.addFolder(folder.copyWith(parentId: targetParentId));
      }
    } else {
      final note = await db.getNote(id);
      if (note != null) {
        cache.removeNote(id);
        cache.addNote(note.copyWith(folderId: targetParentId));
      }
    }
    
    // DB Update
    await db.database.then((d) => d.update(
      type == 'folder' ? 'folders' : 'notes', 
      { type == 'folder' ? 'parent_id' : 'folder_id': targetParentId },
      where: 'id = ?',
      whereArgs: [id]
    ));
    
    // Trigger UI rebuild
    ref.read(refreshTriggerProvider.notifier).state++;
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Moved to parent folder")),
      );
    }
  }
}
