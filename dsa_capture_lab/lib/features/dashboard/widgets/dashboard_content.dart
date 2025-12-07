import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../core/database/app_database.dart';
import '../controllers/dashboard_controller.dart';
import '../providers/dashboard_state.dart';
import 'dashboard_grid_item.dart';

class DashboardContent extends ConsumerWidget {
  final List<dynamic> items;
  final DashboardFilter currentFilter;
  final DashboardController controller;
  final ViewMode viewMode;

  const DashboardContent({
    super.key,
    required this.items,
    required this.currentFilter,
    required this.controller,
    required this.viewMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return _buildEmptyState();
    }
    
    final String gridKey = items.map((e) => "${e.runtimeType}_${e.id}").join('_');
    
    if (viewMode == ViewMode.list) {
      return ListView.separated(
        key: ValueKey('list_$gridKey'),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildItem(context, ref, index),
      );
    }
    
    return MasonryGridView.count(
      key: ValueKey(gridKey),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: items.length,
      itemBuilder: (context, index) => _buildItem(context, ref, index),
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

  Widget _buildItem(BuildContext context, WidgetRef ref, int index) {
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
  }
}
