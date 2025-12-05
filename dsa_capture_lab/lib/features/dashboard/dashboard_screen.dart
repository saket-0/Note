import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/ui/gradient_background.dart';
import '../../core/ui/glass_container.dart';
import '../camera/camera_screen.dart';
import '../editor/editor_screen.dart';

// Tracks the current folder ID (null = root)
final currentFolderProvider = StateProvider<int?>((ref) => null);

// Trigger to force refresh
final refreshTriggerProvider = StateProvider<int>((ref) => 0);

// Fetches subfolders for the current folder
final foldersProvider = FutureProvider.autoDispose<List<Folder>>((ref) async {
  final db = ref.watch(dbProvider);
  final currentFolderId = ref.watch(currentFolderProvider);
  ref.watch(refreshTriggerProvider); // Watch trigger
  
  return await db.getFolders(currentFolderId);
});

// Fetches notes for the current folder
final notesProvider = FutureProvider.autoDispose<List<Note>>((ref) async {
  final db = ref.watch(dbProvider);
  final currentFolderId = ref.watch(currentFolderProvider);
  ref.watch(refreshTriggerProvider); // Watch trigger

  return await db.getNotes(currentFolderId);
});

// Fetches the current folder object (for title/breadcrumbs)
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
    final foldersAsync = ref.watch(foldersProvider);
    final notesAsync = ref.watch(notesProvider);

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
            child: CustomScrollView(
              slivers: [
                // --- Folders Section ---
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text("FOLDERS", style: TextStyle(color: Colors.white70, letterSpacing: 1.2, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                foldersAsync.when(
                  data: (folders) => folders.isEmpty 
                      ? const SliverToBoxAdapter(child: SizedBox.shrink())
                      : SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.5,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final folder = folders[index];
                              return GestureDetector(
                                onTap: () => ref.read(currentFolderProvider.notifier).state = folder.id,
                                child: GlassContainer(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.folder, color: Colors.blueAccent, size: 40),
                                      const SizedBox(height: 8),
                                      Text(
                                        folder.name, 
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: folders.length,
                          ),
                        ),
                  error: (e, s) => SliverToBoxAdapter(child: Text("Error: $e", style: const TextStyle(color: Colors.red))),
                  loading: () => const SliverToBoxAdapter(child: CircularProgressIndicator()),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // --- Notes Section ---
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text("NOTES & SNAPS", style: TextStyle(color: Colors.white70, letterSpacing: 1.2, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                notesAsync.when(
                  data: (notes) => notes.isEmpty 
                      ? SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                "No notes here yet.\nTap + to add one!", 
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withOpacity(0.5)),
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final note = notes[index];
                              final isPhoto = note.imagePath != null;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: GlassContainer(
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: isPhoto ? Colors.purpleAccent.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isPhoto ? Icons.image : Icons.description, 
                                        color: isPhoto ? Colors.purpleAccent : Colors.orangeAccent,
                                      ),
                                    ),
                                    title: Text(note.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                      _formatDate(note.createdAt), 
                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                    ),
                                    onTap: () async {
                                      // Open Note for Editing/Viewing
                                      await Navigator.push(
                                        context, 
                                        MaterialPageRoute(
                                          builder: (_) => EditorScreen(
                                            folderId: currentFolderId,
                                            existingNote: note,
                                          )
                                        )
                                      );
                                      ref.read(refreshTriggerProvider.notifier).state++; // Refresh on return
                                    },
                                  ),
                                ),
                              );
                            },
                            childCount: notes.length,
                          ),
                        ),
                  error: (e, s) => SliverToBoxAdapter(child: Text("Error: $e", style: const TextStyle(color: Colors.red))),
                  loading: () => const SliverToBoxAdapter(child: CircularProgressIndicator()),
                ),
                
                // Add some bottom padding for FAB
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
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
            onPressed: () async { // Async to await result
               await Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => CameraScreen(folderId: currentFolderId))
              );
              ref.read(refreshTriggerProvider.notifier).state++; // Refresh
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
              ref.read(refreshTriggerProvider.notifier).state++; // Refresh
            },
            child: const Icon(Icons.edit, color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year}";
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
