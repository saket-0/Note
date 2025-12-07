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
    final currentFilter = ref.watch(activeFilterProvider);
    
    // MEMORY-FIRST: Synchronous reads - NO LOADING STATE!
    final List<dynamic> items;
    if (currentFilter == DashboardFilter.active) {
       items = ref.watch(activeContentProvider(currentFolderId));
    } else if (currentFilter == DashboardFilter.archived) {
       items = ref.watch(archivedContentProvider);
    } else {
       items = ref.watch(trashContentProvider);
    }
    
    // Only load folder info if we are active and deep (or if we want breadcrumbs later)
    final AsyncValue<Folder?> folderInfo = currentFolderId == null
        ? const AsyncValue.data(null)
        : ref.watch(folderDetailsProvider(currentFolderId));

    // Instantiate Controller
    final controller = DashboardController(context, ref);
    
    // Determine if we are at "Root" context (Active & No Folder) to show Drawer vs Back
    // Actually, "Archived" and "Trash" are global lists, so they act like Roots.
    final bool isRoot = currentFolderId == null || currentFilter != DashboardFilter.active;

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: Drawer(
        child: Container(
          color: Colors.grey[900], // Match dark theme vibe
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.teal),
                child: Text('Notes App', style: TextStyle(color: Colors.white, fontSize: 24)),
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline, color: Colors.white),
                title: const Text('Notes', style: TextStyle(color: Colors.white)),
                selected: currentFilter == DashboardFilter.active,
                selectedTileColor: Colors.teal.withOpacity(0.2),
                onTap: () {
                   ref.read(activeFilterProvider.notifier).state = DashboardFilter.active;
                   ref.read(currentFolderProvider.notifier).state = null; // Reset to root
                   Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined, color: Colors.white),
                title: const Text('Archive', style: TextStyle(color: Colors.white)),
                selected: currentFilter == DashboardFilter.archived,
                selectedTileColor: Colors.teal.withOpacity(0.2),
                onTap: () {
                   ref.read(activeFilterProvider.notifier).state = DashboardFilter.archived;
                   Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.white),
                title: const Text('Trash', style: TextStyle(color: Colors.white)),
                selected: currentFilter == DashboardFilter.trash,
                selectedTileColor: Colors.teal.withOpacity(0.2),
                onTap: () {
                   ref.read(activeFilterProvider.notifier).state = DashboardFilter.trash;
                   Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const TextField(
             decoration: InputDecoration(
               hintText: "Search your notes",
               hintStyle: TextStyle(color: Colors.white54),
               border: InputBorder.none,
               prefixIcon: Icon(Icons.search, color: Colors.white54),
               contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), 
             ),
             style: TextStyle(color: Colors.white),
             cursorColor: Colors.tealAccent,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Leading: Drawer Icon if Root, Back Icon if Deep
        leading: isRoot 
            ? Builder(builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ))
            : DragTarget<String>(
                onAccept: (key) => controller.moveItemToParent(key),
                builder: (context, candidates, rejects) {
                  final isHovering = candidates.isNotEmpty;
                  return IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: isHovering ? Colors.tealAccent : Colors.white, 
                      size: isHovering ? 30 : 24,
                    ),
                    onPressed: () => controller.navigateUp(currentFolderId!),
                  );
                },
              ),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildContent(items, currentFilter, controller, currentFolderId),
          ),
        ),
      ),
      floatingActionButton: (currentFilter == DashboardFilter.active) ? Column(
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
              // Trigger cache rebuild
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
              // Trigger cache rebuild
              ref.read(refreshTriggerProvider.notifier).state++;
            },
            child: const Icon(Icons.edit, color: Colors.white),
          ),
        ],
      ) : null,
    );
  }
  
  Widget _buildContent(List<dynamic> items, DashboardFilter currentFilter, DashboardController controller, int? currentFolderId) {
    if (items.isEmpty) {
      String emptyMsg = "Empty Folder.\nAdd something!";
      if (currentFilter == DashboardFilter.archived) emptyMsg = "No archived items";
      if (currentFilter == DashboardFilter.trash) emptyMsg = "Trash is empty";
      
      return Center(
        child: Text(
          emptyMsg, 
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
      );
    }
    
    final String gridKey = items.map((e) => "${e.runtimeType}_${e.id}").join('_');
    
    return MasonryGridView.count(
      key: ValueKey(gridKey),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final String itemKey = (item is Folder) ? "folder_${item.id}" : "note_${item.id}";
        
        return DashboardGridItem(
          key: ValueKey(itemKey), 
          item: item,
          allItems: items,
          onDrop: (incomingKey, zone) => controller.handleDrop(incomingKey, item, zone, items),
          onTap: () {
             if (item is Folder) {
               if (currentFilter == DashboardFilter.active) {
                 ref.read(currentFolderProvider.notifier).state = item.id;
               }
             } else if (item is Note) {
               controller.openFile(item);
             }
          },
          onDelete: () => controller.deleteItem(item),
          onArchive: (archive) => controller.archiveItem(item, archive),
          onRestore: () => controller.restoreItem(item),
        );
      },
    );
  }
}

