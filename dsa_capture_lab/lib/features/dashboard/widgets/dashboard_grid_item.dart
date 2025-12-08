import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/domain/entities/entities.dart';
import '../controllers/dashboard_controller.dart';
import 'joystick_menu.dart';

class DashboardGridItem extends ConsumerStatefulWidget {
  final dynamic item;
  final List<dynamic> allItems;
  final Function(String key, String zone) onDrop;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Function(bool) onArchive; 
  final VoidCallback onRestore;
  
  // New Callbacks for Keep-style Reorder
  final VoidCallback? onDragStart;
  final Function(DraggableDetails)? onDragEnd;
  final Function(String incomingKey, String zone)? onHoverReorder;

  const DashboardGridItem({
    super.key,
    required this.item,
    required this.allItems,
    required this.onDrop,
    required this.onTap,
    required this.onDelete,
    required this.onArchive,
    required this.onRestore,
    this.onDragStart,
    this.onDragEnd,
    this.onHoverReorder,
  });

  @override
  ConsumerState<DashboardGridItem> createState() => _DashboardGridItemState();
}

class _DashboardGridItemState extends ConsumerState<DashboardGridItem> {
  String _hoverState = 'merge'; // merge, left, right, reorder

  @override
  Widget build(BuildContext context) {
    final int itemId = widget.item.id;
    final bool isFolder = widget.item is Folder;
    final String dragKey = isFolder ? "folder_$itemId" : "note_$itemId";

    return Stack(
      children: [
        // LongPressDraggable
        LongPressDraggable<String>(
          data: dragKey,
          delay: const Duration(milliseconds: 300),
          onDragStarted: widget.onDragStart,
          onDragEnd: widget.onDragEnd,
          feedback: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: 1.05, // Slight pop
              child: Opacity(
                opacity: 0.9,
                child: SizedBox(
                   // Constrain width to look like the card but floating
                   // We ideally want exact size, but context.size might be better?
                   // For now, fixed width/height constraint or using existing builder with loose constraints
                  width: 160, 
                  height: 160, 
                  child: _buildContent(isFeedback: true),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            // VISIBLE HOLE: We want the item to be "invisible" but take up space.
            // Opacity 0 makes it invisible.
            // DashboardContent handles the "shifting" logic.
            // If we shift the list, a NEW item moves into this slot. 
            // So we actually want the *dragged item* (wherever it is in the list) to be 0 opacity.
            // But since local reordering changes the list, the item at this index CHANGES to something else.
            // So relying on `childWhenDragging` is tricky if the widget REBUILDS as a different item.
            // Use opacity: 0.0 only if we don't want "Ghost" behavior in the list.
            // But we DO want the list to reflow.
            // Actually, simply using 0.05 opacity provides a nice "placeholder" hint if needed, 
            // but Keep uses fully invisible (reflows around it).
            opacity: 0.0, 
            child: _buildContent(),
          ),
          child: GestureDetector(
            onTap: widget.onTap,
            child: _buildContent(),
          ),
        ),

        // Drag Target (Overlay)
        Positioned.fill(
          child: DragTarget<String>(
            onWillAccept: (incoming) {
               // Don't accept self
               return incoming != dragKey;
            },
            onMove: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final localPos = box.globalToLocal(details.offset);
              final width = box.size.width;
              final height = box.size.height;
              
              String newState = 'reorder'; // Default is reorder (center)

              // Check for edges (if we still want explicit "side" drops or folder merging)
              // Keep logic: Hovering center triggers reorder.
              // Hovering "long enough" triggers merge? 
              // For now, let's keep it simple: 
              // Center > 50% = Reorder.
              
              // Define zones
              // If we are strictly implementing "Reflow on Hover", we just need to detect "We are over this item".
              
              // Let's call callback immediately for "continuous reorder"
              if (widget.onHoverReorder != null) {
                  widget.onHoverReorder!(details.data as String, 'center');
              }

              // Visual feedback state
              // Maybe we still want to visualize "Merge" vs "Reorder"?
              // If we want merge, we might need a timer or dwell detection. 
              // For now, let's assume everything is Reorder unless explicitly implemented otherwise.
              
              if (_hoverState != newState) {
                setState(() => _hoverState = newState);
              }
            },
            onLeave: (_) {
               setState(() => _hoverState = 'idle');
            },
            onAccept: (incomingKey) => widget.onDrop(incomingKey, _hoverState),
            builder: (context, candidates, rejects) {
              // No visual overlay needed for reorder (the list reflow IS the feedback)
              // Only show highlight if we support Merge/Grouping later.
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContent({bool isFeedback = false}) {
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
            child: Image.file(
              File(item.imagePath!),
              fit: BoxFit.cover,
              cacheWidth: 400,
              gaplessPlayback: true,
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
           IconData icon = Icons.insert_drive_file;
           if (item.fileType == 'pdf') {
             icon = Icons.picture_as_pdf;
           } else if (item.fileType == 'text' || item.fileType == 'rich_text') {
             icon = Icons.description;
           }
           
           String previewText = item.content.trim();
            // Attempt to parse JSON if it looks like our rich text format, regardless of fileType tag (backward compatibility)
            if (item.fileType == 'rich_text' || (previewText.startsWith('{') && previewText.contains('"text":'))) {
              try {
                final json = jsonDecode(previewText);
                if (json is Map && json.containsKey('text')) {
                   previewText = json['text'] ?? "";
                }
              } catch (e) {
                // Fallback if parsing fails
              }
            }
           
           if (previewText.isEmpty) previewText = "No content";

           contentBody = Padding(
             padding: const EdgeInsets.all(12.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               mainAxisSize: MainAxisSize.min, 
               children: [
                      // Title
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
                      // Content snippet
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
    
    return Stack(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(15),
            border: (item is Note && item.color != 0) ? null : Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: contentBody,
        ),
        
        // PIN INDICATOR
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

        // DELETE MENU
        // JOYSTICK MENU
        if (!isFeedback)
        Positioned(
            bottom: 12,
            right: 12,
            child: JoystickMenu(
              isFolder: item is Folder,
              onRename: () {
                 // Open Rename Logic (Reuse creation dialog or new one)
              },
              onDelete: widget.onDelete,
              onArchive: () {
                final bool isArchived = (item is Folder) ? item.isArchived : (item as Note).isArchived;
                widget.onArchive(!isArchived); // Toggle
              },
              onCopy: () {
                // TODO: Implement Copy/Duplicate in Controller
              },
              onOpenAs: () {
                // Open As logic
                 if (item is Note && item.imagePath != null) {
                    DashboardController(context, ref).openFile(item); 
                 }
              }, 
            ),
          )
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
} // End Class replacement helper (not actual code)
