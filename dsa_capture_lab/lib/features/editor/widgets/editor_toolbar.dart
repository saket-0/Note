import 'package:flutter/material.dart';

class EditorToolbar extends StatelessWidget {
  final VoidCallback onAddImage;
  final VoidCallback onColorPalette;
  final VoidCallback onFormat; // Placeholder for future
  final VoidCallback onUndo; 
  final VoidCallback onRedo; 
  final Color contentColor;

  const EditorToolbar({
    super.key,
    required this.onAddImage,
    required this.onColorPalette,
    required this.onFormat,
    required this.onUndo,
    required this.onRedo,
    this.contentColor = Colors.black54,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.transparent,
      elevation: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.add_box_outlined, color: contentColor),
            onPressed: onAddImage,
            tooltip: 'Add image',
          ),
          IconButton(
            icon: Icon(Icons.palette_outlined, color: contentColor),
            onPressed: onColorPalette,
            tooltip: 'Change color',
          ),
          IconButton(
            icon: Icon(Icons.text_format, color: contentColor),
            onPressed: onFormat,
            tooltip: 'Formatting',
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.undo, color: contentColor),
            onPressed: onUndo,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: Icon(Icons.redo, color: contentColor),
            onPressed: onRedo,
            tooltip: 'Redo',
          ),
        ],
      ),
    );
  }
}
