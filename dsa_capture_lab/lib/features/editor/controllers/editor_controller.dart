import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/cache/cache_service.dart';
import '../../dashboard/providers/dashboard_state.dart';
import '../models/checklist_item.dart';
import '../utils/history_stack.dart';
import 'rich_text_controller.dart';
import '../utils/checklist_utils.dart';
import '../models/formatting_span.dart';

class EditorController {
  final WidgetRef ref;
  final BuildContext context;
  final TextEditingController titleController;
  final RichTextController contentController;
  final Function(void Function()) setState; 

  // State
  int? currentNoteId;
  DateTime createdAt = DateTime.now();
  String? imagePath;
  List<String> attachedImages = []; 
  int color = 0; 
  bool isPinned = false;
  bool isChecklist = false;
  List<ChecklistItem> checklistItems = [];
  
  // Logic
  Timer? _saveDebounce;
  Timer? _historyDebounce;
  // History now stores the serialized JSON string to capture text + formatting spans
  final HistoryStack<String> _history = HistoryStack();
  bool _isInternalChange = false;

  EditorController({
    required this.context,
    required this.ref,
    required this.titleController,
    required this.contentController,
    required this.setState,
  });

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void init(Note? existingNote) {
    if (existingNote != null) {
      currentNoteId = existingNote.id;
      titleController.text = existingNote.title;
      // Load content (JSON or Text) into RichTextController
      contentController.load(existingNote.content);
      
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
    
    // Initial History State
    _history.push(contentController.serialize());

    // Setup listeners
    titleController.addListener(_onTitleChanged);
    contentController.addListener(_onContentChanged);
  }

  void dispose() {
    _saveDebounce?.cancel();
    _historyDebounce?.cancel();
  }

  void _onTitleChanged() {
    _scheduleSave();
  }

  void _onContentChanged() {
    if (_isInternalChange) return;

    // Schedule Save
    _scheduleSave();

    // Schedule History Push
    if (_historyDebounce?.isActive ?? false) _historyDebounce!.cancel();
    _historyDebounce = Timer(const Duration(milliseconds: 500), () {
      // Serialize current state (text + spans)
      final currentState = contentController.serialize();
      _history.push(currentState);
      setState(() {});
    });
  }

  void _scheduleSave() {
    if (_saveDebounce?.isActive ?? false) _saveDebounce!.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1000), () {
      saveNote();
    });
  }

  void undo() {
    if (canUndo) {
      _isInternalChange = true;
      final oldState = _history.undo();
      if (oldState != null) {
        contentController.load(oldState);
        _scheduleSave(); 
      }
      _isInternalChange = false;
      setState(() {});
    }
  }

  void redo() {
    if (canRedo) {
      _isInternalChange = true;
      final newState = _history.redo();
      if (newState != null) {
         contentController.load(newState);
         _scheduleSave();
      }
      _isInternalChange = false;
      setState(() {});
    }
  }

  void formatBold() {
    contentController.toggleStyle(StyleType.bold);
    _onContentChanged(); // Force history push
  }

  void formatItalic() {
    contentController.toggleStyle(StyleType.italic);
     _onContentChanged();
  }

  void formatUnderline() {
    contentController.toggleStyle(StyleType.underline);
     _onContentChanged();
  }

  void formatH1() {
    contentController.toggleStyle(StyleType.header1);
     _onContentChanged();
  }

  void formatH2() {
    contentController.toggleStyle(StyleType.header2);
     _onContentChanged();
  }

  void clearFormatting() {
    contentController.clearFormatting();
     _onContentChanged();
  }

  void _parseContentToChecklist() {
    checklistItems = ChecklistUtils.parse(contentController.text);
  }

  void syncChecklistToContent() {
    String content = ChecklistUtils.toContent(checklistItems);
    
    if (contentController.text != content) {
      _isInternalChange = true;
      contentController.text = content; 
      _isInternalChange = false;
      _history.push(contentController.serialize());
    }
    _scheduleSave();
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
        contentController.text = ChecklistUtils.toContent(checklistItems);
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

  Future<Note?> saveNote({int? folderId}) async {
    try {
      final title = titleController.text.trim();
      // SAVE SERIALIZED CONTENT to preserve diffs/spans
      final content = contentController.serialize();

      if (title.isEmpty && contentController.text.isEmpty && currentNoteId == null && attachedImages.isEmpty) return null;

      final db = ref.read(dbProvider);
      final cache = ref.read(cacheServiceProvider);

      if (currentNoteId != null && currentNoteId! > 0) {
        // UPDATE existing note (has real DB ID)
        final updatedNote = Note(
          id: currentNoteId!,
          title: title,
          content: content,
          imagePath: imagePath,
          images: attachedImages,
          fileType: 'rich_text',
          folderId: folderId,
          createdAt: createdAt,
          color: color,
          isPinned: isPinned,
          isChecklist: isChecklist,
          position: 0,
        );
        
        // Cache-first update for instant UI
        cache.updateNote(updatedNote);
        ref.read(refreshTriggerProvider.notifier).state++;
        
        // Background DB update (fire-and-forget)
        db.updateNote(updatedNote);
        return updatedNote;
        
      } else {
        // CREATE new note optimistically
        final tempId = currentNoteId ?? cache.generateTempId();
        final tempNote = Note(
          id: tempId,
          title: title.isEmpty ? "Untitled Note" : title,
          content: content,
          imagePath: imagePath,
          images: attachedImages,
          fileType: 'rich_text',
          folderId: folderId,
          createdAt: DateTime.now(),
          color: color,
          isPinned: isPinned,
          isChecklist: isChecklist,
          position: 999,
        );
        
        // Add to cache IMMEDIATELY for instant display
        if (currentNoteId == null) {
          cache.addNoteOptimistic(tempNote);
          currentNoteId = tempId;
        } else {
          cache.updateNote(tempNote);
        }
        ref.read(refreshTriggerProvider.notifier).state++;
        
        // Persist to DB in background (fire-and-forget)
        db.createNote(
          title: tempNote.title,
          content: content,
          imagePath: imagePath,
          images: attachedImages,
          fileType: 'rich_text',
          folderId: folderId,
          color: color,
          isPinned: isPinned,
          isChecklist: isChecklist,
        ).then((realId) {
          cache.resolveTempId(tempId, realId, isFolder: false);
          currentNoteId = realId; // Update for future saves
        });
        
        return tempNote;
      }
    } catch (e) {
      debugPrint('Error saving note: $e');
      return null;
    }
  }

  Future<void> deleteNote() async {
    if (currentNoteId != null) {
      final db = ref.read(dbProvider);
      await db.deleteNote(currentNoteId!);
    }
    Navigator.pop(context);
  }
}
