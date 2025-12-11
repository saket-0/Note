import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/data/notes_repository.dart';
import '../../../shared/database/drift/app_database.dart';
import '../../../shared/services/image_optimization_service.dart';
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
  String? thumbnailPath;  // NEW: Compressed thumbnail path for grid display
  List<String> attachedImages = [];
  int color = 0;
  bool isPinned = false;
  bool isChecklist = false;
  int position = 0;
  int? folderId;
  List<ChecklistItem> checklistItems = [];

  // Logic
  Timer? _saveDebounce;
  Timer? _historyDebounce;
  final HistoryStack<String> _history = HistoryStack();
  bool _isInternalChange = false;
  bool _isSaving = false;  // Prevent concurrent saves

  EditorController({
    required this.context,
    required this.ref,
    required this.titleController,
    required this.contentController,
    required this.setState,
  });

  NotesRepository get _repo => ref.read(notesRepositoryProvider);
  ImageOptimizationService get _imageService => ref.read(imageOptimizationServiceProvider);

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void init(Note? existingNote, int? initialFolderId) {
    folderId = initialFolderId;
    
    if (existingNote != null) {
      currentNoteId = existingNote.id;
      titleController.text = existingNote.title;
      contentController.load(existingNote.content);
      
      createdAt = existingNote.createdAt;
      imagePath = existingNote.imagePath;
      thumbnailPath = existingNote.thumbnailPath;  // Load existing thumbnail
      color = existingNote.color;
      isPinned = existingNote.isPinned;
      isChecklist = existingNote.isChecklist;
      position = existingNote.position;
      folderId = existingNote.folderId;
      
      // Load attached images from note_images table
      _loadNoteImages(existingNote.id);

      if (isChecklist) {
        _parseContentToChecklist();
      }
    }

    _history.push(contentController.serialize());
    titleController.addListener(_onTitleChanged);
    contentController.addListener(_onContentChanged);
  }
  
  Future<void> _loadNoteImages(int noteId) async {
    final images = await _repo.getNoteImages(noteId);
    setState(() {
      attachedImages = List.from(images);
    });
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

    _scheduleSave();

    if (_historyDebounce?.isActive ?? false) _historyDebounce!.cancel();
    _historyDebounce = Timer(const Duration(milliseconds: 500), () {
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
    _onContentChanged();
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
          checklistItems = [ChecklistItem(isChecked: false, text: '')];
        }
      } else {
        contentController.text = ChecklistUtils.toContent(checklistItems);
      }
      saveNote();
    });
  }

  /// Pick an image and generate a thumbnail for grid display.
  /// 
  /// The original image is stored at full resolution for editing.
  /// A compressed thumbnail (300px, 80% quality) is generated for dashboard grid.
  Future<void> pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final originalPath = result.files.single.path!;
        
        // Generate compressed thumbnail for grid display
        final generatedThumbnail = await _imageService.generateThumbnail(originalPath);
        
        setState(() {
          attachedImages.add(originalPath);
          
          // Set as primary image and thumbnail if this is the first image
          if (imagePath == null) {
            imagePath = originalPath;
            thumbnailPath = generatedThumbnail;
          }
        });
        
        debugPrint('[EditorController] Added image: $originalPath');
        debugPrint('[EditorController] Thumbnail: $generatedThumbnail');
        
        saveNote();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> saveNote() async {
    // Prevent concurrent saves
    if (_isSaving) return;
    _isSaving = true;
    
    try {
      final title = titleController.text.trim();
      final content = contentController.serialize();

      if (title.isEmpty && contentController.text.isEmpty && currentNoteId == null && attachedImages.isEmpty) {
        _isSaving = false;
        return;
      }

      if (currentNoteId != null && currentNoteId! > 0) {
        // UPDATE existing note
        final existingNote = await _repo.getNote(currentNoteId!);
        if (existingNote != null) {
          final updatedNote = Note(
            id: currentNoteId!,
            title: title.isEmpty ? 'Untitled' : title,
            content: content,
            thumbnailPath: thumbnailPath,
            imagePath: imagePath,
            fileType: 'rich_text',
            folderId: folderId,
            isPinned: isPinned,
            position: position,
            color: color,
            isChecklist: isChecklist,
            isArchived: existingNote.isArchived,
            isDeleted: existingNote.isDeleted,
            createdAt: createdAt,
          );

          await _repo.updateNote(updatedNote, images: attachedImages);
        }
        
        _isSaving = false;
        
      } else {
        // CREATE new note
        final realId = await _repo.createNote(
          title: title.isEmpty ? 'Untitled' : title,
          content: content,
          thumbnailPath: thumbnailPath,
          imagePath: imagePath,
          images: attachedImages,
          fileType: 'rich_text',
          folderId: folderId,
          color: color,
          isPinned: isPinned,
          isChecklist: isChecklist,
        );
        
        currentNoteId = realId;
        _isSaving = false;
      }
    } catch (e) {
      debugPrint('Error saving note: $e');
      _isSaving = false;
    }
  }

  Future<void> deleteNote() async {
    if (currentNoteId != null) {
      await _repo.deleteNote(currentNoteId!, permanent: false);
    }
    if (context.mounted) {
      Navigator.pop(context);
    }
  }
}
