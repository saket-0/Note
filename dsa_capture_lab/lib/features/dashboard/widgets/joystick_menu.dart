import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'joystick_geometry.dart';

class JoystickMenu extends StatefulWidget {
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onArchive;
  final VoidCallback onCopy;
  final VoidCallback onOpenAs;
  final bool isFolder;

  const JoystickMenu({
    super.key,
    required this.onRename,
    required this.onDelete,
    required this.onArchive,
    required this.onCopy,
    required this.onOpenAs,
    required this.isFolder,
  });

  @override
  State<JoystickMenu> createState() => _JoystickMenuState();
}

class _JoystickMenuState extends State<JoystickMenu> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _ballKey = GlobalKey();

  void _startDrag(DragStartDetails details) {
    HapticFeedback.mediumImpact();
    // Calculate global position of the ball
    final RenderBox renderBox = _ballKey.currentContext?.findRenderObject() as RenderBox;
    final Offset ballPosition = renderBox.localToGlobal(Offset.zero);
    
    _overlayEntry = _createOverlayEntry(ballPosition);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _updateDrag(DragUpdateDetails details) {
    _overlayEntry?.markNeedsBuild(); // Trigger rebuild to update hover logic if needed (via GlobalKey access or Stream?)
    // Actually, we need to pass the drag updates TO the overlay.
    // So we need a GlobalKey for the Overlay content's state.
    globalOverlayKey.currentState?.updateDrag(details.globalPosition);
  }

  void _endDrag(DragEndDetails details) {
    globalOverlayKey.currentState?.endDrag();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  final GlobalKey<_JoystickOverlayState> globalOverlayKey = GlobalKey<_JoystickOverlayState>();

  OverlayEntry _createOverlayEntry(Offset ballPosition) {
    return OverlayEntry(
      builder: (context) => _JoystickOverlay(
        key: globalOverlayKey,
        ballPosition: ballPosition,
        onRename: widget.onRename,
        onDelete: widget.onDelete,
        onArchive: widget.onArchive,
        onCopy: widget.onCopy,
        onOpenAs: widget.onOpenAs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _startDrag,
      onPanUpdate: _updateDrag,
      onPanEnd: _endDrag,
        child: Container(
          key: _ballKey,
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.3), 
          ),
        ),
    );
  }
}

class _JoystickOverlay extends StatefulWidget {
  final Offset ballPosition;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onArchive;
  final VoidCallback onCopy;
  final VoidCallback onOpenAs;

  const _JoystickOverlay({
    super.key,
    required this.ballPosition,
    required this.onRename,
    required this.onDelete,
    required this.onArchive,
    required this.onCopy,
    required this.onOpenAs,
  });

  @override
  State<_JoystickOverlay> createState() => _JoystickOverlayState();
}

class _JoystickOverlayState extends State<_JoystickOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  int? _hoveredIndex;
  
  // Options
  final List<IconData> _icons = [Icons.edit, Icons.delete, Icons.archive, Icons.copy, Icons.open_in_new];
  final List<String> _labels = ["Rename", "Delete", "Archive", "Copy", "Open As"];
  final List<Color> _colors = [Colors.blue, Colors.red, Colors.grey, Colors.teal, Colors.orange];

  // Pre-calculated positions
  JoystickLayout? _layout;
  Offset _dragOffset = Offset.zero; // Local to Ball Center

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _expandAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
    
    // Calculate Positions ONCE
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final size = MediaQuery.of(context).size;
       _layout = JoystickGeometry.calculateLayout(
         ballPosition: widget.ballPosition, // This is top-left of widget (16x16)
         screenSize: size,
         radius: 65.0, // Reduced from 80.0
         itemCount: 5,
         horizontalMargin: 65.0 + 40.0, // Radius + 40px SAFE ZONE for Android Back Gesture
         verticalMargin: 65.0 + 16.0,   // Radius + 16px padding
       );
       setState(() {});
       
       // Trigger animation
       _controller.forward();
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void updateDrag(Offset globalPosition) {
    if (_layout == null) return;
    
    // Convert global drag to local offset relative to ball center
    final center = widget.ballPosition + const Offset(8, 8); // Ball Center
    
    // For visual drag, we want offset from Ball Center
    final local = globalPosition - center;

    setState(() {
       _dragOffset = local;
      _hoveredIndex = _hitTest(globalPosition);
    });
    if (_hoveredIndex != null) HapticFeedback.selectionClick();
  }

  void endDrag() {
    if (_hoveredIndex != null) {
       switch (_hoveredIndex) {
        case 0: widget.onRename(); break;
        case 1: widget.onDelete(); break;
        case 2: widget.onArchive(); break;
        case 3: widget.onCopy(); break;
        case 4: widget.onOpenAs(); break;
      }
    }
  }

  int? _hitTest(Offset currentPoint) {
    if (_layout == null) return null;

    final center = widget.ballPosition + const Offset(8, 8); 
    
    // SMART SHIFT HIT TEST:
    // We measure angle relative to the VIRTUAL CENTER (shifted)
    // The items are arranged around (BallCenter + Shift).
    // So we need vector from (BallCenter + Shift) to Finger.
    
    final virtualCenter = center + _layout!.centerOffset;
    final diff = currentPoint - virtualCenter;
    
    // Distance check?
    // User might be dragging from ball(edge) to center(inwards).
    // The distance from VIRTUAL center might be small or large.
    // Let's use distance from Ball for activation threshold?
    // Or just use angle if they are somewhat actively dragging.
    // Let's require them to move finger a bit from BALL center to activate.
    
    final distFromBall = (currentPoint - center).distance;
    if (distFromBall < 20) return null; // Deadzone
    
    final double touchAngle = math.atan2(diff.dy, diff.dx);
    
    int? bestIndex;
    double minAngleDiff = double.infinity;
    
    for (int i = 0; i < _layout!.itemOffsets.length; i++) {
      // itemOffsets are relative to BallCenter.
      // We want angle relative to VirtualCenter.
      // ItemPosAbs = BallCenter + ItemOffset
      // ItemPosRelVirtual = ItemPosAbs - VirtualCenter
      //                   = (BallCenter + ItemOffset) - (BallCenter + Shift)
      //                   = ItemOffset - Shift
      
      final relPos = _layout!.itemOffsets[i] - _layout!.centerOffset;
      final double itemAngle = math.atan2(relPos.dy, relPos.dx);
      
      // Calculate angular difference ensuring wraparound logic
      double angleDiff = (touchAngle - itemAngle).abs();
      if (angleDiff > math.pi) angleDiff = (2 * math.pi) - angleDiff;
      
      // Threshold: ~28 degrees
      if (angleDiff < 0.5) { 
        if (angleDiff < minAngleDiff) {
          minAngleDiff = angleDiff;
          bestIndex = i;
        }
      }
    }
    
    return bestIndex;
  }

  @override
  Widget build(BuildContext context) {
    if (_layout == null) return const SizedBox.shrink(); // Wait for layout

    final bool isEngulfed = _hoveredIndex != null;

    return Stack(
      children: [
        // TETHER LINE (Optional visual aid)
        if (!isEngulfed)
        CustomPaint(
            painter: _TetherPainter(
                start: widget.ballPosition + const Offset(8, 8),
                end: widget.ballPosition + const Offset(8, 8) + _dragOffset,
                color: Colors.white.withOpacity(0.3)
            ),
        ),

        // OPTIONS
        ...List.generate(5, (index) {
          return AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
               final double progress = _expandAnimation.value;
               // _layout!.itemOffsets are Relative to Ball (already contain shift)
               // However, we want them to ANIMATE OUT from the Ball?
               // Or from the Safe Center?
               // Ideally from Safe Center for "expansion" feel?
               // But usually menus expand from the "trigger point".
               // If we expand from Ball, they will slide into place. 
               // Let's expand relative to Ball (0,0) -> Target.
               // Target = Shift + Polar.
               
               final Offset target = _layout!.itemOffsets[index];
               
               // Lerp Position
               final double dx = target.dx * progress;
               final double dy = target.dy * progress;
               
               // Render position - Adjusted for new 16px center (Ball TopLeft + 8 + offset - ItemRadius)
               final left = widget.ballPosition.dx + 8 + dx - 20; 
               final top = widget.ballPosition.dy + 8 + dy - 20;
               
               final isHovered = _hoveredIndex == index; 
               
               final double safeOpacity = progress.clamp(0.0, 1.0);
               
               return Positioned(
                 left: left,
                 top: top,
                 child: Transform.scale(
                   // Engulf Effect: If covered, scale UP.
                   scale: isHovered ? 1.5 : 1.0, 
                   child: Opacity(
                     opacity: safeOpacity,
                     child: Container(
                       width: 40, height: 40,
                       decoration: BoxDecoration(
                         color: _colors[index],
                         shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                        border: isHovered ? Border.all(color: Colors.white, width: 3) : null,
                       ),
                       child: Icon(_icons[index], color: Colors.white, size: 20),
                     ),
                   ),
                 ),
               );
            }
          );
        }),

        // MOVABLE KNOB
        // Only visible if NOT engulfed
        if (!isEngulfed)
          Positioned(
            left: widget.ballPosition.dx + 8 + _dragOffset.dx - 8, // Center knob on drag point
            top: widget.ballPosition.dy + 8 + _dragOffset.dy - 8,
            child: Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
            ),
          ),
      ],
    );
  }
}

class _TetherPainter extends CustomPainter {
    final Offset start;
    final Offset end;
    final Color color;
    _TetherPainter({required this.start, required this.end, required this.color});
    
    @override
    void paint(Canvas canvas, Size size) {
        final paint = Paint()
            ..color = color
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round;
        canvas.drawLine(start, end, paint);
    }
    @override
    bool shouldRepaint(covariant _TetherPainter oldDelegate) => start != oldDelegate.start || end != oldDelegate.end;
}
