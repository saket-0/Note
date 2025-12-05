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

  @override
  void initState() {
    super.initState();
    // Pre-fill if editing
    if (widget.existingNote != null) {
      _titleController.text = widget.existingNote!.title;
      _contentController.text = widget.existingNote!.content;
    }
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) return;

    final db = ref.read(dbProvider);

    if (widget.existingNote != null) {
      // UPDATE existing
      final updatedNote = Note(
        id: widget.existingNote!.id,
        title: title,
        content: content,
        imagePath: widget.existingNote!.imagePath,
        folderId: widget.existingNote!.folderId,
        createdAt: widget.existingNote!.createdAt, // Keep original date or update? Keep for now.
      );
      await db.updateNote(updatedNote);
    } else {
      // CREATE new
      await db.createNote(
        title: title.isEmpty ? "Untitled Note" : title,
        content: content,
        folderId: widget.folderId,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Note saved!")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: _saveNote,
            icon: const Icon(Icons.check),
            tooltip: 'Save',
          )
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
              DateFormat.yMMMd().format(DateTime.now()),
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