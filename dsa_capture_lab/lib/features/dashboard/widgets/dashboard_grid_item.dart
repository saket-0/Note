import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/domain/entities/entities.dart';
import '../../../shared/data/data_repository.dart';
import '../../../shared/services/folder_service.dart';
import '../gestures/body_zone/perfect_gesture.dart';
import '../gestures/glide_menu/glide_menu_overlay.dart' as glide;
import 'package:share_plus/share_plus.dart';
import '../providers/dashboard_state.dart';

class DashboardGridItem extends ConsumerStatefulWidget {
  final dynamic item;
  final List<dynamic> allItems;
  final Function(String key, String zone) onDrop;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Function(bool) onArchive; 
  final VoidCallback onRestore;
  
  // Selection Props
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onLongPress;

  // Callbacks for Keep-style Reorder
  final VoidCallback? onDragStart;
  final Function(DraggableDetails)? onDragEnd;
  final Function(String incomingKey, String zone)? onHoverReorder;
  
  // Callback for drag state changes (to hide top bar)
  final void Function(bool isDragging)? onDragStateChanged;
  
  // Callback when an item is moved into this item (for immediate local removal)
  final void Function(String movedItemKey)? onMoveComplete;

  const DashboardGridItem({
    super.key,
    required this.item,
    required this.allItems,
    required this.onDrop,
    required this.onTap,
    required this.onDelete,
    required this.onArchive,
    required this.onRestore,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onLongPress,
    this.onDragStart,
    this.onDragEnd,
    this.onHoverReorder,
    this.onDragStateChanged,
    this.onMoveComplete,
  });

  @override
  ConsumerState<DashboardGridItem> createState() => _DashboardGridItemState();
}

class _DashboardGridItemState extends ConsumerState<DashboardGridItem> {
  String _hoverState = 'idle'; // idle, folder-hover
  
  // Glide Menu State
  final GlobalKey _iconKey = GlobalKey();
  GlobalKey<glide.GlideMenuOverlayState> _overlayKey = GlobalKey();
  OverlayEntry? _menuOverlay;
  Alignment _iconAlignment = Alignment.bottomRight;
  
  @override
  void initState() {
    super.initState();
    // Determine column after layout
    WidgetsBinding.instance.addPostFrameCallback((_) => _determineAlignment());
  }
  
  void _determineAlignment() {
     // Always position the hamburger icon at bottom-right
     // (Previously this was dynamic based on column position)
     if (!mounted) return;
     setState(() {
       _iconAlignment = Alignment.bottomRight;
     });
  }

  // --- GLIDE MENU LOGIC (Using Modular System) ---

  void _showGlideMenu(PointerDownEvent event) {
     HapticFeedback.mediumImpact();
     
     // Lock scrolling while menu is open
     ref.read(isGlideMenuOpenProvider.notifier).state = true;
     
     final RenderBox iconBox = _iconKey.currentContext!.findRenderObject() as RenderBox;
     final Offset iconCenter = iconBox.localToGlobal(iconBox.size.center(Offset.zero));
     
     _overlayKey = GlobalKey<glide.GlideMenuOverlayState>();
     
     // Get the current filter to determine which menu options to show
     final filter = ref.read(activeFilterProvider);
     
     // Create menu items based on filter context
     final item = widget.item;
     final List<glide.GlideMenuItem> items;
     
     if (filter == DashboardFilter.trash) {
       // Trash context: Restore + Delete Forever
       items = glide.GlideMenuItems.forTrash(
         onRestore: widget.onRestore,
         onDeleteForever: widget.onDelete, // Controller handles permanent flag based on filter
       );
     } else if (filter == DashboardFilter.archived) {
       // Archive context: Unarchive + Delete
       items = glide.GlideMenuItems.forArchived(
         onUnarchive: () => widget.onArchive(false), // false = remove from archive
         onDelete: widget.onDelete,
       );
     } else if (item is Folder) {
       // Active: Folder menu
       items = glide.GlideMenuItems.forFolder(
         onPin: () => _handlePin(),
         onRename: () => _handleRename(),
         onShare: () => _handleShare(),
         onDelete: widget.onDelete,
       );
     } else if (item is Note && item.fileType == 'image') {
       // Active: Image note menu
       items = glide.GlideMenuItems.forImageNote(
         onPin: () => _handlePin(),
         onRename: () => _handleRename(),
         onShare: () => _handleShare(),
         onDelete: widget.onDelete,
       );
     } else {
       // Active: Text note menu
       items = glide.GlideMenuItems.forTextNote(
         onPin: () => _handlePin(),
         onColor: () => _showColorPicker(),
         onShare: () => _handleShare(),
         onDelete: widget.onDelete,
       );
     }
     
     // Store anchor position for drag calculations in the barrier
     final menuAnchor = iconCenter;
     
     _menuOverlay = OverlayEntry(
       builder: (context) => Stack(
         children: [
           // Full-screen barrier to block scrolling and capture all pointer events
           Positioned.fill(
             child: Listener(
               behavior: HitTestBehavior.opaque, // Captures ALL pointer events
               onPointerMove: (event) {
                 // Forward drag events to menu
                 final distanceUp = menuAnchor.dy - event.position.dy;
                 _overlayKey.currentState?.updateDragY(distanceUp);
               },
               onPointerUp: (event) {
                 // Execute action on release
                 _overlayKey.currentState?.executeAndClose();
               },
               onPointerCancel: (event) {
                 // Close on cancel (e.g., system gesture)
                 _closeGlideMenu();
               },
               child: Container(color: Colors.transparent),
             ),
           ),
           // The actual menu
           glide.GlideMenuOverlay(
             key: _overlayKey,
             anchorPosition: iconCenter,
             items: items,
             onClose: _closeGlideMenu,
           ),
         ],
       ),
     );
     
     Overlay.of(context).insert(_menuOverlay!);
  }
  
  void _handlePin() async {
    final item = widget.item;
    final repo = ref.read(dataRepositoryProvider);
    
    debugPrint('[DEBUG] _handlePin called for: ${item.runtimeType}, id: ${item.id}');
    
    if (item is Note) {
      debugPrint('[DEBUG] Toggling Note pin: ${item.isPinned} -> ${!item.isPinned}');
      await repo.updateNote(item.copyWith(isPinned: !item.isPinned));
    } else if (item is Folder) {
      debugPrint('[DEBUG] Toggling Folder pin: ${item.isPinned} -> ${!item.isPinned}');
      await repo.updateFolder(item.copyWith(isPinned: !item.isPinned));
    }
    
    debugPrint('[DEBUG] _handlePin completed');
  }
  
  void _handleShare() async {
    final item = widget.item;
    
    if (item is Note) {
      if (item.fileType == 'image' && item.imagePath != null) {
        await Share.shareXFiles([XFile(item.imagePath!)], text: item.title);
      } else {
        await Share.share('${item.title}\n\n${item.content}');
      }
    } else if (item is Folder) {
      // Folders not supported yet
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing folders not supported yet')),
        );
      }
    }
  }
  
  void _handleRename() {
    final item = widget.item;
    final controller = TextEditingController(
      text: item is Folder ? item.name : (item as Note).title,
    );
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item is Folder ? 'Rename Folder' : 'Rename Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(dialogContext);
                final repo = ref.read(dataRepositoryProvider);
                if (item is Folder) {
                  await repo.updateFolder(item.copyWith(name: newName));
                } else if (item is Note) {
                  await repo.updateNote(item.copyWith(title: newName));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _showColorPicker() {
    // TODO: Show color picker bottom sheet
    debugPrint("Color: ${widget.item.id}");
  }

  void _updateGlideMenu(PointerMoveEvent event) {
     if (_menuOverlay == null) return;
     // Track Y-Axis DRAG relative to start? 
     // Actually GlideMenuOverlay calculates based on drag UP distance.
     // We need to calculate how much we moved UP from the anchor.
     
     // Let's pass the raw Global Y coordinate to be safer, 
     // OR calculate distance here.
     final RenderBox iconBox = _iconKey.currentContext!.findRenderObject() as RenderBox;
     final Offset iconCenter = iconBox.localToGlobal(iconBox.size.center(Offset.zero));
     
     // Drag Up -> currentY < startY. distance = startY - currentY.
     final double distanceUp = iconCenter.dy - event.position.dy;
     
     _overlayKey.currentState?.updateDragY(distanceUp);
  }

  void _endGlideMenu(PointerUpEvent event) {
     if (_menuOverlay == null) return;
     _overlayKey.currentState?.executeAndClose();
     // _menuOverlay pointer is cleared inside executeAndClose's callback (onClose)
  }
  
  void _closeGlideMenu() {
     _menuOverlay?.remove();
     _menuOverlay = null;
     
     // Unlock scrolling (only if widget is still mounted)
     if (mounted) {
       ref.read(isGlideMenuOpenProvider.notifier).state = false;
     }
  }

  @override
  Widget build(BuildContext context) {
    final int itemId = widget.item.id;
    final bool isFolder = widget.item is Folder;
    final String dragKey = isFolder ? "folder_$itemId" : "note_$itemId";

    // Visual Scales
    final double scale = widget.isSelected ? 0.95 : 1.0;
    
    // Z-Order (Stack):
    return Stack(
      children: [
        // LAYER 1: The Body (Zone B)
        // Wraps Content + Drag Logic
        DragTarget<String>(
            onWillAccept: (incoming) {
               // Accept only if: 1) target is a Folder, 2) not dropping on itself
               final isFolder = widget.item is Folder;
               return incoming != dragKey && isFolder;
            },
            onMove: (details) {
               // Show immediate blue border for valid folder targets
               // (No dwell timer needed - folder acceptance is instant)
               if (widget.item is Folder && _hoverState != 'folder-hover') {
                 setState(() {
                   _hoverState = 'folder-hover';
                 });
                 HapticFeedback.lightImpact();
               }
               // Reorder logic delegated to parent via callback (for non-folder targets)
               // This callback is now only called when NOT over a folder
               if (widget.item is! Folder && widget.onHoverReorder != null) {
                 widget.onHoverReorder?.call(details.data, 'center');
               }
            },
            onLeave: (_) {
               setState(() => _hoverState = 'idle');
            },
            onAccept: (incomingKey) async {
               // Move item into folder via FolderService
               if (widget.item is Folder) {
                 final folderService = ref.read(folderServiceProvider);
                 final success = await folderService.moveItemByKey(
                   itemKey: incomingKey,
                   targetFolderId: widget.item.id,
                 );
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to move item to folder'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else if (success) {
                    // Notify parent to remove item from local list immediately
                    widget.onMoveComplete?.call(incomingKey);
                  }
               } else {
                 // Fallback to original drop handler for reorder
                 widget.onDrop(incomingKey, _hoverState);
               }
               setState(() => _hoverState = 'idle');
            },
            builder: (context, candidates, rejects) {
               final bool showFolderHover = _hoverState == 'folder-hover';
               
               // Build the gesture-aware content
               Widget gestureContent = PerfectGestureDetector(
                 isSelected: widget.isSelected,
                 onTap: widget.onTap,
                 onLongPress: widget.onLongPress,
                 onDragStateChanged: widget.onDragStateChanged,
                 child: AnimatedScale(
                   scale: scale,
                   duration: const Duration(milliseconds: 100),
                   child: Container(
                     decoration: showFolderHover ? BoxDecoration(
                       border: Border.all(color: Colors.blueAccent, width: 4),
                       borderRadius: BorderRadius.circular(15)
                     ) : null,
                     child: _buildContent(isSelected: widget.isSelected),
                   ),
                 ),
               );
               
               // GRID LOCK: When selection mode is active, disable drag-to-reorder
               // The first item being dragged won't rebuild until release, so it can still drag
               // Other items will have isSelectionMode=true and won't get LongPressDraggable
               if (widget.isSelectionMode) {
                 return gestureContent; // No LongPressDraggable = grid locked
               }
               
               // Normal mode: Enable drag-to-reorder with LongPressDraggable
               return LongPressDraggable<String>(
                  data: dragKey,
                  delay: const Duration(milliseconds: 350), // 350ms lock
                  onDragStarted: widget.onDragStart,
                  onDragEnd: widget.onDragEnd,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Transform.scale(
                      scale: 1.05,
                      child: Opacity(
                        opacity: 0.9,
                        child: SizedBox(
                          width: 160, 
                          height: 160, 
                          child: _buildContent(isFeedback: true),
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3, // Ghostly partial opacity
                    child: _buildContent(),
                  ),
                  onDragCompleted: () {},
                  child: gestureContent,
               );
            },
          ),
        
        // LAYER 2: The Hamburger Icon (Zone A)
        // ONLY positioned in the corner, NOT filling the entire card
        if (!widget.isSelectionMode)
        Positioned(
           // Position based on which column we're in
           right: _iconAlignment == Alignment.bottomRight ? 4 : null,
           left: _iconAlignment == Alignment.bottomLeft ? 4 : null,
           bottom: 4,
           child: Listener(
             behavior: HitTestBehavior.opaque, // Only catch events in THIS widget's bounds
             onPointerDown: _showGlideMenu,
             onPointerMove: _updateGlideMenu,
             onPointerUp: _endGlideMenu,
             onPointerCancel: (_) => _closeGlideMenu(), // Safety: close on cancel
             // Hitbox: 48x48 invisible container with Icon centered
             child: Container(
               key: _iconKey,
               width: 48,
               height: 48,
               color: Colors.transparent, // Invisible Hitbox
               alignment: Alignment.center,
               child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                     color: Colors.black.withOpacity(0.4),
                     shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.menu, color: Colors.white, size: 16),
               ),
             ),
           ),
        ),
          
          // Selection Checkmark Overlay
          if (widget.isSelected)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
            ),
      ],
    );
  }

  Widget _buildContent({bool isFeedback = false, bool isSelected = false}) {
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
      contentBody = Padding(
        padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 16.0), // Added Height
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, color: Colors.blueAccent, size: 40),
            const SizedBox(height: 8),
            Text(
              item.name, 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else { // Note

       // 1. IMAGE COLLAGE (Multi-Image)
       if (item.images.isNotEmpty) {
          contentBody = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildImageCollage(item.images),
              if (item.title.isNotEmpty || item.content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.title.isNotEmpty)
                        Text(
                          item.title,
                          style: TextStyle(
                            color: (item.color != 0) ? Colors.black87 : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (item.content.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.content,
                          style: TextStyle(
                            color: (item.color != 0) ? Colors.black54 : Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]
                    ],
                  ),
                )
            ],
          );
       }
       // 2. SINGLE IMAGE (Legacy or Single)
       else if (item.fileType == 'image' && item.imagePath != null) {
          contentBody = ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                Image.file(
                  File(item.imagePath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  cacheWidth: 400,
                  gaplessPlayback: true,
                ),
                // Gradient label overlay
                if (item.title.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          );
       } 
       // 3. CHECKLIST
       else if (item.isChecklist) {
           contentBody = Padding(
             padding: const EdgeInsets.all(12.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               mainAxisSize: MainAxisSize.min,
               children: [
                  // Title
                  if (item.title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: (item.color != 0) ? Colors.black87 : Colors.white, 
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Checklist Preview
                  ..._buildChecklistPreview(item, isFeedback ? 3 : 6, (item.color != 0) ? Colors.black87 : Colors.white70),
               ],
             ),
           );
       }
       // 4. TEXT / OTHER
       else {
           // ... (Same parsing logic as before)
           // Simplified for replacement:
           String previewText = item.content.trim();
            if (item.fileType == 'rich_text' || (previewText.startsWith('{') && previewText.contains('"text":'))) {
              try {
                final json = jsonDecode(previewText);
                if (json is Map && json.containsKey('text')) {
                   previewText = json['text'] ?? "";
                }
              } catch (e) {}
            }
           if (previewText.isEmpty) previewText = "No content";

           contentBody = Padding(
             padding: const EdgeInsets.all(12.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               mainAxisSize: MainAxisSize.min, 
               children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: (item.color != 0) ? Colors.black87 : Colors.white, 
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: isFeedback ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        previewText,
                        style: TextStyle(
                          color: (item.color != 0) ? Colors.black54 : Colors.white70,
                          fontSize: 14,
                        ),
                        maxLines: isFeedback ? 2 : 6,
                        overflow: TextOverflow.ellipsis,
                      ),
               ],
             ),
           );
       }
    }
    
    // WRAPPER:
    final container = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        border: (item is Note && item.color != 0) ? null : Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: contentBody,
    );

    if (isSelected) {
       return Container(
         decoration: BoxDecoration(
           border: Border.all(color: Colors.blueAccent, width: 2), // Selected Border
           borderRadius: BorderRadius.circular(15),
         ),
         child: container,
       );
    }
    
    return Stack(
      children: [
        container,
        // PIN INDICATOR (Inside content)
        if (item is Note && item.isPinned)
          Positioned(
            top: 8,
            right: 8,
            child: Icon(
              Icons.push_pin, 
              size: 16, 
              color: (item.color != 0) ? Colors.black54 : Colors.white70
            ),
          ),
      ],
    );
  }

  Widget _buildImageCollage(List<String> images) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
        child: Image.file(
          File(images[0]), 
          fit: BoxFit.cover, 
          height: 150, 
          width: double.infinity, 
          cacheWidth: 400,
          gaplessPlayback: true,
        ),
      );
    } else if (images.length == 2) {
      return Row(
         children: images.map((path) => Expanded(
           child: SizedBox(
             height: 120,
             child: Image.file(
               File(path), 
               fit: BoxFit.cover, 
               cacheWidth: 300,
               gaplessPlayback: true,
             ),
           )
         )).toList(),
      );
    } else if (images.length == 3) {
      return Column(
        children: [
          SizedBox(
            height: 100, 
            width: double.infinity, 
            child: Image.file(
              File(images[0]), 
              fit: BoxFit.cover, 
              cacheWidth: 400,
              gaplessPlayback: true,
            ),
          ),
          Row(
             children: [
               Expanded(child: SizedBox(height: 80, child: Image.file(File(images[1]), fit: BoxFit.cover, cacheWidth: 300, gaplessPlayback: true))),
               Expanded(child: SizedBox(height: 80, child: Image.file(File(images[2]), fit: BoxFit.cover, cacheWidth: 300, gaplessPlayback: true))),
             ],
          )
        ],
      );
    } else {
       // 4 or more
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        children: images.take(4).map((path) => Image.file(
          File(path), 
          fit: BoxFit.cover, 
          cacheWidth: 200,
          gaplessPlayback: true,
        )).toList(),
      );
    }
  }

  List<Widget> _buildChecklistPreview(Note note, int maxLines, Color textColor) {
    final lines = note.content.split('\n').take(maxLines).toList();
    List<Widget> widgets = [];
    for (var line in lines) {
       bool checked = line.startsWith('[x] ');
       String text = line.replaceFirst(RegExp(r'^\[[ x]\] '), '');
       widgets.add(
         Row(
           children: [
             Icon(
               checked ? Icons.check_circle_outline : Icons.radio_button_unchecked,
               size: 14,
               color: textColor.withOpacity(0.6),
             ),
             const SizedBox(width: 6),
             Expanded(
               child: Text(
                 text,
                 style: TextStyle(
                   color: textColor,
                   fontSize: 13,
                   decoration: checked ? TextDecoration.lineThrough : null
                 ),
                 overflow: TextOverflow.ellipsis,
               ),
             )
           ],
         )
       );
       widgets.add(const SizedBox(height: 4));
    }
    if (note.content.split('\n').length > maxLines) {
       widgets.add(Text("...", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 10)));
    }
    return widgets;
  }
}

