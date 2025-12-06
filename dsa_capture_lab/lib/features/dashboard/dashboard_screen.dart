import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:mime/mime.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../core/database/app_database.dart';
import '../../core/ui/gradient_background.dart';
import '../../core/ui/glass_container.dart';
import '../camera/camera_screen.dart';
import '../editor/editor_screen.dart';

// Tracks the current folder ID (null = root)
final currentFolderProvider = StateProvider<int?>((ref) => null);

// Trigger to force refresh
final refreshTriggerProvider = StateProvider<int>((ref) => 0);

// Unified Content Provider (Folders + Files)
final contentProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final db = ref.watch(dbProvider);
  final currentFolderId = ref.watch(currentFolderProvider);
  ref.watch(refreshTriggerProvider); // Watch trigger
  
  // Fetch both
  final folders = await db.getFolders(currentFolderId);
  final notes = await db.getNotes(currentFolderId);
  
  // Combine (Folders first, then Files)
  return [...folders, ...notes];
});

final currentFolderObjProvider = FutureProvider.autoDispose<Folder?>((ref) async {
  final db = ref.watch(dbProvider);
  final id = ref.watch(currentFolderProvider);
  if (id == null) return null;
  return await db.getFolder(id);
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Map to track hover state per item: 'merge', 'left', 'right', or null
  // We don't actually need this in parent if GridItem handles it?
  // Actually we rely on GridItem to tell us when to rebuild parent or just logic helper.
  // The GridItem handles its own hover state for visual feedback.
  // The Parent handles the DROP logic.

  @override
  Widget build(BuildContext context) {
    final currentFolderId = ref.watch(currentFolderProvider);
    final folderInfo = ref.watch(currentFolderObjProvider);
    final contentAsync = ref.watch(contentProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: folderInfo.when(
          data: (f) => Text(f?.name ?? "My Knowledge Base"),
          loading: () => const Text("Loading..."),
          error: (_, __) => const Text("Error"),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: currentFolderId != null 
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () {
                  _navigateUp(context, ref, currentFolderId);
                },
              )
            : null,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: contentAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      "Empty Folder.\nAdd something!", 
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  );
                }
                
                // MASONRY GRID (Keep Style)
                return MasonryGridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return DashboardGridItem(
                      key: ValueKey(item.id),
                      item: item,
                      allItems: items,
                      onDrop: (incomingKey, zone) => _handleDrop(ref, incomingKey, item, zone, items),
                      onTap: () {
                         if (item is Folder) {
                           ref.read(currentFolderProvider.notifier).state = item.id;
                         } else if (item is Note) {
                           _openFile(context, ref, item);
                         }
                      },
                    );
                  },
                );
              },
              error: (e, s) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.red))),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
           FloatingActionButton.small(
            heroTag: "import_btn",
            backgroundColor: Colors.teal,
            onPressed: () => _importFile(context, ref),
            child: const Icon(Icons.file_upload, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.small(
            heroTag: "folder_btn",
            backgroundColor: Colors.blueGrey,
            onPressed: () => _showCreateFolderDialog(context, ref),
            child: const Icon(Icons.create_new_folder, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "camera_btn",
            backgroundColor: Colors.deepPurple,
            onPressed: () async { 
               await Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => CameraScreen(folderId: currentFolderId))
              );
              ref.read(refreshTriggerProvider.notifier).state++;
            },
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "note_btn",
            backgroundColor: Colors.amber[800],
            onPressed: () async {
              await Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => EditorScreen(folderId: currentFolderId))
              );
              ref.read(refreshTriggerProvider.notifier).state++;
            },
            child: const Icon(Icons.edit, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDrop(WidgetRef ref, String incomingKey, dynamic targetItem, String zone, List<dynamic> allItems) async {
    final db = ref.read(dbProvider);
    
    // Parse Key: "folder_123" -> Type=Folder, ID=123
    final parts = incomingKey.split('_');
    final type = parts[0];
    final id = int.parse(parts[1]);
    
    // Find Strategy
    dynamic incomingObj;
    if (type == 'folder') {
      incomingObj = allItems.firstWhere((e) => e is Folder && e.id == id, orElse: () => null);
    } else {
      incomingObj = allItems.firstWhere((e) => e is Note && e.id == id, orElse: () => null);
    }

    if (incomingObj == null) return;

    if (zone == 'merge') {
      // MERGE LOGIC
      if (incomingObj == targetItem) return; // Drop on self

      if (targetItem is Folder) {
        // Move into Folder
        if (incomingObj is Note) {
           await db.moveNote(incomingObj.id, targetItem.id);
        } else if (incomingObj is Folder) {
           // Move folder into folder
        }
      } else if (targetItem is Note) {
        // File on File -> Group
        if (incomingObj is Note) {
          _mergeItemsIntoFolder(context, ref, incomingObj.id, targetItem);
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

  Future<void> _openFile(BuildContext context, WidgetRef ref, Note note) async {
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

  Future<void> _importFile(BuildContext context, WidgetRef ref) async {
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

  Future<void> _moveNoteToFolder(WidgetRef ref, int noteId, int targetFolderId) async {
    final db = ref.read(dbProvider);
    await db.moveNote(noteId, targetFolderId);
    ref.read(refreshTriggerProvider.notifier).state++;
  }

  Future<void> _mergeItemsIntoFolder(BuildContext context, WidgetRef ref, int incomingNoteId, Note targetNote) async {
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

  void _navigateUp(BuildContext context, WidgetRef ref, int currentId) async {
    final db = ref.read(dbProvider);
    final currentFolder = await db.getFolder(currentId);
    if (currentFolder != null) {
        ref.read(currentFolderProvider.notifier).state = currentFolder.parentId;
    } else {
        ref.read(currentFolderProvider.notifier).state = null;
    }
  }

  Future<void> _showCreateFolderDialog(BuildContext context, WidgetRef ref) async {
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
}

class DashboardGridItem extends StatefulWidget {
  final dynamic item;
  final List<dynamic> allItems;
  final Function(String key, String zone) onDrop;
  final VoidCallback onTap;

  const DashboardGridItem({
    super.key,
    required this.item,
    required this.allItems,
    required this.onDrop,
    required this.onTap,
  });

  @override
  State<DashboardGridItem> createState() => _DashboardGridItemState();
}

class _DashboardGridItemState extends State<DashboardGridItem> {
  String _hoverState = 'merge'; 

  @override
  Widget build(BuildContext context) {
    final int itemId = widget.item.id;
    final bool isFolder = widget.item is Folder;
    final String dragKey = isFolder ? "folder_$itemId" : "note_$itemId";

    return Stack(
      children: [
        Positioned.fill(
          child: DragTarget<String>(
            onMove: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final localPos = box.globalToLocal(details.offset);
              final width = box.size.width;
              
              String newState = 'merge';
              if (localPos.dx < width * 0.25) {
                newState = 'left';
              } else if (localPos.dx > width * 0.75) {
                newState = 'right';
              } else {
                newState = 'merge';
              }

              if (_hoverState != newState) {
                setState(() => _hoverState = newState);
              }
            },
            onLeave: (_) {},
            onAccept: (incomingKey) => widget.onDrop(incomingKey, _hoverState),
            builder: (context, candidates, rejects) {
              if (candidates.isEmpty) return const SizedBox.shrink();
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: _hoverState == 'merge' 
                      ? Border.all(color: Colors.tealAccent, width: 3) 
                      : null,
                ),
                child: Stack(
                  children: [
                     if (_hoverState == 'left')
                       Positioned(left: 0, top: 0, bottom: 0, width: 6, child: Container(
                         decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(3))
                       )),
                     if (_hoverState == 'right')
                       Positioned(right: 0, top: 0, bottom: 0, width: 6, child: Container(
                         decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(3))
                       )),
                  ],
                ),
              );
            },
          ),
        ),

        LongPressDraggable<String>(
          data: dragKey,
          delay: const Duration(milliseconds: 300),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.8,
              child: SizedBox(
                width: 140, 
                height: 140, // Feedback can be fixed size
                child: _buildContent(isFeedback: true),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _buildContent(), // Keep size consistent
          ),
          child: GestureDetector(
            onTap: widget.onTap,
            child: _buildContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildContent({bool isFeedback = false}) {
    final item = widget.item;
    
    // Determine Color
    Color bgColor = Colors.white.withOpacity(0.05); // Default Glass
    if (item is Note && item.color != 0) {
      bgColor = Color(item.color); // Opaque custom color
    } else if (item is Folder) {
      bgColor = Colors.blueAccent.withOpacity(0.1);
    }

    Widget contentBody;
    
    if (item is Folder) {
      contentBody = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, color: Colors.blueAccent, size: 40),
          const SizedBox(height: 8),
          Text(
            item.name, 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else { // Note
       if (item.fileType == 'image' && item.imagePath != null) {
          contentBody = ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.file(
              File(item.imagePath!),
              fit: BoxFit.cover, 
            ),
          );
       } else {
          // Text / Other
          IconData icon = Icons.insert_drive_file;
          Color accentColor = Colors.blueGrey;
          
           if (item.fileType == 'pdf') {
             icon = Icons.picture_as_pdf;
             accentColor = Colors.redAccent;
           } else if (item.fileType == 'text') {
             icon = Icons.description;
             accentColor = Colors.amber;
           }
           
           // Text Content Preview (Keep Style)
           String previewText = item.content.trim();
           if (previewText.isEmpty) previewText = "No content";

           contentBody = Padding(
             padding: const EdgeInsets.all(12.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               mainAxisSize: MainAxisSize.min, // Wrap content
               children: [
                 if (item.imagePath == null) ...[
                    // Title
                    Text(
                      item.title,
                      style: TextStyle(
                        color: (item.color != 0) ? Colors.black87 : Colors.white, 
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Content snippet
                    Text(
                      previewText,
                      style: TextStyle(
                         color: (item.color != 0) ? Colors.black54 : Colors.white70,
                         fontSize: 14,
                      ),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                 ] 
               ],
             ),
           );
       }
    }
    
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(15),
            // Glass border if no color
            border: (item is Note && item.color != 0) ? null : Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: contentBody,
        ),
        
        // PIN INDICATOR
        if (item is Note && item.isPinned)
          Positioned(
            top: 8,
            right: 8,
            child: Icon(
              Icons.push_pin, 
              size: 16, 
              color: (item.color != 0) ? Colors.black54 : Colors.white70
            ),
          )
      ],
    );
  }
}
