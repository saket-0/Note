import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:mime/mime.dart';
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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    
                    if (item is Folder) {
                      return DragTarget<int>(
                        onAccept: (noteId) {
                          _moveNoteToFolder(ref, noteId, item.id);
                        },
                        builder: (context, candidates, rejects) {
                          return GestureDetector(
                            onTap: () => ref.read(currentFolderProvider.notifier).state = item.id,
                            child: GlassContainer(
                              color: candidates.isNotEmpty 
                                  ? Colors.greenAccent.withOpacity(0.3) 
                                  : Colors.blueAccent.withOpacity(0.1),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.folder, color: Colors.blueAccent, size: 40),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.name, 
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    } else if (item is Note) {
                      // Draggable File Item
                      return LongPressDraggable<int>(
                        data: item.id,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Opacity(
                            opacity: 0.7,
                            child: _buildFileItem(context, ref, item, isFeedback: true),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _buildFileItem(context, ref, item),
                        ),
                        child: _buildFileItem(context, ref, item),
                      );
                    }
                    return const SizedBox.shrink();
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
            backgroundColor: Colors.purpleAccent,
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
            backgroundColor: Colors.orangeAccent,
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

  Widget _buildFileItem(BuildContext context, WidgetRef ref, Note note, {bool isFeedback = false}) {
    IconData icon;
    Color color;

    switch (note.fileType) {
      case 'image':
        icon = Icons.image;
        color = Colors.purpleAccent;
        break;
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.redAccent;
        break;
      case 'text':
        icon = Icons.description;
        color = Colors.orangeAccent;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return GestureDetector(
      onTap: () => _openFile(context, ref, note),
      child: GlassContainer(
        width: isFeedback ? 150 : null, // Fixed width for feedback
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              note.title, 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
