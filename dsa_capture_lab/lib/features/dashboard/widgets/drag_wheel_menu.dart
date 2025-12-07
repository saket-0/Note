import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DragWheelMenu extends StatefulWidget {
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onArchive;
  final VoidCallback onCopy; // Added Copy
  final VoidCallback onOpenAs; // Added Open As
  final bool isFolder; // To disable OpenAs if needed, or adjust icons

  const DragWheelMenu({
    super.key,
    required this.onRename,
    required this.onDelete,
    required this.onArchive,
    required this.onCopy,
    required this.onOpenAs,
    required this.isFolder,
  });

  @override
  State<DragWheelMenu> createState() => _DragWheelMenuState();
}

class _DragWheelMenuState extends State<DragWheelMenu> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  int? _hoveredIndex;
  
  // 5 Options
  // 0: Rename, 1: Delete, 2: Archive, 3: Copy, 4: Open As
  final List<IconData> _icons = [
    Icons.edit,
    Icons.delete,
    Icons.archive,
    Icons.copy,
    Icons.open_in_new,
  ];
  
  final List<String> _labels = [
    "Rename", "Delete", "Archive", "Copy", "Open As"
  ];

  final List<Color> _colors = [
    Colors.blue,
    Colors.red,
    Colors.grey,
    Colors.teal,
    Colors.orange,
  ];

  bool _isDragging = false;
  Offset _dragStart = Offset.zero;
  Offset _currentDrag = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
  }

  void _onPanStart(DragStartDetails details) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isDragging = true;
      _dragStart = details.globalPosition;
      _currentDrag = details.globalPosition;
    });
    _controller.forward();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentDrag = details.globalPosition;
      _hoveredIndex = _hitTest(details.globalPosition);
    });
    
    if (_hoveredIndex != null) {
      // Haptic feedback only on change? No, too spammy.
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_hoveredIndex != null) {
      HapticFeedback.selectionClick();
      switch (_hoveredIndex) {
        case 0: widget.onRename(); break;
        case 1: widget.onDelete(); break;
        case 2: widget.onArchive(); break;
        case 3: widget.onCopy(); break;
        case 4: widget.onOpenAs(); break;
      }
    }
    
    setState(() {
      _isDragging = false;
      _hoveredIndex = null;
    });
    _controller.reverse();
  }

  int? _hitTest(Offset currentPoint) {
    final diff = currentPoint - _dragStart;
    final dist = diff.distance;
    
    if (dist < 20) return null; // Deadzone

    // Calculate angle
    // -PI to PI. 0 is Right.
    double angle = math.atan2(diff.dy, diff.dx);
    if (angle < 0) angle += 2 * math.pi; // 0 to 2PI
    
    // 5 segments = 360 / 5 = 72 deg = 1.256 rad
    // Shift slightly so up is centered? Or straightforward?
    // Let's divide equally.
    // 0: Rename (Right?), etc. 
    // Let's map intuitively if possible.
    // BottomRight: Delete? TopRight: Rename?
    
    // Let's just do sequential sectors for simplicity.
    final sector = (angle / (2 * math.pi / 5)).floor();
    return sector % 5;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      behavior: HitTestBehavior.opaque, // Catch drag even if child is small?
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // The Draggable Ball
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2), 
              border: Border.all(color: Colors.white.withOpacity(0.5)),
            ),
            child: const Icon(Icons.drag_indicator, size: 16, color: Colors.white70),
          ),
          
          if (_isDragging || _controller.isAnimating)
            ...List.generate(5, (index) {
              final double angle = (index * (2 * math.pi / 5));
              final isHovered = _hoveredIndex == index;
              
              return AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, child) {
                  final double dist = 70.0 * _expandAnimation.value;
                  final double dx = dist * math.cos(angle);
                  final double dy = dist * math.sin(angle);
                  
                  return Positioned(
                    left: 16 + dx - 20, // Center relative to 16 (half of 32)
                    top: 16 + dy - 20,
                    child: Transform.scale(
                      scale: isHovered ? 1.2 : 1.0,
                      child: Opacity(
                        opacity: _expandAnimation.value,
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _colors[index],
                                shape: BoxShape.circle,
                                boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                                border: isHovered ? Border.all(color: Colors.white, width: 2) : null,
                              ),
                              child: Icon(_icons[index], color: Colors.white, size: 20),
                            ),
                            if (isHovered)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                child: Text(_labels[index], style: const TextStyle(color: Colors.white, fontSize: 10)),
                              )
                          ],
                        ),
                      ),
                    ),
                  );
                }
              );
            })
        ],
      ),
    );
  }
}
