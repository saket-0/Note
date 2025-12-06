import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../core/database/app_database.dart';
import '../../core/ui/gradient_background.dart';
import '../camera/camera_screen.dart';
import '../editor/editor_screen.dart';
import 'controllers/dashboard_controller.dart';
import 'providers/dashboard_state.dart';
import 'widgets/dashboard_grid_item.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  
  @override
  Widget build(BuildContext context) {
    final currentFolderId = ref.watch(currentFolderProvider);
    final folderInfo = ref.watch(currentFolderObjProvider);
    final contentAsync = ref.watch(contentProvider);

    // Instantiate Controller
    final controller = DashboardController(context, ref);

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
                onPressed: () => controller.navigateUp(currentFolderId),
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
                      key: ValueKey(item.id), // Important for stability
                      item: item,
                      allItems: items,
                      onDrop: (incomingKey, zone) => controller.handleDrop(incomingKey, item, zone, items),
                      onTap: () {
                         if (item is Folder) {
                           ref.read(currentFolderProvider.notifier).state = item.id;
                         } else if (item is Note) {
                           controller.openFile(item);
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
            onPressed: () => controller.importFile(),
            child: const Icon(Icons.file_upload, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.small(
            heroTag: "folder_btn",
            backgroundColor: Colors.blueGrey,
            onPressed: () => controller.showCreateFolderDialog(),
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
}
