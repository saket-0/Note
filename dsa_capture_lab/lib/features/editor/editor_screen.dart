import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import 'controllers/editor_controller.dart';
import 'models/checklist_item.dart';
import 'widgets/editor_app_bar.dart';
import 'widgets/editor_canvas.dart';
import 'widgets/editor_toolbar.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final int? folderId;
  final Note? existingNote;

  const EditorScreen({super.key, this.folderId, this.existingNote});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  late EditorController _controller;

  final List<Color> _noteColors = [
    Colors.transparent, // Default (Theme Background)
    const Color(0xFF5C2B29), // Dark Red
    const Color(0xFF614A19), // Dark Orange/Brown
    const Color(0xFF635D19), // Dark Yellow
    const Color(0xFF345920), // Dark Green
    const Color(0xFF16504B), // Dark Teal
    const Color(0xFF2D555E), // Dark Blue Grey
    const Color(0xFF1E3A5F), // Dark Blue
    const Color(0xFF42275E), // Dark Purple
    const Color(0xFF5B2245), // Dark Pink
    const Color(0xFF442F19), // Dark Brown
    const Color(0xFF3C3F41), // Grey
  ];

  @override
  void initState() {
    super.initState();
    _controller = EditorController(
      context: context, 
      ref: ref, 
      titleController: _titleController, 
      contentController: _contentController,
      setState: (fn) {
        if (mounted) setState(fn);
      }
    );
    _controller.init(widget.existingNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _showColorPicker() {
     showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF303134), // Google Surface
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _noteColors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final color = _noteColors[index];
              final isSelected = _controller.color == color.value;
              return GestureDetector(
                onTap: () {
                  setState(() => _controller.color = color.value);
                  _controller.saveNote(folderId: widget.folderId);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color == Colors.transparent ? Theme.of(context).scaffoldBackgroundColor : color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white24,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: color == Colors.transparent 
                      ? const Icon(Icons.format_color_reset, color: Colors.white70, size: 20)
                      : (isSelected ? const Icon(Icons.check, color: Colors.white) : null),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Logic: If color is 0 (Transparent/Default), use Theme Scaffold (Dark #202124).
    final Color bgColor = _controller.color == 0 
        ? Theme.of(context).scaffoldBackgroundColor 
        : Color(_controller.color);
    
    // Logic: Contrast. If BG is dark (Theme), text should be White.
    // If BG is Pastel (custom color), user might want Black.
    // But since we switched to Dark Note Colors, text should likely remain White/Light Grey.
    final bool isDark = bgColor.computeLuminance() < 0.5;
    final Color contentColor = isDark ? const Color(0xFFE8EAED) : Colors.black87;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
         if (didPop) return;
         _controller.saveNote(folderId: widget.folderId);
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: EditorAppBar(
          isPinned: _controller.isPinned,
          isChecklist: _controller.isChecklist,
          onPinToggle: () {
            setState(() => _controller.isPinned = !_controller.isPinned);
            _controller.saveNote(folderId: widget.folderId);
          },
          onChecklistToggle: _controller.toggleChecklistMode,
          onDelete: _controller.deleteNote,
          contentColor: contentColor,
        ),
        body: EditorCanvas(
          titleController: _titleController,
          contentController: _contentController,
          checklistItems: _controller.checklistItems,
          isChecklist: _controller.isChecklist,
          attachedImages: _controller.attachedImages,
          createdAt: _controller.createdAt,
          onImageRemove: (index) {
            setState(() => _controller.attachedImages.removeAt(index));
            _controller.saveNote(folderId: widget.folderId);
          },
          onChecklistItemChanged: (index, val) {
            _controller.checklistItems[index].text = val;
            _controller.syncChecklistToContent();
          },
          onChecklistItemChecked: (index, val) {
            setState(() => _controller.checklistItems[index].isChecked = val);
            _controller.syncChecklistToContent();
          },
          onChecklistItemRemoved: (index) {
            setState(() => _controller.checklistItems.removeAt(index));
            _controller.syncChecklistToContent();
          },
          onChecklistItemAdded: () {
            setState(() => _controller.checklistItems.add(ChecklistItem(isChecked: false, text: "")));
            _controller.syncChecklistToContent();
          },
          contentColor: contentColor,
        ),
        bottomNavigationBar: EditorToolbar(
          onAddImage: _controller.pickImage,
          onColorPalette: _showColorPicker,
          onFormat: () {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Formatting coming soon!")));
          },
          onUndo: () {},   
          onRedo: () {},   
          contentColor: contentColor,
        ),
      ),
    );
  }
}