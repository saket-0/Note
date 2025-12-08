import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlideMenuOverlay extends StatefulWidget {
  final Offset anchorPosition; // The center-bottom position of the hamburger icon
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onClose;
  
  const GlideMenuOverlay({
    super.key,
    required this.anchorPosition,
    required this.onRename,
    required this.onDelete,
    required this.onShare,
    required this.onClose,
  });

  @override
  State<GlideMenuOverlay> createState() => GlideMenuOverlayState();
}

class GlideMenuOverlayState extends State<GlideMenuOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int? _highlightedIndex;
  
  // Dimensions
  static const double _itemHeight = 50.0;
  static const double _menuWidth = 140.0;
  static const double _bottomPadding = 20.0; // Distance above finger
  
  // Logic: Menu grows UPWARDS from anchor.
  // Item 0 is at Bottom (Rename)
  // Item 1 is Middle (Share)
  // Item 2 is Top (Delete) -- Or reverse order based on "Glide Up"
  // "As finger crosses each list item... that item highlights"
  // If we drag UP, we cross the bottom-most item first.
  // So List should be:
  // [Delete] (Top)
  // [Share]
  // [Rename] (Bottom - First to hit)
  
  final List<String> _labels = ["Delete", "Share", "Rename"];
  final List<IconData> _icons = [Icons.delete, Icons.share, Icons.edit];
  final List<Color> _colors = [Colors.red, Colors.blue, Colors.orange];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       duration: const Duration(milliseconds: 150), 
       vsync: this
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  // Called by parent's onPanUpdate
  // Drag DY is negative when going UP.
  void updateDrag(double deltaY) {
     // deltaY is total displacement from start (usually negative)
     // Or absolute Y position?
     // Parent sends Global Position Y?
     // Let's assume parent sends "Offset from Anchor".
     
     // Ideally, we want to map "Distance Dragged Up" to "Item Index".
     // Distance 0 to 50 -> Rename
     // Distance 50 to 100 -> Share
     // Distance 100 to 150 -> Delete
     
     // Since dragging UP means negative dy (in screen coords), or positive "distance".
     // Let's use distance = -diff.dy (if diff is vector from Anchor to Finger)
  }
  
  void updateDragY(double dragAmountUpwards) {
     // dragAmountUpwards should be positive as we go up
     int index = -1;
     
     if (dragAmountUpwards > 0 && dragAmountUpwards < _itemHeight) {
       index = 2; // Rename (Bottom)
     } else if (dragAmountUpwards >= _itemHeight && dragAmountUpwards < _itemHeight * 2) {
       index = 1; // Share
     } else if (dragAmountUpwards >= _itemHeight * 2 && dragAmountUpwards < _itemHeight * 3) {
       index = 0; // Delete (Top)
     }
     
     if (index != _highlightedIndex) {
       setState(() {
         _highlightedIndex = index;
       });
       if (index != -1) HapticFeedback.selectionClick();
     }
  }

  void executeAndClose() {
    // Labels array: [Delete, Share, Rename] -> Indices 0, 1, 2
    if (_highlightedIndex == 0) widget.onDelete();
    if (_highlightedIndex == 1) widget.onShare();
    if (_highlightedIndex == 2) widget.onRename();
    
    _close();
  }
  
  void _close() {
    _controller.reverse().then((_) => widget.onClose());
  }

  @override
  Widget build(BuildContext context) {
    // Anchor is at the bottom center of the column.
    // We position the menu ABOVE the anchor.
    // Total Height = 3 * 50 = 150.
    
    // Position: 
    // Left = Anchor.dx - Width/2
    // Top = Anchor.dy - Height - BottomPadding
    
    final double totalHeight = _itemHeight * 3;
    final double topPos = widget.anchorPosition.dy - totalHeight - _bottomPadding;
    final double leftPos = widget.anchorPosition.dx - (_menuWidth / 2);
    
    return Stack(
      children: [
        // Modal Barrier (Touchable to cancel?)
        // Actually, logic says "Release outside -> Cancel".
        // The parent GestureDetector handles the release.
        
        Positioned(
          top: topPos,
          left: leftPos,
          child: ScaleTransition(
            scale: _scaleAnimation,
            alignment: Alignment.bottomCenter,
            child: Container(
              width: _menuWidth,
              height: totalHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C), // Dark Grey
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: List.generate(3, (i) {
                  final bool isHighlighted = _highlightedIndex == i;
                  return _buildItem(i, isHighlighted);
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildItem(int index, bool isHighlighted) {
    return Container(
      height: _itemHeight,
      decoration: BoxDecoration(
        color: isHighlighted ? _colors[index] : Colors.transparent,
        borderRadius: _getBorderRadius(index),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(_icons[index], color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(
            _labels[index],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  BorderRadius _getBorderRadius(int index) {
    if (index == 0) return const BorderRadius.vertical(top: Radius.circular(16));
    if (index == 2) return const BorderRadius.vertical(bottom: Radius.circular(16));
    return BorderRadius.zero;
  }
}
