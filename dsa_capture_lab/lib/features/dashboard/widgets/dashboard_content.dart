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
  int? _lastFolderId;
  DashboardFilter? _lastFilter; // Track filter to detect changes

  @override
  void didUpdateWidget(DashboardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
     // If filter changes, we must reset. 
     // We rely on build() to sync data, but if we are NOT dragging, we should sync.
  }

  @override
  Widget build(BuildContext context) {
    final currentFolderId = ref.watch(currentFolderProvider);
    
    // Scroll lock when glide menu is open
    final isMenuOpen = ref.watch(isGlideMenuOpenProvider);
    final ScrollPhysics scrollPhysics = isMenuOpen 
        ? const NeverScrollableScrollPhysics() 
        : const AlwaysScrollableScrollPhysics();
    
    // Detect Folder Change OR Filter Change & Reset
    if (currentFolderId != _lastFolderId || widget.currentFilter != _lastFilter) {
      _lastFolderId = currentFolderId;
      _lastFilter = widget.currentFilter;
      _isDragging = false;
      _draggingId = null;
      _localItems = [];
    }
    
    // Watch for pending removal (from move-to-parent or other cross-widget moves)
    final pendingRemovalKeys = ref.watch(pendingRemovalKeysProvider);
    if (pendingRemovalKeys.isNotEmpty) {
      // Remove items from local list and clear the pending keys
      _localItems.removeWhere((it) {
        final key = (it is Folder) ? "folder_${it.id}" : "note_${it.id}";
        return pendingRemovalKeys.contains(key);
      });
      // Clear the pending keys (schedule for after build)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pendingRemovalKeysProvider.notifier).state = {};
      });
    }

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
    // CRITICAL: We must sync when data changes (pin/unpin, add/remove), only block during active visual reorder
    print("DEBUG: _isDragging=$_isDragging");
    if (!_isDragging) {
      _errorMessageIfMismatch(sourceItems);
      _localItems = List.from(sourceItems);
    } else {
      // Even when dragging, force sync if:
      // 1. Length changed (item added/removed)
      // 2. Any item's isPinned changed
      bool forceSyncNeeded = sourceItems.length != _localItems.length;
      
      if (!forceSyncNeeded) {
        // Check for isPinned mismatch
        for (final sourceItem in sourceItems) {
          final sourceId = (sourceItem is Folder) ? sourceItem.id : (sourceItem as Note).id;
          final sourcePinned = (sourceItem is Note) ? sourceItem.isPinned : (sourceItem as Folder).isPinned;
          
          bool foundInLocal = false;
          for (final localItem in _localItems) {
            final localId = (localItem is Folder) ? localItem.id : (localItem as Note).id;
            if (sourceId == localId) {
              foundInLocal = true;
              final localPinned = (localItem is Note) ? localItem.isPinned : (localItem as Folder).isPinned;
              if (sourcePinned != localPinned) {
                forceSyncNeeded = true;
                break;
              }
            }
          }
          // New item not found in local
          if (!foundInLocal) {
            forceSyncNeeded = true;
          }
          if (forceSyncNeeded) break;
        }
      }
      
      if (forceSyncNeeded) {
        print("DEBUG: Data mismatch detected during drag, forcing sync (source=${sourceItems.length}, local=${_localItems.length})");
        _localItems = List.from(sourceItems);
        _isDragging = false;
        _draggingId = null;
      }
    }
    
    print("DEBUG: DashboardContent build. Filter=${widget.currentFilter}, Folder=$currentFolderId");
    print("DEBUG: sourceItems count: ${sourceItems.length}");
    print("DEBUG: _localItems count: ${_localItems.length}");
    
    // Debug: Show pinned state of first 3 items
    for (int i = 0; i < _localItems.length && i < 3; i++) {
      final item = _localItems[i];
      if (item is Note) {
        print("DEBUG: Item[$i] Note id=${item.id}, isPinned=${item.isPinned}");
      } else if (item is Folder) {
        print("DEBUG: Item[$i] Folder id=${item.id}, isPinned=${item.isPinned}");
      }
    }
    
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
        physics: scrollPhysics,
        itemCount: _localItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildItem(index, _localItems),
      );
    }
    
    return MasonryGridView.count(
      key: PageStorageKey('grid_$storageKey'),
      physics: scrollPhysics,
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
           final List<dynamic> freshItems;
           switch (widget.currentFilter) {
             case DashboardFilter.active:
               final currentId = ref.read(currentFolderProvider);
               freshItems = ref.read(activeContentProvider(currentId));
               break;
             case DashboardFilter.archived:
               freshItems = ref.read(archivedContentProvider);
               break;
             case DashboardFilter.trash:
               freshItems = ref.read(trashContentProvider);
               break;
           }
           
           bool itemWasMoved = true;
           for (final item in freshItems) {
              final key = (item is Folder) ? "folder_${item.id}" : "note_${item.id}";
              if (key == _draggingId) {
                 itemWasMoved = false;
                 break;
              }
           }
           
           if (itemWasMoved) {
              setState(() {
                _isDragging = false;
                _draggingId = null;
                _localItems = List.from(freshItems);
              });
              return;
           }

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
        // Communicate drag state to hide/show top bar
        // When drag ends (isDragging = false), clear selection to return to normal mode
        onDragStateChanged: (isDragging) {
           ref.read(isDraggingProvider.notifier).state = isDragging;
           if (!isDragging) {
             // Drag ended: deselect all items, return to normal search bar
             ref.read(selectionControllerProvider).clearSelection();
           }
        },
        // When item is moved into a folder, remove it from local list immediately
        onMoveComplete: (movedItemKey) {
           setState(() {
             _localItems.removeWhere((it) {
               final key = (it is Folder) ? "folder_${it.id}" : "note_${it.id}";
               return key == movedItemKey;
             });
             _isDragging = false;
             _draggingId = null;
           });
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
     
     // 2. PREVENT DRAGGING BETWEEN PINNED/UNPINNED SECTIONS
     final bool isDraggingPinned = (draggingObj is Note && draggingObj.isPinned) || 
                                    (draggingObj is Folder && draggingObj.isPinned);
     final bool isTargetPinned = (targetItem is Note && targetItem.isPinned) || 
                                  (targetItem is Folder && targetItem.isPinned);
     
     if (isDraggingPinned != isTargetPinned) {
        return; // Block the swap - can't cross pinned/unpinned boundary
     }
     
     // 3. SWAP / REORDER (within same section)
     setState(() {
        _localItems.removeAt(fromIndex);
        _localItems.insert(targetIndex, draggingObj);
     });
     // HapticFeedback.selectionClick(); // Optional, feels good
  }
}
