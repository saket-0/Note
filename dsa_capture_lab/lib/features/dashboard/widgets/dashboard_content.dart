import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../shared/domain/entities/entities.dart';
import '../controllers/dashboard_controller.dart';
import '../providers/dashboard_state.dart';
import '../selection/selection.dart';
import 'dashboard_grid_item.dart';

class DashboardContent extends ConsumerStatefulWidget {
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
  ConsumerState<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<DashboardContent> {
  // Local state for optimistic reordering (The "Visual Order")
  List<dynamic> _localItems = [];
  bool _isDragging = false;
  String? _draggingId; // "note_123" or "folder_456"

  @override
  void didUpdateWidget(DashboardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
     // If filter changes, we must reset. 
     // We rely on build() to sync data, but if we are NOT dragging, we should sync.
  }

  @override
  Widget build(BuildContext context) {
    final currentFolderId = ref.watch(currentFolderProvider);
    
    // Fetch Source of Truth
    final List<dynamic> sourceItems;
    if (widget.currentFilter == DashboardFilter.active) {
      sourceItems = ref.watch(activeContentProvider(currentFolderId));
    } else if (widget.currentFilter == DashboardFilter.archived) {
      sourceItems = ref.watch(archivedContentProvider);
    } else {
      sourceItems = ref.watch(trashContentProvider);
    }
    
    // Sync Local State if NOT dragging
    // We check if lists are different length or different IDs to detect external updates
    if (!_isDragging) {
      _errorMessageIfMismatch(sourceItems);
      _localItems = List.from(sourceItems);
    }
    
    print("DEBUG: DashboardContent build. Filter=${widget.currentFilter}, Folder=$currentFolderId");
    print("DEBUG: sourceItems count: ${sourceItems.length}");
    print("DEBUG: _localItems count: ${_localItems.length}");
    
    if (_localItems.isEmpty) {
      print("DEBUG: _localItems is empty, showing Empty State");
      return _buildEmptyState();
    }
    
    // Key strategy: Use a key that changes when FILTER or FOLDER changes, 
    // but DOES NOT change when items are reordered (to preserve scroll/state).
    final String storageKey = "${widget.currentFilter}_${currentFolderId ?? 'root'}_${widget.viewMode}";

    if (widget.viewMode == ViewMode.list) {
      return ListView.separated(
        key: PageStorageKey('list_$storageKey'),
        itemCount: _localItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildItem(index, _localItems),
      );
    }
    
    return MasonryGridView.count(
      key: PageStorageKey('grid_$storageKey'),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: _localItems.length,
      itemBuilder: (context, index) => _buildItem(index, _localItems),
    );
  }

  void _errorMessageIfMismatch(List<dynamic> source) {
    // Optional: Check for drift? 
    // Usually standard assignment is fine.
  }

  Widget _buildEmptyState() {
    String emptyMsg = "Empty Folder.\nAdd something!";
    if (widget.currentFilter == DashboardFilter.archived) emptyMsg = "No archived items";
    if (widget.currentFilter == DashboardFilter.trash) emptyMsg = "Trash is empty";
    
    return Center(
      child: Text(
        emptyMsg, 
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildItem(int index, List<dynamic> items) {
    final item = items[index];
    final String itemKey = (item is Folder) ? "folder_${item.id}" : "note_${item.id}";
    // Opacity 0 for the item being dragged (to create the "Hole")
    bool isBeingDragged = _draggingId == itemKey;
    
    // Selection State (Using isolated selection module)
    final bool isSelected = ref.watch(isItemSelectedProvider(itemKey));
    final bool isSelectionMode = ref.watch(isSelectionModeProvider);

    return Opacity(
      // data sends "opacity: 0" but we prefer handling it in GridItem via "childWhenDragging"
      // But for staggered grid reorder, if we move the item index, the "hole" moves.
      // So if Note A is at Index 0 and we drag it to Index 5...
      // Index 0 becomes Note B. Note A is now at Index 5.
      // The "Ghost" is floating. The "Real Item" at Index 5 is Note A (invisible).
      opacity: 1.0, // DashboardGridItem handles the opacity during its own drag start
      child: DashboardGridItem(
        key: ValueKey(itemKey),
        item: item,
        allItems: items, // Pass local items so it knows neighbors
        isSelected: isSelected,
        isSelectionMode: isSelectionMode,
        onDragStart: () {
           if (isSelectionMode) {
              // drag-to-reorder while selecting?
              // keep it simple for now. 
           }
           setState(() {
             _isDragging = true;
             _draggingId = itemKey;
           });
        },
        onDragEnd: (details) {
           setState(() {
             _isDragging = false;
             _draggingId = null;
           });
           // Commit changes
           widget.controller.handleReorder(_localItems);
        },
        onHoverReorder: (incomingKey, hoverIndexStr) {
           // hoverIndexStr allows us to know WHERE we are hovering relative to this item?
           // Actually, simpler: The Item *itself* knows its index in `items`.
           // But `items` is passed in.
           
           // We need to find the indexes.
           // incomingKey = "note_123"
           // targetItem = item
           
           _handleLocalReorder(incomingKey, item);
        },
        onDrop: (incomingKey, zone) => widget.controller.handleDrop(incomingKey, item, zone, items),
        onTap: () {
           if (isSelectionMode) {
              // Use modular selection controller
              ref.read(selectionControllerProvider).toggleSelection(item);
           } else {
             if (item is Folder) {
               ref.read(currentFolderProvider.notifier).state = item.id;
             } else if (item is Note) {
               widget.controller.openFile(item);
             }
           }
        },
        onLongPress: () {
           // Trigger Selection Mode with heavy haptic
           ref.read(selectionControllerProvider).selectItem(item, haptic: true);
        },
        onDelete: () => widget.controller.deleteItem(item),
        onArchive: (archive) => widget.controller.archiveItem(item, archive),
        onRestore: () => widget.controller.restoreItem(item),
      ),
    );
  }

  void _handleLocalReorder(String incomingKey, dynamic targetItem) {
     if (!_isDragging) return;
     
     // 1. Find indices
     final int targetIndex = _localItems.indexOf(targetItem);
     if (targetIndex == -1) return;
     
     int fromIndex = -1;
     dynamic draggingObj;
     
     for (int i=0; i<_localItems.length; i++) {
        final it = _localItems[i];
        final key = (it is Folder) ? "folder_${it.id}" : "note_${it.id}";
        if (key == incomingKey) {
           fromIndex = i;
           draggingObj = it;
           break;
        }
     }
     
     if (fromIndex == -1 || draggingObj == null) return;
     if (fromIndex == targetIndex) return;
     
     // 2. SWAP / REORDER
     // Google Keep style: If I drag Note A (idx 0) to Note C (idx 2)...
     // List becomes [Note B, Note C, Note A] ? 
     // No, usually it's insert.
     
     setState(() {
        _localItems.removeAt(fromIndex);
        _localItems.insert(targetIndex, draggingObj);
     });
     // HapticFeedback.selectionClick(); // Optional, feels good
  }
}
