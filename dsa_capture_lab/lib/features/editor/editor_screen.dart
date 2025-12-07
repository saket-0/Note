import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
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
  
  // Auto-save logic
  Timer? _debounce;
  int? _currentNoteId;
  DateTime _createdAt = DateTime.now();
  String? _imagePath;
  List<String> _attachedImages = []; 
  int _color = 0; 
  bool _isPinned = false;
  bool _isChecklist = false;

  List<ChecklistItem> _checklistItems = [];

  final List<Color> _noteColors = [
    Colors.transparent, 
    const Color(0xFFFAAFA8), 
    const Color(0xFFF39F76), 
    const Color(0xFFFFF8B8), 
    const Color(0xFFE2F6D3), 
    const Color(0xFFB4DDD3), 
    const Color(0xFFD4E4ED), 
    const Color(0xFFAECCDC), 
    const Color(0xFFD3BFDB), 
    const Color(0xFFF6E2DD), 
    const Color(0xFFE9E3D4), 
    const Color(0xFFEFEFF1), 
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingNote != null) {
      _currentNoteId = widget.existingNote!.id;
      _titleController.text = widget.existingNote!.title;
      _contentController.text = widget.existingNote!.content;
      _createdAt = widget.existingNote!.createdAt;
      _imagePath = widget.existingNote!.imagePath;
      _color = widget.existingNote!.color;
      _isPinned = widget.existingNote!.isPinned;
      _isChecklist = widget.existingNote!.isChecklist;
      _attachedImages = List.from(widget.existingNote!.images);

      if (_isChecklist) {
        _parseContentToChecklist();
      }
    }
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  void _parseContentToChecklist() {
    _checklistItems = _contentController.text.split('\n').where((line) => line.isNotEmpty).map((line) {
      bool checked = line.startsWith('[x] ');
      String text = line.replaceFirst(RegExp(r'^\[[ x]\] '), '');
      return ChecklistItem(isChecked: checked, text: text);
    }).toList();
  }

  void _syncChecklistToContent() {
    String content = _checklistItems.map((item) {
      return "${item.isChecked ? '[x]' : '[ ]'} ${item.text}";
    }).join('\n');
    
    // Direct update without listener loop
    if (_contentController.text != content) {
      _contentController.value = _contentController.value.copyWith(
        text: content,
        selection: TextSelection.collapsed(offset: content.length),
        composing: TextRange.empty
      );
    }
    _onTextChanged();
  }

  void _toggleChecklistMode() {
    setState(() {
      _isChecklist = !_isChecklist;
      if (_isChecklist) {
        // Converting Text -> List
        if (_contentController.text.trim().isNotEmpty) {
           _parseContentToChecklist();
        } else {
           _checklistItems = [ChecklistItem(isChecked: false, text: "")];
        }
      } else {
        // Converting List -> Text
        _contentController.text = _checklistItems.map((e) => e.text).join('\n');
      }
      _saveNote();
    });
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        setState(() {
          _attachedImages.add(result.files.single.path!);
        });
        _saveNote();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Note: Avoid async operations in dispose. Save should be synchronously queued.
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      _saveNote();
    });
  }

  Future<void> _saveNote() async {
    try {
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();

      // If completely empty, don't save
      if (title.isEmpty && content.isEmpty && _currentNoteId == null && _attachedImages.isEmpty) return;

      final db = ref.read(dbProvider);

      if (_currentNoteId != null) {
        // UPDATE existing note
        final updatedNote = Note(
          id: _currentNoteId!,
          title: title,
          content: content,
          imagePath: _imagePath,
          images: _attachedImages,
          fileType: 'text',
          folderId: widget.folderId ?? widget.existingNote?.folderId,
          createdAt: _createdAt, 
          color: _color,
          isPinned: _isPinned,
          isChecklist: _isChecklist,
          position: widget.existingNote?.position ?? 0,
          isArchived: widget.existingNote?.isArchived ?? false,
          isDeleted: widget.existingNote?.isDeleted ?? false,
        );
        await db.updateNote(updatedNote);
      } else {
        // CREATE new note
        final newId = await db.createNote(
          title: title.isEmpty ? "Untitled Note" : title,
          content: content,
          imagePath: _imagePath,
          images: _attachedImages,
          fileType: 'text',
          folderId: widget.folderId,
          color: _color,
          isPinned: _isPinned,
          isChecklist: _isChecklist,
        );
        
        if (mounted) {
          setState(() {
            _currentNoteId = newId;
          });
        } else {
          _currentNoteId = newId;
        }
      }
    } catch (e) {
      debugPrint('Error saving note: $e');
      // Silent failure for auto-save to avoid spamming user
    }
  }

  Future<void> _deleteNote() async {
    try {
      if (_currentNoteId != null) {
        final db = ref.read(dbProvider);
        final note = await db.getNote(_currentNoteId!);
        if (note != null) {
          await db.updateNote(note.copyWith(isDeleted: true));
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error deleting note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete note'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showColorPicker() {
     showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E), 
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _noteColors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final color = _noteColors[index];
                final isSelected = _color == color.value;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _color = color.value;
                    });
                    _saveNote(); 
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color == Colors.transparent ? Colors.black : color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.blueAccent : Colors.white30,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: color == Colors.transparent 
                        ? const Icon(Icons.format_color_reset, color: Colors.white, size: 20)
                        : (isSelected ? const Icon(Icons.check, color: Colors.black54) : null),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final Color bgColor = _color == 0 ? Colors.white : Color(_color);
    // Calculate contrast color: if background is light, use black text; else white
    final Color contentColor = bgColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: EditorAppBar(
        isPinned: _isPinned,
        isChecklist: _isChecklist,
        onPinToggle: () {
          setState(() => _isPinned = !_isPinned);
          _saveNote();
        },
        onChecklistToggle: _toggleChecklistMode,
        onDelete: _deleteNote,
        contentColor: contentColor,
      ),
      body: EditorCanvas(
        titleController: _titleController,
        contentController: _contentController,
        checklistItems: _checklistItems,
        isChecklist: _isChecklist,
        attachedImages: _attachedImages,
        createdAt: _createdAt,
        onImageRemove: (index) {
          setState(() => _attachedImages.removeAt(index));
          _saveNote();
        },
        onChecklistItemChanged: (index, val) {
          _checklistItems[index].text = val;
          _syncChecklistToContent();
        },
        onChecklistItemChecked: (index, val) {
          setState(() => _checklistItems[index].isChecked = val);
          _syncChecklistToContent();
        },
        onChecklistItemRemoved: (index) {
          setState(() => _checklistItems.removeAt(index));
          _syncChecklistToContent();
        },
        onChecklistItemAdded: () {
          setState(() => _checklistItems.add(ChecklistItem(isChecked: false, text: "")));
          _syncChecklistToContent();
        },
        contentColor: contentColor,
      ),
      bottomNavigationBar: EditorToolbar(
        onAddImage: _pickImage,
        onColorPalette: _showColorPicker,
        onFormat: () {}, // Future
        onUndo: () {},   // Future 
        onRedo: () {},   // Future
        contentColor: contentColor,
      ),
    );
  }
}