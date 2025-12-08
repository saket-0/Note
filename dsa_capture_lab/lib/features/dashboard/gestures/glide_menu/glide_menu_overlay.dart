/// Glide Menu - Enhanced Overlay
/// 
/// Isolated glide menu system for note quick actions.
/// Touch-down on hamburger → Drag up → Release to execute.
/// Errors here do not affect other features.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Menu item definition
class GlideMenuItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onExecute;
  
  const GlideMenuItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onExecute,
  });
}

/// Enhanced glide menu overlay with customizable items
class GlideMenuOverlay extends StatefulWidget {
  final Offset anchorPosition;
  final List<GlideMenuItem> items;
  final VoidCallback onClose;
  
  const GlideMenuOverlay({
    super.key,
    required this.anchorPosition,
    required this.items,
    required this.onClose,
  });
  
  @override
  State<GlideMenuOverlay> createState() => GlideMenuOverlayState();
}

class GlideMenuOverlayState extends State<GlideMenuOverlay> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int? _highlightedIndex;
  
  // Smart positioning state
  bool _isDownwardMode = false;
  double _screenHeight = 0;
  
  static const double _itemHeight = 48.0;
  static const double _menuWidth = 140.0;
  static const double _padding = 24.0;
  static const double _minSpaceRequired = 8.0; // Minimum margin from screen edge
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller, 
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateDirection();
  }
  
  void _calculateDirection() {
    // Get screen dimensions safely
    _screenHeight = MediaQuery.of(context).size.height;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    
    final totalMenuHeight = _itemHeight * widget.items.length;
    final spaceAbove = widget.anchorPosition.dy - _padding - safeAreaTop;
    
    // Determine if we need downward mode
    _isDownwardMode = spaceAbove < totalMenuHeight + _minSpaceRequired;
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  /// Update highlight based on drag distance (called by parent)
  /// dragAmountUpwards is positive when dragging up, negative when dragging down
  void updateDragY(double dragAmountUpwards) {
    if (!mounted) return;
    
    int index = -1;
    final items = widget.items;
    
    if (_isDownwardMode) {
      // DOWNWARD MODE: Menu is below anchor, user drags DOWN to select
      // dragAmountUpwards will be NEGATIVE when dragging down
      // Convert to positive "distance traveled towards menu"
      final dragDistance = -dragAmountUpwards; // Negate to get positive value for downward drag
      
      if (dragDistance > 0) {
        // Map distance to index - first item (index 0) is closest to anchor
        final directIndex = (dragDistance / _itemHeight).floor();
        if (directIndex >= 0 && directIndex < items.length) {
          index = directIndex;
        }
      }
    } else {
      // UPWARD MODE (Default): Menu is above anchor, user drags UP to select
      // Items are ordered top-to-bottom in list, but visually bottom-to-top
      // So item[last] is at bottom (closest to finger)
      
      if (dragAmountUpwards > 0) {
        final reversedIndex = (dragAmountUpwards / _itemHeight).floor();
        if (reversedIndex >= 0 && reversedIndex < items.length) {
          // Reverse the index since items are rendered top-to-bottom
          index = items.length - 1 - reversedIndex;
        }
      }
    }
    
    if (index != _highlightedIndex) {
      setState(() => _highlightedIndex = index);
      if (index >= 0 && index < items.length) {
        HapticFeedback.selectionClick();
      }
    }
  }
  
  /// Execute highlighted action and close
  void executeAndClose() {
    if (_highlightedIndex != null && 
        _highlightedIndex! >= 0 && 
        _highlightedIndex! < widget.items.length) {
      // In downward mode, items are reversed, so we need to map back to original index
      final actualIndex = _isDownwardMode 
          ? widget.items.length - 1 - _highlightedIndex! 
          : _highlightedIndex!;
      widget.items[actualIndex].onExecute();
    }
    _close();
  }
  
  void _close() {
    _controller.reverse().then((_) => widget.onClose());
  }
  
  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final totalHeight = _itemHeight * items.length;
    
    // Calculate horizontal position (centered, clamped to screen)
    final screenWidth = MediaQuery.of(context).size.width;
    final leftPos = (widget.anchorPosition.dx - (_menuWidth / 2))
        .clamp(_minSpaceRequired, screenWidth - _menuWidth - _minSpaceRequired);
    
    // Calculate vertical position based on direction mode
    double topPos;
    Alignment scaleAlignment;
    
    if (_isDownwardMode) {
      // Render BELOW anchor
      topPos = widget.anchorPosition.dy + _padding;
      scaleAlignment = Alignment.topCenter; // Scale from top (where anchor is)
    } else {
      // Render ABOVE anchor (default)
      topPos = widget.anchorPosition.dy - totalHeight - _padding;
      scaleAlignment = Alignment.bottomCenter; // Scale from bottom (where anchor is)
    }
    
    // Clamp to screen bounds
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    topPos = topPos.clamp(
      safeAreaTop + _minSpaceRequired, 
      _screenHeight - totalHeight - safeAreaBottom - _minSpaceRequired,
    );
    
    // Build items - in downward mode, REVERSE order so "Pin" (last item) is closest to anchor
    // In upward mode, items render top-to-bottom but "Pin" is at bottom (closest to finger)
    final orderedItems = _isDownwardMode ? items.reversed.toList() : items;
    
    return Positioned(
      top: topPos,
      left: leftPos,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: scaleAlignment,
        child: Container(
          width: _menuWidth,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(orderedItems.length, (i) {
                final isFirst = i == 0;
                final isLast = i == orderedItems.length - 1;
                return _buildItem(orderedItems[i], i, isFirst, isLast);
              }),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildItem(GlideMenuItem item, int index, bool isFirst, bool isLast) {
    final isHighlighted = _highlightedIndex == index;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: _itemHeight,
      decoration: BoxDecoration(
        color: isHighlighted ? item.color.withOpacity(0.9) : Colors.transparent,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(14) : Radius.zero,
          bottom: isLast ? const Radius.circular(14) : Radius.zero,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(
            item.icon, 
            color: isHighlighted ? Colors.white : Colors.white70, 
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                color: isHighlighted ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                decoration: TextDecoration.none,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Default menu items factory
class GlideMenuItems {
  /// Menu for text notes: [Delete, Archive, Share, Color, Pin/Unpin]
  static List<GlideMenuItem> forTextNote({
    required VoidCallback onPin,
    required VoidCallback onColor,
    required VoidCallback onShare,
    required VoidCallback onArchive,
    required VoidCallback onDelete,
    bool isPinned = false,
  }) {
    return [
      GlideMenuItem(
        label: 'Delete',
        icon: Icons.delete_outline,
        color: Colors.red.shade400,
        onExecute: onDelete,
      ),
      GlideMenuItem(
        label: 'Archive',
        icon: Icons.archive_outlined,
        color: Colors.grey.shade600,
        onExecute: onArchive,
      ),
      GlideMenuItem(
        label: 'Share',
        icon: Icons.share_outlined,
        color: Colors.blue.shade400,
        onExecute: onShare,
      ),
      GlideMenuItem(
        label: 'Color',
        icon: Icons.palette_outlined,
        color: Colors.purple.shade400,
        onExecute: onColor,
      ),
      GlideMenuItem(
        label: isPinned ? 'Unpin' : 'Pin',
        icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        color: Colors.amber.shade600,
        onExecute: onPin,
      ),
    ];
  }
  
  /// Menu for image notes: [Delete, Archive, Share, Rename, Pin/Unpin]
  static List<GlideMenuItem> forImageNote({
    required VoidCallback onPin,
    required VoidCallback onRename,
    required VoidCallback onShare,
    required VoidCallback onArchive,
    required VoidCallback onDelete,
    bool isPinned = false,
  }) {
    return [
      GlideMenuItem(
        label: 'Delete',
        icon: Icons.delete_outline,
        color: Colors.red.shade400,
        onExecute: onDelete,
      ),
      GlideMenuItem(
        label: 'Archive',
        icon: Icons.archive_outlined,
        color: Colors.grey.shade600,
        onExecute: onArchive,
      ),
      GlideMenuItem(
        label: 'Share',
        icon: Icons.share_outlined,
        color: Colors.blue.shade400,
        onExecute: onShare,
      ),
      GlideMenuItem(
        label: 'Rename',
        icon: Icons.edit_outlined,
        color: Colors.orange.shade400,
        onExecute: onRename,
      ),
      GlideMenuItem(
        label: isPinned ? 'Unpin' : 'Pin',
        icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        color: Colors.amber.shade600,
        onExecute: onPin,
      ),
    ];
  }
  
  /// Menu for folders: [Delete, Archive, Share, Rename, Pin/Unpin]
  static List<GlideMenuItem> forFolder({
    required VoidCallback onPin,
    required VoidCallback onRename,
    required VoidCallback onShare,
    required VoidCallback onArchive,
    required VoidCallback onDelete,
    bool isPinned = false,
  }) {
    return [
      GlideMenuItem(
        label: 'Delete',
        icon: Icons.delete_outline,
        color: Colors.red.shade400,
        onExecute: onDelete,
      ),
      GlideMenuItem(
        label: 'Archive',
        icon: Icons.archive_outlined,
        color: Colors.grey.shade600,
        onExecute: onArchive,
      ),
      GlideMenuItem(
        label: 'Share',
        icon: Icons.share_outlined,
        color: Colors.blue.shade400,
        onExecute: onShare,
      ),
      GlideMenuItem(
        label: 'Rename',
        icon: Icons.edit_outlined,
        color: Colors.orange.shade400,
        onExecute: onRename,
      ),
      GlideMenuItem(
        label: isPinned ? 'Unpin' : 'Pin',
        icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        color: Colors.amber.shade600,
        onExecute: onPin,
      ),
    ];
  }
  
  /// Menu for trashed items: [Delete Forever, Restore]
  static List<GlideMenuItem> forTrash({
    required VoidCallback onRestore,
    required VoidCallback onDeleteForever,
  }) {
    return [
      GlideMenuItem(
        label: 'Forever',
        icon: Icons.delete_forever,
        color: Colors.redAccent,
        onExecute: onDeleteForever,
      ),
      GlideMenuItem(
        label: 'Restore',
        icon: Icons.restore,
        color: Colors.tealAccent,
        onExecute: onRestore,
      ),
    ];
  }
  
  /// Menu for archived items: [Delete, Unarchive]
  static List<GlideMenuItem> forArchived({
    required VoidCallback onUnarchive,
    required VoidCallback onDelete,
  }) {
    return [
      GlideMenuItem(
        label: 'Delete',
        icon: Icons.delete_outline,
        color: Colors.red.shade400,
        onExecute: onDelete,
      ),
      GlideMenuItem(
        label: 'Unarchive',
        icon: Icons.unarchive,
        color: Colors.amberAccent,
        onExecute: onUnarchive,
      ),
    ];
  }
  /// Legacy alias for forTextNote
  static List<GlideMenuItem> forNote({
    required VoidCallback onPin,
    required VoidCallback onColor,
    required VoidCallback onShare,
    required VoidCallback onArchive,
    required VoidCallback onDelete,
    bool isPinned = false,
  }) => forTextNote(onPin: onPin, onColor: onColor, onShare: onShare, onArchive: onArchive, onDelete: onDelete, isPinned: isPinned);
}
