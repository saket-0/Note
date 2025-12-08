import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/checklist_item.dart';

class EditorCanvas extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController contentController;
  final List<ChecklistItem> checklistItems;
  final bool isChecklist;
  final List<String> attachedImages;
  final DateTime createdAt;
  final Function(int index) onImageRemove;
  final Function(int index, String val) onChecklistItemChanged;
  final Function(int index, bool val) onChecklistItemChecked;
  final Function(int index) onChecklistItemRemoved;
  final VoidCallback onChecklistItemAdded;
  final Color contentColor;
  final bool isNewNote;

  const EditorCanvas({
    super.key,
    required this.titleController,
    required this.contentController,
    required this.checklistItems,
    required this.isChecklist,
    required this.attachedImages,
    required this.createdAt,
    required this.onImageRemove,
    required this.onChecklistItemChanged,
    required this.onChecklistItemChecked,
    required this.onChecklistItemRemoved,
    required this.onChecklistItemAdded,
    this.contentColor = Colors.black87,
    this.isNewNote = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGES
            if (attachedImages.isNotEmpty)
              ...attachedImages.asMap().entries.map((entry) {
                final index = entry.key;
                final imagePath = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildSafeImage(imagePath),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => onImageRemove(index),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              
            const SizedBox(height: 16),
            
            // TITLE
            TextField(
              controller: titleController,
              cursorColor: contentColor,
              autofocus: isNewNote, // Auto-focus when creating a new note
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: contentColor,
              ),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(color: contentColor.withOpacity(0.5)),
                border: InputBorder.none,
              ),
              maxLines: null,
            ),
            const SizedBox(height: 4),
            
            // DATE
            Text(
              DateFormat.yMMMd().format(createdAt),
              style: TextStyle(color: contentColor.withOpacity(0.6), fontSize: 12),
            ),
            Divider(color: contentColor.withOpacity(0.2)),
            
            // CONTENT (Text or Checklist)
            isChecklist ? _buildChecklistEditor() : _buildTextEditor(),
            
            // Extra padding at bottom for keyboard
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  /// Safely load image with error handling
  Widget _buildSafeImage(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: contentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(Icons.broken_image, color: contentColor.withOpacity(0.5), size: 40),
        ),
      );
    }
    return Image.file(
      file,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: contentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(Icons.error_outline, color: contentColor.withOpacity(0.5), size: 40),
          ),
        );
      },
    );
  }

  Widget _buildTextEditor() {
    return TextField(
      controller: contentController,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      cursorColor: contentColor,
      style: TextStyle(color: contentColor, fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Start typing...',
        hintStyle: TextStyle(color: contentColor.withOpacity(0.5)),
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildChecklistEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checklist items
        ...checklistItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Row(
            children: [
              Checkbox(
                value: item.isChecked,
                onChanged: (val) => onChecklistItemChecked(index, val ?? false),
                activeColor: contentColor,
                checkColor: contentColor == Colors.black87 ? Colors.white : Colors.black,
                side: BorderSide(color: contentColor.withOpacity(0.5)),
              ),
              Expanded(
                child: TextFormField(
                  initialValue: item.text,
                  onChanged: (val) => onChecklistItemChanged(index, val),
                  cursorColor: contentColor,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Item",
                    hintStyle: TextStyle(color: contentColor.withOpacity(0.5)),
                  ),
                  style: TextStyle(
                    decoration: item.isChecked ? TextDecoration.lineThrough : null,
                    color: item.isChecked ? contentColor.withOpacity(0.5) : contentColor,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 16, color: contentColor.withOpacity(0.5)),
                onPressed: () => onChecklistItemRemoved(index),
              ),
            ],
          );
        }),
        // Add item button
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.add, color: contentColor.withOpacity(0.5)),
          title: Text(
            "List item", 
            style: TextStyle(color: contentColor.withOpacity(0.5)),
          ),
          onTap: onChecklistItemAdded,
        ),
      ],
    );
  }
}
