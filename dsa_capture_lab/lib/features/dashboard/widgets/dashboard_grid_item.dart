import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';

class DashboardGridItem extends StatefulWidget {
  final dynamic item;
  final List<dynamic> allItems;
  final Function(String key, String zone) onDrop;
  final VoidCallback onTap;
  final VoidCallback onDelete; // Added

  const DashboardGridItem({
    super.key,
    required this.item,
    required this.allItems,
    required this.onDrop,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<DashboardGridItem> createState() => _DashboardGridItemState();
}

class _DashboardGridItemState extends State<DashboardGridItem> {
  String _hoverState = 'merge'; // merge, left, right

  @override
  Widget build(BuildContext context) {
    final int itemId = widget.item.id;
    final bool isFolder = widget.item is Folder;
    final String dragKey = isFolder ? "folder_$itemId" : "note_$itemId";

    // Decoupled Stack:
    // Bottom: DragTarget (Handles Hover/Drop Logic & Border Feedback)
    // Top: Draggable (Handles Drag Start & Content Display)
    
    // Decoupled Stack:
    // Bottom: The Content (Determines Size)
    // Overlay 1: DragTarget (Matches Content Size)
    // Overlay 2: Draggable (Matches Content Size)
    
    return Stack(
      children: [
        // LAYER 0: The Content (Invisible Placeholder for Size)
        // We need the size to be determined by the content, but the content itself is draggable.
        // So we render the content here just to give the Stack a size? 
        // No, simplest way is:
        // Stack {
        //   1. Draggable(child: Content) -> This is the main visible thing.
        //   2. DragTarget (Positioned.fill) -> Overlay or Underlay.
        // }
        // BUT Draggable wrapper doesn't force size unless child does.
        
        // Let's swap the order or remove Positioned.fill from the "sizing" element.
        
        // LongPressDraggable
        LongPressDraggable<String>(
          data: dragKey,
           delay: const Duration(milliseconds: 300),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.8,
              child: SizedBox(
                width: 140, 
                height: 140, 
                child: _buildContent(isFeedback: true),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _buildContent(),
          ),
          child: GestureDetector(
            onTap: widget.onTap,
            child: _buildContent(),
          ),
        ),

        // LAYER 1: Drag Target (Overlay)
        // This sits on top (or below if we want) but must match size of above.
        // Since the above is NOT Positioned, the Stack takes its size.
        // So we can use Positioned.fill for this one.
        Positioned.fill(
          child: DragTarget<String>(
            onMove: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final localPos = box.globalToLocal(details.offset);
              final width = box.size.width;
              
              String newState = 'merge';
              if (localPos.dx < width * 0.20) {
                newState = 'left';
              } else if (localPos.dx > width * 0.80) {
                newState = 'right';
              } else {
                newState = 'merge';
              }

              if (_hoverState != newState) {
                setState(() => _hoverState = newState);
              }
            },
            onLeave: (_) {},
            onAccept: (incomingKey) => widget.onDrop(incomingKey, _hoverState),
            builder: (context, candidates, rejects) {
              if (candidates.isEmpty) return const SizedBox.shrink();
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: _hoverState == 'merge' 
                      ? Border.all(color: Colors.tealAccent, width: 4) 
                      : null,
                  color: _hoverState == 'merge' ? Colors.teal.withOpacity(0.2) : null,
                ),
                child: Stack(
                  children: [
                     if (_hoverState == 'left')
                       Positioned(left: 0, top: 0, bottom: 0, width: 8, child: Container(
                         decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(4))
                       )),
                     if (_hoverState == 'right')
                       Positioned(right: 0, top: 0, bottom: 0, width: 8, child: Container(
                         decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(4))
                       )),
                  ],
                ),
              );
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
      contentBody = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, color: Colors.blueAccent, size: 40),
          const SizedBox(height: 8),
          Text(
            item.name, 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else { // Note
       if (item.fileType == 'image' && item.imagePath != null) {
          contentBody = ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.file(
              File(item.imagePath!),
              fit: BoxFit.cover, 
            ),
          );
       } else {
          // Text / Other
          IconData icon = Icons.insert_drive_file;
           if (item.fileType == 'pdf') {
             icon = Icons.picture_as_pdf;
           } else if (item.fileType == 'text') {
             icon = Icons.description;
           }
           
           // Text Content Preview (Keep Style)
           String previewText = item.content.trim();
           if (previewText.isEmpty) previewText = "No content";

           contentBody = Padding(
             padding: const EdgeInsets.all(12.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               mainAxisSize: MainAxisSize.min, // Wrap content
               children: [
                 if (item.imagePath == null) ...[
                    // Title
                    Text(
                      item.title,
                      style: TextStyle(
                        color: (item.color != 0) ? Colors.black87 : Colors.white, 
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
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
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                 ] 
               ],
             ),
           );
       }
    }
    
    return Stack(
      children: [
        Container(
          width: double.infinity, // <--- Force full width for 2-column Masonry
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(15),
            // Glass border if no color
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

        // DELETE MENU (Show only if not dragging feedback)
        if (!isFeedback)
        Positioned(
            bottom: 4,
            right: 4,
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert, 
                size: 20, 
                color: (item is Note && item.color != 0) ? Colors.black54 : Colors.white70
              ),
              onSelected: (value) {
                if (value == 'delete') widget.onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text("Delete"),
                    ],
                  ),
                ),
              ],
            ),
          )
      ],
    );
  }
}
