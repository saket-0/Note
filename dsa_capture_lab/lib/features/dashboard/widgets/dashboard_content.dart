import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../shared/domain/entities/entities.dart';
import '../controllers/dashboard_controller.dart';
import '../providers/dashboard_state.dart';
import 'dashboard_grid_item.dart';

class DashboardContent extends ConsumerWidget {
  final DashboardFilter currentFilter;
  final DashboardController controller;
  final ViewMode viewMode;

  const DashboardContent({
    super.key,
    required this.currentFilter,
    required this.controller,
    required this.viewMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current folder ID
    final currentFolderId = ref.watch(currentFolderProvider);
    
    // CRITICAL: Fetch items directly from provider to ensure fresh data on every rebuild
    // Previously items were passed as props which could become stale
    final List<dynamic> items;
    if (currentFilter == DashboardFilter.active) {
      items = ref.watch(activeContentProvider(currentFolderId));
    } else if (currentFilter == DashboardFilter.archived) {
      items = ref.watch(archivedContentProvider);
    } else {
      items = ref.watch(trashContentProvider);
    }
    
    if (items.isEmpty) {
      return _buildEmptyState();
    }
    
    // Use PageStorageKey/ValueKey based on CONTEXT (Folder/Filter), not CONTENT.
    // This ensures scroll position is preserved when items are added/removed/modified.
    // Including viewMode ensures we reset if switching list<->grid.
    // Including items.length helps force grid rebuild when content changes.
    final String storageKey = "${currentFilter}_${currentFolderId ?? 'root'}_${viewMode}_${items.length}";

    if (viewMode == ViewMode.list) {
      return ListView.separated(
        key: PageStorageKey('list_$storageKey'),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildItem(context, ref, index, items),
      );
    }
    
    return MasonryGridView.count(
      key: PageStorageKey('grid_$storageKey'),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: items.length,
      itemBuilder: (context, index) => _buildItem(context, ref, index, items),
    );
  }

  Widget _buildEmptyState() {
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

  Widget _buildItem(BuildContext context, WidgetRef ref, int index, List<dynamic> items) {
    final item = items[index];
    final String itemKey = (item is Folder) ? "folder_${item.id}" : "note_${item.id}";
    
    return DashboardGridItem(
      key: ValueKey(itemKey), 
      item: item,
      allItems: items,
      onDrop: (incomingKey, zone) => controller.handleDrop(incomingKey, item, zone, items),
      onTap: () {
         if (item is Folder) {
           // Allow navigation in all modes (Active, Archive, Trash)
           ref.read(currentFolderProvider.notifier).state = item.id;
         } else if (item is Note) {
           controller.openFile(item);
         }
      },
      onDelete: () => controller.deleteItem(item),
      onArchive: (archive) => controller.archiveItem(item, archive),
      onRestore: () => controller.restoreItem(item),
    );
  }
}
