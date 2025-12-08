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
  
  static const double _itemHeight = 48.0;
  static const double _menuWidth = 140.0;
  static const double _bottomPadding = 24.0;
  
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  /// Update highlight based on drag distance (called by parent)
  void updateDragY(double dragAmountUpwards) {
    if (!mounted) return;
    
    int index = -1;
    final items = widget.items;
    
    // Calculate which item is under the finger
    // Items are ordered bottom-to-top visually, but stored top-to-bottom in list
    // So item[0] is at top, item[last] is at bottom (closest to finger)
    // dragAmountUpwards increases as finger moves up
    
    final reversedIndex = (dragAmountUpwards / _itemHeight).floor();
    if (reversedIndex >= 0 && reversedIndex < items.length) {
      // Reverse the index since items are rendered top-to-bottom
      index = items.length - 1 - reversedIndex;
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
      widget.items[_highlightedIndex!].onExecute();
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
    
    // Position menu ABOVE anchor
    final topPos = widget.anchorPosition.dy - totalHeight - _bottomPadding;
    final leftPos = (widget.anchorPosition.dx - (_menuWidth / 2))
        .clamp(8.0, MediaQuery.of(context).size.width - _menuWidth - 8);
    
    return Positioned(
      top: topPos.clamp(8.0, double.infinity),
      left: leftPos,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: Alignment.bottomCenter,
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
              children: List.generate(items.length, (i) {
                final isFirst = i == 0;
                final isLast = i == items.length - 1;
                return _buildItem(items[i], i, isFirst, isLast);
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
  /// Menu for text notes: [Delete, Archive, Share, Color, Pin]
  static List<GlideMenuItem> forTextNote({
    required VoidCallback onPin,
    required VoidCallback onColor,
    required VoidCallback onShare,
    required VoidCallback onArchive,
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
        label: 'Pin',
        icon: Icons.push_pin_outlined,
        color: Colors.amber.shade600,
        onExecute: onPin,
      ),
    ];
  }
  
  /// Menu for image notes: [Delete, Archive, Share, Rename, Pin]
  static List<GlideMenuItem> forImageNote({
    required VoidCallback onPin,
    required VoidCallback onRename,
    required VoidCallback onShare,
    required VoidCallback onArchive,
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
        label: 'Pin',
        icon: Icons.push_pin_outlined,
        color: Colors.amber.shade600,
        onExecute: onPin,
      ),
    ];
  }
  
  /// Menu for folders: [Delete, Archive, Share, Rename, Pin]
  static List<GlideMenuItem> forFolder({
    required VoidCallback onPin,
    required VoidCallback onRename,
    required VoidCallback onShare,
    required VoidCallback onArchive,
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
        label: 'Pin',
        icon: Icons.push_pin_outlined,
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
  }) => forTextNote(onPin: onPin, onColor: onColor, onShare: onShare, onArchive: onArchive, onDelete: onDelete);
}
