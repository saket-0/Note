import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/data/notes_repository.dart';
import '../../shared/database/drift/app_database.dart';
import 'controllers/editor_controller.dart';
import 'models/checklist_item.dart';
import 'widgets/editor_app_bar.dart';
import 'widgets/editor_canvas.dart';
import 'widgets/editor_toolbar.dart';
import 'controllers/rich_text_controller.dart';
import 'models/formatting_span.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final int? folderId;
  final int? existingNoteId;  // Pass ID for fresh fetch from DB
  
  // Legacy support: still accept Note object
  final Note? existingNote;

  const EditorScreen({
    super.key, 
    this.folderId, 
    this.existingNoteId,
    this.existingNote,
  });

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _titleController = TextEditingController();
  late RichTextController _contentController; 
  late EditorController _controller;
  
  bool _isLoading = true;
  Note? _loadedNote;

  bool _showFormattingToolbar = false;

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
    _contentController = RichTextController();
    _contentController.addListener(_onSelectionChanged);
    _controller = EditorController(
      context: context, 
      ref: ref, 
      titleController: _titleController, 
      contentController: _contentController,
      setState: (fn) {
        if (mounted) setState(fn);
      }
    );
    
    _initializeNote();
  }
  
  Future<void> _initializeNote() async {
    Note? noteToLoad;
    
    // Priority 1: Fetch by ID (fresh from DB)
    if (widget.existingNoteId != null) {
      final repo = ref.read(notesRepositoryProvider);
      noteToLoad = await repo.getNote(widget.existingNoteId!);
    }
    // Priority 2: Use passed Note object (legacy support)
    else if (widget.existingNote != null) {
      noteToLoad = widget.existingNote;
    }
    
    _loadedNote = noteToLoad;
    _controller.init(noteToLoad, widget.folderId);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _contentController.removeListener(_onSelectionChanged);
    _controller.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  void _showColorPicker() {
     // ... (unchanged)
  }

  void _showFormatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF303134),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return ValueListenableBuilder(
          valueListenable: _contentController,
          builder: (context, value, child) {
              final styles = _contentController.currentStyles;
              return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFormatOption(label: "H1", onTap: _controller.formatH1, isActive: styles.contains(StyleType.header1)),
                    const SizedBox(width: 12),
                    _buildFormatOption(label: "H2", onTap: _controller.formatH2, isActive: styles.contains(StyleType.header2)),
                    const SizedBox(width: 12),
                    Container(width: 1, height: 24, color: Colors.white24), // Separator
                    const SizedBox(width: 12),
                    _buildFormatOption(icon: Icons.format_bold, onTap: _controller.formatBold, isActive: styles.contains(StyleType.bold)),
                    const SizedBox(width: 12),
                    _buildFormatOption(icon: Icons.format_italic, onTap: _controller.formatItalic, isActive: styles.contains(StyleType.italic)),
                    const SizedBox(width: 12),
                    _buildFormatOption(icon: Icons.format_underlined, onTap: _controller.formatUnderline, isActive: styles.contains(StyleType.underline)),
                    const SizedBox(width: 12),
                    Container(width: 1, height: 24, color: Colors.white24), // Separator
                    const SizedBox(width: 12),
                    _buildFormatOption(icon: Icons.format_clear, onTap: _controller.clearFormatting),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildFormatOption({IconData? icon, String? label, required VoidCallback onTap, bool isActive = false}) {
    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
        ),
        child: icon != null 
          ? Icon(icon, color: isActive ? Colors.white : Theme.of(context).colorScheme.primary, size: 24)
          : Text(
              label ?? "", 
              style: TextStyle(
                color: isActive ? Colors.white : Theme.of(context).colorScheme.primary, 
                fontWeight: FontWeight.bold,
                fontSize: 16
              )
            ),
      ),
    );
  }

  void _toggleFormatToolbar() {
    setState(() {
      _showFormattingToolbar = !_showFormattingToolbar;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Show loading while fetching note
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    final Color bgColor = _controller.color == 0 
        ? Theme.of(context).scaffoldBackgroundColor 
        : Color(_controller.color);
    final bool isDark = bgColor.computeLuminance() < 0.5;
    final Color contentColor = isDark ? const Color(0xFFE8EAED) : Colors.black87;
    
    final bool isNewNote = _loadedNote == null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
         if (didPop) return;
         await _controller.saveNote();
         if (mounted) {
           Navigator.pop(context);
         }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        resizeToAvoidBottomInset: true, 
        appBar: EditorAppBar(
          isPinned: _controller.isPinned,
          isChecklist: _controller.isChecklist,
          onPinToggle: () {
            setState(() => _controller.isPinned = !_controller.isPinned);
            _controller.saveNote();
          },
          onChecklistToggle: _controller.toggleChecklistMode,
          onDelete: _controller.deleteNote,
          contentColor: contentColor,
        ),
        body: Column(
          children: [
            Expanded(
              child: EditorCanvas(
                titleController: _titleController,
                contentController: _contentController,
                checklistItems: _controller.checklistItems,
                isChecklist: _controller.isChecklist,
                attachedImages: _controller.attachedImages,
                createdAt: _controller.createdAt,
                isNewNote: isNewNote,
                onImageRemove: (index) {
                  setState(() => _controller.attachedImages.removeAt(index));
                  _controller.saveNote();
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
            ),
            EditorToolbar(
              onAddImage: _controller.pickImage,
              onColorPalette: _showColorPicker,
              onFormatToggle: _toggleFormatToolbar,
              onUndo: _controller.undo, 
              onRedo: _controller.redo,
              canUndo: _controller.canUndo,
              canRedo: _controller.canRedo,
              contentColor: contentColor,
              isFormattingMode: _showFormattingToolbar,
              activeStyles: _contentController.currentStyles,
              onH1: _controller.formatH1,
              onH2: _controller.formatH2,
              onBold: _controller.formatBold,
              onItalic: _controller.formatItalic,
              onUnderline: _controller.formatUnderline,
              onClearFormatting: _controller.clearFormatting,
            ),
          ],
        ),
      ),
    );
  }
}