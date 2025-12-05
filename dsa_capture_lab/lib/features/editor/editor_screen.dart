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

  @override
  void initState() {
    super.initState();
    // Initialize state from existing note if available
    if (widget.existingNote != null) {
      _currentNoteId = widget.existingNote!.id;
      _titleController.text = widget.existingNote!.title;
      _contentController.text = widget.existingNote!.content;
      _createdAt = widget.existingNote!.createdAt;
      _imagePath = widget.existingNote!.imagePath;
    }

    // Add listeners for auto-save
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Ensure we save on exit if there's a pending change or final state
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

    // Don't save empty notes if they haven't been created yet
    if (title.isEmpty && content.isEmpty && _currentNoteId == null) return;

    final db = ref.read(dbProvider);

    if (_currentNoteId != null) {
      // UPDATE existing
      final updatedNote = Note(
        id: _currentNoteId!,
        title: title,
        content: content,
        imagePath: _imagePath,
        folderId: widget.folderId ?? widget.existingNote?.folderId, // Keep folder consistency
        createdAt: _createdAt, 
      );
      await db.updateNote(updatedNote);
    } else {
      // CREATE new
      final newId = await db.createNote(
        title: title.isEmpty ? "Untitled Note" : title,
        content: content,
        folderId: widget.folderId,
      );
      // Update local state so next save is an UPDATE
      if (mounted) {
        setState(() {
          _currentNoteId = newId;
        });
      } else {
        _currentNoteId = newId;
      }
    }
    // Optional: Log save for debugging
    // print("Auto-saved note $_currentNoteId");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // We can just use the default back button which triggers dispose -> save
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          // Optional: A visual indicator or "Done" button that just closes
          TextButton(
             onPressed: () => Navigator.pop(context),
             child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
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