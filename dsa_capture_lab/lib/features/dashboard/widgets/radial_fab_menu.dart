import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A radial FAB menu using separate OverlayEntry for expansion.
/// Collapsed state is a standard FAB size (56x56) to ensure correct layout.
class RadialFabMenu extends StatefulWidget {
  final VoidCallback onCreateNote;
  final VoidCallback onImportFile;
  final VoidCallback onCreateFolder;

  const RadialFabMenu({
    super.key,
    required this.onCreateNote,
    required this.onImportFile,
    required this.onCreateFolder,
  });

  @override
  State<RadialFabMenu> createState() => _RadialFabMenuState();
}

class _RadialFabMenuState extends State<RadialFabMenu> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey<RadialMenuOverlayState> _overlayKey = GlobalKey<RadialMenuOverlayState>();
  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;

  void _openMenu() {
    if (_isMenuOpen) return;
    
    HapticFeedback.mediumImpact();
    
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset fabGlobalPosition = renderBox.localToGlobal(Offset.zero);
    
    _overlayEntry = _createOverlayEntry(fabGlobalPosition);
    Overlay.of(context).insert(_overlayEntry!);
    
    setState(() {
      _isMenuOpen = true;
    });
  }

  void _closeMenu() {
    if (!_isMenuOpen) return;
    
    _overlayEntry?.remove();
    _overlayEntry = null;
    
    setState(() {
      _isMenuOpen = false;
    });
  }

  OverlayEntry _createOverlayEntry(Offset fabGlobalPosition) {
    return OverlayEntry(
      builder: (context) => RadialMenuOverlay(
        key: _overlayKey,
        link: _layerLink,
        fabGlobalPosition: fabGlobalPosition,
        onClose: _closeMenu,
        onImportFile: widget.onImportFile,
        onCreateFolder: widget.onCreateFolder,
        onCreateNote: widget.onCreateNote,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onLongPress: _openMenu,
        onLongPressMoveUpdate: (details) => _overlayKey.currentState?.updateDragPosition(details.globalPosition),
        onLongPressEnd: (_) => _overlayKey.currentState?.handleDragEnd(),
        onTap: widget.onCreateNote,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _isMenuOpen ? Theme.of(context).colorScheme.primary : Theme.of(context).floatingActionButtonTheme.backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.edit, color: _isMenuOpen ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}

class RadialMenuOverlay extends StatefulWidget {
  final LayerLink link;
  final Offset fabGlobalPosition;
  final VoidCallback onClose;
  final VoidCallback onImportFile;
  final VoidCallback onCreateFolder;
  final VoidCallback onCreateNote;

  const RadialMenuOverlay({
    super.key,
    required this.link,
    required this.fabGlobalPosition,
    required this.onClose,
    required this.onImportFile,
    required this.onCreateFolder,
    required this.onCreateNote,
  });

  @override
  State<RadialMenuOverlay> createState() => RadialMenuOverlayState();
}

class RadialMenuOverlayState extends State<RadialMenuOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  int? _hoveredIndex; // 0 = Folder, 1 = Import (Updated order for layout)

  // Configuration
  static const double _fabSize = 56.0;
  static const double _childSize = 48.0;
  static const double _expandRadius = 100.0; 

  // Angles: Left side
  final List<double> _childAngles = [
    math.pi,           // 180° (Directly Left) - Folder
    math.pi * 1.25,    // 225° (Top-Left diagonal) - Import (Upwards)
  ];

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
    _controller.forward();
  }

  void handleDragEnd() {
    if (_hoveredIndex != null) {
      _executeAction(_hoveredIndex!);
    } else {
      _close();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    // Check if we tapped on an item
    final int? tappedIndex = _hitTest(details.globalPosition);
    
    if (tappedIndex != null) {
      _executeAction(tappedIndex);
    } else {
      _close();
    }
  }

  void _executeAction(int index) {
    HapticFeedback.selectionClick();
    widget.onClose(); // Close first
    
    if (index == 0) {
      widget.onCreateFolder();
    } else if (index == 1) {
      widget.onImportFile();
    }
  }

  void _close() {
    _controller.reverse().then((_) => widget.onClose());
  }

  int? _hitTest(Offset globalPoint) {
    final Offset fabCenter = widget.fabGlobalPosition + const Offset(_fabSize / 2, _fabSize / 2);
    
    // Check main FAB (Reset selection) - Explicitly handle canceling
    if ((globalPoint - fabCenter).distance < _fabSize / 2) {
       return null; 
    }

    // Check children
    for (int i = 0; i < _childAngles.length; i++) {
      final double angle = _childAngles[i];
      final Offset childCenter = Offset(
        fabCenter.dx + _expandRadius * math.cos(angle),
        fabCenter.dy + _expandRadius * math.sin(angle),
      );
      
      if ((globalPoint - childCenter).distance < _childSize / 2 + 15) { 
        return i;
      }
    }
    return null;
  }

  void updateDragPosition(Offset globalPoint) {
    final int? newIndex = _hitTest(globalPoint);

    if (newIndex != _hoveredIndex) {
      setState(() => _hoveredIndex = newIndex);
      if (newIndex != null) HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _handleTapUp,
      onLongPressEnd: (_) => handleDragEnd(),
      onLongPressMoveUpdate: (details) => updateDragPosition(details.globalPosition),
      child: Stack(
        children: [
          // This follows the FAB position
          CompositedTransformFollower(
            link: widget.link,
            showWhenUnlinked: false,
            // Offset to center (0,0) is top-left of FAB.
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _RadialMenuContent(
                  animation: _expandAnimation,
                  hoveredIndex: _hoveredIndex,
                );
              } 
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialMenuContent extends StatelessWidget {
  final Animation<double> animation;
  final int? hoveredIndex;

  const _RadialMenuContent({
    required this.animation,
    required this.hoveredIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Visuals
        ...List.generate(2, (index) {
          final isHovered = hoveredIndex == index;
          // 0 = Folder (Left - 180), 1 = Import (TopLeft - 225)
          final double angle = index == 0 ? math.pi : math.pi * 1.25;
          
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final double dist = 100.0 * animation.value;
              final double dx = dist * math.cos(angle);
              final double dy = dist * math.sin(angle);
              
              // Center of button needs to be at (28 + dx, 28 + dy)
              return Positioned(
                left: 28 + dx - 24,
                top: 28 + dy - 24,
                child: Transform.scale(
                  scale: animation.value,
                  child: Opacity(
                    opacity: animation.value.clamp(0.0, 1.0),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: index == 0 ? const Color(0xFF8AB4F8) : const Color(0xFF81C995), // Google Blue : Google Green
                        shape: BoxShape.circle,
                        border: isHovered ? Border.all(color: Colors.white, width: 2) : null,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: isHovered ? 12 : 6, offset: const Offset(0, 2))
                        ]
                      ),
                      child: Icon(
                         index == 0 ? Icons.create_new_folder : Icons.file_upload,
                         color: Colors.black87, // Dark icons on pastel Google colors
                         size: isHovered ? 26 : 22,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
        
        // Main FAB Cover (Visual only)
        Positioned(
          left: 0, top: 0,
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.edit, color: Theme.of(context).colorScheme.onPrimary),
          ),
        ),
      ],
    );
  }
}
