import 'package:flutter/material.dart';

class EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isPinned;
  final bool isChecklist;
  final VoidCallback onPinToggle;
  final VoidCallback onChecklistToggle;
  final VoidCallback onDelete;
  final Color contentColor;

  const EditorAppBar({
    super.key,
    required this.isPinned,
    required this.isChecklist,
    required this.onPinToggle,
    required this.onChecklistToggle,
    required this.onDelete,
    this.contentColor = Colors.black87,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: contentColor),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            color: isPinned ? Theme.of(context).colorScheme.primary : contentColor,
          ),
          onPressed: onPinToggle,
        ),
        IconButton(
          icon: Icon(
            isChecklist ? Icons.check_box : Icons.check_box_outlined,
            color: contentColor,
          ),
          onPressed: onChecklistToggle,
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: contentColor),
          onPressed: onDelete,
        ),
      ],
    );
  }
}
