/// Selection App Bar Widget
/// 
/// The contextual action bar shown during selection mode.
/// Replaces the search bar with bulk action controls.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dashboard_state.dart';
import '../selection.dart';

/// The "Action Mode" app bar shown when items are selected.
/// 
/// Features:
/// - Close button (X) to exit selection mode
/// - Selection count display
/// - Action buttons: Pin, Color, Archive, Delete
class SelectionAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final VoidCallback? onClose;
  
  const SelectionAppBar({super.key, this.onClose});
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(selectionCountProvider);
    final controller = ref.read(selectionControllerProvider);
    
    return AppBar(
      backgroundColor: const Color(0xFF3C4043), // Darker to indicate mode change
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () {
          HapticFeedback.lightImpact();
          controller.clearSelection();
          onClose?.call();
        },
        tooltip: 'Exit Selection',
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: Text(
          '$count',
          key: ValueKey(count),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      actions: [
        // Group into Folder Button
        IconButton(
          icon: const Icon(Icons.create_new_folder_outlined, color: Colors.white),
          onPressed: () => _showGroupDialog(context, ref, controller, count),
          tooltip: 'Group into Folder',
        ),
        // Pin Button
        IconButton(
          icon: const Icon(Icons.push_pin_outlined, color: Colors.white),
          onPressed: () async {
            HapticFeedback.mediumImpact();
            await controller.pinSelectedItems(true);
            _showSnackbar(context, 'Pinned $count items');
          },
          tooltip: 'Pin',
        ),
        // Color Palette Button
        IconButton(
          icon: const Icon(Icons.palette_outlined, color: Colors.white),
          onPressed: () => _showColorPicker(context, ref, controller, count),
          tooltip: 'Change Color',
        ),
        // Archive Button
        IconButton(
          icon: const Icon(Icons.archive_outlined, color: Colors.white),
          onPressed: () async {
            HapticFeedback.mediumImpact();
            await controller.archiveSelectedItems(true);
            _showSnackbar(context, 'Archived $count items');
          },
          tooltip: 'Archive',
        ),
        // Delete Button
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _confirmDelete(context, ref, controller, count),
          tooltip: 'Delete',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
  
  void _showGroupDialog(BuildContext context, WidgetRef ref, SelectionController controller, int count) {
    final textController = TextEditingController(text: 'New Folder');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Create Folder', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group $count items into a new folder',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Folder Name',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final folderName = textController.text.trim();
              if (folderName.isEmpty) {
                _showSnackbar(context, 'Folder name cannot be empty');
                return;
              }
              
              final currentFolderId = ref.read(currentFolderProvider);
              final folderId = await controller.groupSelectedIntoFolder(
                folderName,
                currentFolderId,
              );
              
              if (folderId != null && context.mounted) {
                _showSnackbar(context, 'Created folder "$folderName" with $count items');
              } else if (context.mounted) {
                _showSnackbar(context, 'Failed to create folder. Please try again.');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  
  void _showColorPicker(BuildContext context, WidgetRef ref, SelectionController controller, int count) {
    final colors = [
      Colors.transparent, // Default/No color
      const Color(0xFFFFF59D), // Yellow
      const Color(0xFFA5D6A7), // Green
      const Color(0xFF80DEEA), // Cyan
      const Color(0xFFCE93D8), // Purple
      const Color(0xFFFFAB91), // Coral
      const Color(0xFF90CAF9), // Blue
      const Color(0xFFBCAAA4), // Brown
    ];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF202124),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Color',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.map((color) {
                final isTransparent = color == Colors.transparent;
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    HapticFeedback.selectionClick();
                    await controller.setColorForSelected(color.value);
                    if (context.mounted) {
                      _showSnackbar(context, 'Color updated for $count items');
                    }
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isTransparent ? const Color(0xFF525355) : color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: isTransparent 
                      ? const Icon(Icons.format_color_reset, color: Colors.white54, size: 20)
                      : null,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
  
  void _confirmDelete(BuildContext context, WidgetRef ref, SelectionController controller, int count) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Text('Move $count items to Trash?', style: const TextStyle(color: Colors.white)),
        content: const Text('Items will be moved to Trash.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              await controller.deleteSelectedItems(permanent: false);
              if (context.mounted) {
                _showSnackbar(context, 'Moved $count items to Trash');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Trash'),
          ),
        ],
      ),
    );
  }
  
  void _showSnackbar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message), 
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}
