import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
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

class ChecklistItem {
  bool isChecked;
  String text;
  ChecklistItem({required this.isChecked, required this.text});
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  // Auto-save logic
  Timer? _debounce;
  int? _currentNoteId;
  DateTime _createdAt = DateTime.now();
  String? _imagePath;
  List<String> _attachedImages = []; // New Multi-images
  int _color = 0; 
  bool _isPinned = false;
  bool _isChecklist = false; // New Checklist Mode

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
        // Split by lines, assume unchecked unless marked
        if (_contentController.text.trim().isNotEmpty) {
           _parseContentToChecklist();
        } else {
           _checklistItems = [ChecklistItem(isChecked: false, text: "")];
        }
      } else {
        // Converting List -> Text
        // Already synced via _syncChecklistToContent usually, but just in case
        _contentController.text = _checklistItems.map((e) => e.text).join('\n');
      }
      _saveNote();
    });
  }

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

    if (title.isEmpty && content.isEmpty && _currentNoteId == null && _attachedImages.isEmpty) return;

    final db = ref.read(dbProvider);

    if (_currentNoteId != null) {
      final updatedNote = Note(
        id: _currentNoteId!,
        title: title,
        content: content,
        imagePath: _imagePath,
        images: _attachedImages,
        folderId: widget.folderId ?? widget.existingNote?.folderId,
        createdAt: _createdAt, 
        color: _color,
        isPinned: _isPinned,
        isChecklist: _isChecklist,
      );
      await db.updateNote(updatedNote);
    } else {
      final newId = await db.createNote(
        title: title.isEmpty ? "Untitled Note" : title,
        content: content,
        folderId: widget.folderId,
        color: _color,
        isPinned: _isPinned,
        isChecklist: _isChecklist,
        images: _attachedImages,
      );
      if (mounted) {
        setState(() {
          _currentNoteId = newId;
        });
      } else {
        _currentNoteId = newId;
      }
    }
    
    // Refresh Dashboard Logic could be triggered here or via provider watcher
    // But since dashboard uses StateNotifier load(), we might want to trigger it if popping.
    // For now, onPop handles it.
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _attachedImages.addAll(result.paths.whereType<String>());
      });
      _saveNote();
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = _color == 0 ? Colors.transparent : Color(_color);
    
    return Scaffold(
      backgroundColor: bgColor == Colors.transparent ? null : bgColor, 
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
            onPressed: () {
               // When going back, if checklist, ensure synced one last time
               if (_isChecklist) _syncChecklistToContent();
               Navigator.pop(context);
            },
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
           IconButton(
            icon: const Icon(Icons.image_outlined),
            onPressed: _pickImages,
          ),
          IconButton(
            icon: Icon(_isChecklist ? Icons.check_box : Icons.check_box_outline_blank),
            onPressed: _toggleChecklistMode,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image (Legacy) handling? Or just treat as first image?
              // Logic: If _imagePath exists, show it.
              if (_imagePath != null) 
                 Padding(
                   padding: const EdgeInsets.only(bottom: 16),
                   child: ClipRRect(
                     borderRadius: BorderRadius.circular(12),
                     child: Image.file(File(_imagePath!), height: 200, width: double.infinity, fit: BoxFit.cover),
                   ),
                 ),

              // Attached Images Grid
              if (_attachedImages.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _attachedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                         ClipRRect(
                           borderRadius: BorderRadius.circular(8),
                           child: Image.file(
                             File(_attachedImages[index]), 
                             fit: BoxFit.cover,
                             width: double.infinity, height: double.infinity,
                           ),
                         ),
                         Positioned(
                           top: 4, right: 4,
                           child: GestureDetector(
                             onTap: () {
                               setState(() => _attachedImages.removeAt(index));
                               _saveNote();
                             },
                             child: const CircleAvatar(
                               radius: 10,
                               backgroundColor: Colors.black54,
                               child: Icon(Icons.close, size: 12, color: Colors.white),
                             ),
                           ),
                         )
                      ],
                    );
                  },
                ),
                
              const SizedBox(height: 16),
              
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
              
              // EDITOR Content
              _isChecklist ? _buildChecklistEditor() : _buildTextEditor(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextEditor() {
    return TextField(
      controller: _contentController,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(
        hintText: 'Start typing...',
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildChecklistEditor() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _checklistItems.length + 1, // +1 for "Add Item" ghost
      itemBuilder: (context, index) {
        if (index == _checklistItems.length) {
          return ListTile(
            leading: const Icon(Icons.add, color: Colors.grey),
            title: const Text("List item", style: TextStyle(color: Colors.grey)),
            onTap: () {
              setState(() {
                _checklistItems.add(ChecklistItem(isChecked: false, text: ""));
              });
              _syncChecklistToContent();
            },
          );
        }
        
        final item = _checklistItems[index];
        return Row(
          children: [
            Checkbox(
              value: item.isChecked,
              onChanged: (val) {
                setState(() => item.isChecked = val ?? false);
                _syncChecklistToContent();
              },
            ),
            Expanded(
              child: TextFormField(
                initialValue: item.text,
                onChanged: (val) {
                  item.text = val;
                  _syncChecklistToContent();
                },
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Item",
                ),
                style: TextStyle(
                  decoration: item.isChecked ? TextDecoration.lineThrough : null,
                  color: item.isChecked ? Colors.grey : null,
                ),
              ),
            ),
             IconButton(
               icon: const Icon(Icons.close, size: 16),
               onPressed: () {
                  setState(() => _checklistItems.removeAt(index));
                  _syncChecklistToContent();
               },
             )
          ],
        );
      },
    );
  }
  
  void _showColorPicker() {
    // ... (Keep existing implementation)
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
}