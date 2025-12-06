import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';

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
  int _color = 0; // Default transparent/glass
  bool _isPinned = false;

  final List<Color> _noteColors = [
    Colors.transparent, // Default
    const Color(0xFFFAAFA8), // Red
    const Color(0xFFF39F76), // Orange
    const Color(0xFFFFF8B8), // Yellow
    const Color(0xFFE2F6D3), // Green
    const Color(0xFFB4DDD3), // Teal
    const Color(0xFFD4E4ED), // Blue
    const Color(0xFFAECCDC), // Dark Blue
    const Color(0xFFD3BFDB), // Purple
    const Color(0xFFF6E2DD), // Pink
    const Color(0xFFE9E3D4), // Brown
    const Color(0xFFEFEFF1), // Grey
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
    }
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  // ... (dispose and onTextChanged remain same)
  @override
  void dispose() {
    _debounce?.cancel();
    _saveNote(); 
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
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty && _currentNoteId == null) return;

    final db = ref.read(dbProvider);

    if (_currentNoteId != null) {
      final updatedNote = Note(
        id: _currentNoteId!,
        title: title,
        content: content,
        imagePath: _imagePath,
        folderId: widget.folderId ?? widget.existingNote?.folderId,
        createdAt: _createdAt, 
        color: _color,
        isPinned: _isPinned,
      );
      await db.updateNote(updatedNote);
    } else {
      final newId = await db.createNote(
        title: title.isEmpty ? "Untitled Note" : title,
        content: content,
        folderId: widget.folderId,
        color: _color,
        isPinned: _isPinned,
      );
      if (mounted) {
        setState(() {
          _currentNoteId = newId;
        });
      } else {
        _currentNoteId = newId;
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
            color: Color(0xFF1E1E1E), // Dark grey
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
                    _saveNote(); // Save immediately
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
    // Determine background color for editor
    Color bgColor = _color == 0 ? Colors.transparent : Color(_color);
    // If transparent, we might want white for light mode or stick to transparent for dark theme consistency?
    // Since app is dark theme, if color is set, we use it. If not, we use transparent (which shows app background).
    // Note: If user picks valid color, it overrides background.
    
    return Scaffold(
      backgroundColor: bgColor == Colors.transparent ? null : bgColor, // Null fallback to theme/transparent
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _isPinned ? Colors.blueAccent : null,
            ),
            onPressed: () {
               setState(() => _isPinned = !_isPinned);
               _saveNote();
            },
          ),
          IconButton(
            icon: const Icon(Icons.color_lens_outlined),
            onPressed: _showColorPicker,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat.yMMMd().format(_createdAt),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Start typing...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}