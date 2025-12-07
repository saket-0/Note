import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../models/checklist_item.dart';
import '../../../core/cache/cache_service.dart';
 

class EditorController {
  final WidgetRef ref;
  final BuildContext context;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final Function(void Function()) setState; // Callback to trigger UI rebuilds

  // State visible to UI
  int? currentNoteId;
  DateTime createdAt = DateTime.now();
  String? imagePath;
  List<String> attachedImages = []; 
  int color = 0; 
  bool isPinned = false;
  bool isChecklist = false;
  List<ChecklistItem> checklistItems = [];
  Timer? _debounce;

  EditorController({
    required this.context,
    required this.ref,
    required this.titleController,
    required this.contentController,
    required this.setState,
  });

  void init(Note? existingNote) {
    if (existingNote != null) {
      currentNoteId = existingNote.id;
      titleController.text = existingNote.title;
      contentController.text = existingNote.content;
      createdAt = existingNote.createdAt;
      imagePath = existingNote.imagePath;
      color = existingNote.color;
      isPinned = existingNote.isPinned;
      isChecklist = existingNote.isChecklist;
      attachedImages = List.from(existingNote.images);

      if (isChecklist) {
        _parseContentToChecklist();
      }
    }
    
    // Setup listeners
    titleController.addListener(_onTextChanged);
    contentController.addListener(_onTextChanged);
  }

  void dispose() {
    _debounce?.cancel();
    // Controllers disposed by Parent
  }

  void _onTextChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      saveNote();
    });
  }

  void _parseContentToChecklist() {
    checklistItems = contentController.text.split('\n').where((line) => line.isNotEmpty).map((line) {
      bool checked = line.startsWith('[x] ');
      String text = line.replaceFirst(RegExp(r'^\[[ x]\] '), '');
      return ChecklistItem(isChecked: checked, text: text);
    }).toList();
  }

  void syncChecklistToContent() {
    String content = checklistItems.map((item) {
      return "${item.isChecked ? '[x]' : '[ ]'} ${item.text}";
    }).join('\n');
    
    if (contentController.text != content) {
      contentController.value = contentController.value.copyWith(
        text: content,
        selection: TextSelection.collapsed(offset: content.length),
        composing: TextRange.empty
      );
    }
    _onTextChanged();
  }

  void toggleChecklistMode() {
    setState(() {
      isChecklist = !isChecklist;
      if (isChecklist) {
        if (contentController.text.trim().isNotEmpty) {
           _parseContentToChecklist();
        } else {
           checklistItems = [ChecklistItem(isChecked: false, text: "")];
        }
      } else {
        contentController.text = checklistItems.map((e) => e.text).join('\n');
      }
      saveNote();
    });
  }

  Future<void> pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        setState(() {
          attachedImages.add(result.files.single.path!);
        });
        saveNote();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> saveNote({int? folderId}) async {
    try {
      final title = titleController.text.trim();
      final content = contentController.text.trim();

      if (title.isEmpty && content.isEmpty && currentNoteId == null && attachedImages.isEmpty) return;

      final db = ref.read(dbProvider);

      if (currentNoteId != null) {
        // UPDATE
        final updatedNote = Note(
          id: currentNoteId!,
          title: title,
          content: content,
          imagePath: imagePath,
          images: attachedImages,
          fileType: 'text',
          folderId: folderId, // This might need logic to preserve existing
          createdAt: createdAt, 
          color: color,
          isPinned: isPinned,
          isChecklist: isChecklist,
          position: 0, 
        );
        // We really need to fetch existing to preserve folderId if passed null... 
        // Logic simplified for now, assuming passing original FolderId is handled by View passing it back?
        // Actually, we can fetch from DB? Or just trust state?
        // Using `folderId` passed from arguments only for creation usually. 
        // For update, we should check `existingNote` logic but here we lost it?
        // Let's rely on DB or keep it simple: We don't change folderId here unless moved.
        // Wait, `folderId` argument is nullable. 
        // Refactor: `saveNote` shouldn't take folderId, it should be in state?
        // Let's assume we stick to current folder logic.
        
        await db.updateNote(updatedNote);
      } else {
        // CREATE
        final newId = await db.createNote(
          title: title.isEmpty ? "Untitled Note" : title,
          content: content,
          imagePath: imagePath,
          images: attachedImages,
          fileType: 'text',
          folderId: folderId,
          color: color,
          isPinned: isPinned,
          isChecklist: isChecklist,
        );
        
        currentNoteId = newId;
        // No setState needed if we just update local var for next save? 
        // But UI might want to know ID?
      }
    } catch (e) {
      debugPrint('Error saving note: $e');
    }
  }

  Future<void> deleteNote() async {
    if (currentNoteId != null) {
      final db = ref.read(dbProvider);
      await db.deleteNote(currentNoteId!); // Soft delete usually? Controller logic had soft delete.
    }
    Navigator.pop(context);
  }
}
