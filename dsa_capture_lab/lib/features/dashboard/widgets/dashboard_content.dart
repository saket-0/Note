import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../shared/database/drift/app_database.dart';
import '../../../shared/services/hydrated_state.dart';
import '../controllers/dashboard_controller.dart';
import '../providers/dashboard_state.dart';
import '../selection/selection.dart';
import 'dashboard_grid_item.dart';

class DashboardContent extends ConsumerStatefulWidget {
  final DashboardFilter currentFilter;
  final DashboardController controller;
  final ViewMode viewMode;
  final double bottomPadding;

  const DashboardContent({
    super.key,
    required this.currentFilter,
    required this.controller,
    required this.viewMode,
    this.bottomPadding = 0.0,
  });

  @override
  ConsumerState<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<DashboardContent> 
    with WidgetsBindingObserver {
  // Local state for optimistic reordering (The "Visual Order")
  List<dynamic> _localItems = [];
  bool _isDragging = false;
  String? _draggingId; // "note_123" or "folder_456"
  int? _lastFolderId;
  DashboardFilter? _lastFilter; // Track filter to detect changes
  
  // === SMART SCROLL: Velocity-based loading pause ===
  // When scrolling fast, pause image loading to maintain 120Hz
  bool _isHighVelocityScroll = false;
  double _lastScrollPosition = 0;
  static const double _velocityThreshold = 2000.0; // pixels per second
  
  // Precache tracking
  int _lastPrecacheMinIndex = -1;

  @override
  void initState() {
    super.initState();
    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    // Reset glide menu state on widget initialization (prevents stuck scroll)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(isGlideMenuOpenProvider.notifier).state = false;
      }
    });
  }

  @override
  void dispose() {
    // Unregister lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    // Reset glide menu state on dispose (prevents stuck scroll)
    ref.read(isGlideMenuOpenProvider.notifier).state = false;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reset glide menu state when app resumes (prevents stuck scroll after multitasking)
    if (state == AppLifecycleState.resumed) {
      ref.read(isGlideMenuOpenProvider.notifier).state = false;
    }
  }

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

    // Fetch Source of Truth from streams
    final AsyncValue<List<dynamic>> asyncItems;
    if (widget.currentFilter == DashboardFilter.active) {
      asyncItems = ref.watch(activeContentStreamProvider(currentFolderId));
    } else if (widget.currentFilter == DashboardFilter.archived) {
      asyncItems = ref.watch(archivedContentStreamProvider);
    } else {
      asyncItems = ref.watch(trashedContentStreamProvider);
    }
    
    // Handle async state
    final List<dynamic> sourceItems = asyncItems.when(
      data: (items) => items,
      loading: () => _localItems, // Keep current items while loading
      error: (e, _) => _localItems, // Keep current items on error
    );
    
    // Sync Local State if NOT dragging
    // CRITICAL: We must sync when data changes (pin/unpin, add/remove), only block during active visual reorder
    print("DEBUG: _isDragging=$_isDragging");
    if (!_isDragging) {
      _errorMessageIfMismatch(sourceItems);
      _localItems = List.from(sourceItems);
    } else {
      // During drag, we need to:
      // 1. If items were added/removed - force full sync and cancel drag
      // 2. If isPinned changed for any item - force full sync (items need re-sorting)
      // 3. Otherwise - keep order stable
      
      // Build source map for comparison
      final Map<String, dynamic> sourceMap = {};
      final Set<String> sourceIds = {};
      for (final item in sourceItems) {
        final key = (item is Folder) ? "folder_${item.id}" : "note_${item.id}";
        sourceIds.add(key);
        sourceMap[key] = item;
      }
      
      // Build local IDs set and check for isPinned changes
      final Set<String> localIds = {};
      bool isPinnedChanged = false;
      for (final localItem in _localItems) {
        final key = (localItem is Folder) ? "folder_${localItem.id}" : "note_${localItem.id}";
        localIds.add(key);
        
        final sourceItem = sourceMap[key];
        if (sourceItem != null) {
          final localPinned = (localItem is Note) ? localItem.isPinned : (localItem as Folder).isPinned;
          final sourcePinned = (sourceItem is Note) ? sourceItem.isPinned : (sourceItem as Folder).isPinned;
          if (localPinned != sourcePinned) {
            isPinnedChanged = true;
          }
        }
      }
      
      // Check if item SET changed (add/remove)
      final bool itemsChanged = !sourceIds.containsAll(localIds) || !localIds.containsAll(sourceIds);
      
      if (itemsChanged || isPinnedChanged) {
        // Items added/removed OR isPinned changed - must reset to re-sort
        print("DEBUG: Forcing sync (itemsChanged=$itemsChanged, isPinnedChanged=$isPinnedChanged)");
        _localItems = List.from(sourceItems);
        _isDragging = false;
        _draggingId = null;
      }
      // If only other data changed (not isPinned, not add/remove), keep order stable
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
      return NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: ListView.separated(
          key: PageStorageKey('list_$storageKey'),
          physics: scrollPhysics,
          padding: EdgeInsets.only(bottom: widget.bottomPadding),
          itemCount: _localItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildItem(index, _localItems),
        ),
      );
    }
    
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: MasonryGridView.count(
        key: PageStorageKey('grid_$storageKey'),
        physics: scrollPhysics,
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        cacheExtent: 500, // Pre-build 500px of off-screen items for smoother scroll
        itemCount: _localItems.length,
        itemBuilder: (context, index) => _buildItem(index, _localItems),
      ),
    );
  }

  /// Handle scroll notifications and detect high-velocity scrolling
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final currentPosition = notification.metrics.pixels;
      
      // === PHOENIX PROTOCOL: Track scroll position for persistence ===
      ref.read(scrollPositionProvider.notifier).update(currentPosition);
      
      // Calculate velocity from position delta (approximate)
      // ScrollUpdateNotification provides per-frame deltas
      final delta = (currentPosition - _lastScrollPosition).abs();
      // Estimate velocity: delta * 60fps = pixels per second
      final estimatedVelocity = delta * 60;
      
      _lastScrollPosition = currentPosition;
      
      final wasHighVelocity = _isHighVelocityScroll;
      _isHighVelocityScroll = estimatedVelocity > _velocityThreshold;
      
       // Update provider only if state changed (avoids unnecessary rebuilds)
      if (wasHighVelocity != _isHighVelocityScroll) {
        ref.read(isHighVelocityScrollProvider.notifier).state = _isHighVelocityScroll;
      }
      
      // === PRECACHING STRATEGY ===
      // Only precache if velocity is reasonable (don't choke IO during flings)
      if (!_isHighVelocityScroll) {
         _precacheNextImages(currentPosition, notification.metrics.viewportDimension);
      }
    } else if (notification is ScrollEndNotification) {
      // Scroll ended - always resume normal loading
      if (_isHighVelocityScroll) {
        _isHighVelocityScroll = false;
        ref.read(isHighVelocityScrollProvider.notifier).state = false;
      }
    }
    return false; // Don't consume the notification
  }

  void _precacheNextImages(double scrollPos, double viewportHeight) {
    if (_localItems.isEmpty) return;

    // Approximate grid parameters
    const double avgItemHeight = 200.0; // Average height of grid item
    const int crossAxisCount = 2;       // Number of columns

    // Calculate approx index of first visible item
    // (scrollPos / itemHeight) * columns
    final int firstVisibleIndex = (scrollPos / avgItemHeight).floor() * crossAxisCount;
    
    // Calculate approx index of last visible item
    final int visibleItemsCount = (viewportHeight / avgItemHeight).ceil() * crossAxisCount;
    final int lastVisibleIndex = firstVisibleIndex + visibleItemsCount;
    
    // Determine precache range (next 20 items)
    final int startIndex = lastVisibleIndex;
    final int endIndex = (startIndex + 20).clamp(0, _localItems.length);
    
    // Throttle: Only process if we've scrolled past the previous batch (e.g. by 10 items)
    if ((startIndex - _lastPrecacheMinIndex).abs() < 10) return;
    _lastPrecacheMinIndex = startIndex;

    // Execute precache
    for (int i = startIndex; i < endIndex; i++) {
      if (i >= _localItems.length) break;
      
      final item = _localItems[i];
      if (item is Note) {
        // Prioritize thumbnail, then imagePath
        final String? path = item.thumbnailPath ?? item.imagePath;
        if (path != null && path.isNotEmpty) {
           precacheImage(FileImage(File(path)), context);
        }
      }
    }
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
               final asyncData = ref.read(activeContentStreamProvider(currentId));
               freshItems = asyncData.valueOrNull ?? _localItems;
               break;
             case DashboardFilter.archived:
               final archiveData = ref.read(archivedContentStreamProvider);
               freshItems = archiveData.valueOrNull ?? _localItems;
               break;
             case DashboardFilter.trash:
               final trashData = ref.read(trashedContentStreamProvider);
               freshItems = trashData.valueOrNull ?? _localItems;
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
