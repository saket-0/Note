import 'dart:io';
import 'package:flutter/material.dart';

class CameraControlBar extends StatelessWidget {
  final bool isBatchMode;
  final List<dynamic> capturedItems; 
  final VoidCallback onDiscardBatch;
  final VoidCallback onFinishBatch;
  final VoidCallback onTakePicture; // New
  final Function(dynamic item) onItemTap;

  const CameraControlBar({
    super.key,
    required this.isBatchMode,
    required this.capturedItems,
    required this.onDiscardBatch,
    required this.onFinishBatch,
    required this.onTakePicture,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        color: Colors.black.withOpacity(0.5), // Semi-transparent backing
        padding: const EdgeInsets.only(bottom: 30, top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Thumbnail Strip (Batch Mode Only)
            if (isBatchMode && capturedItems.isNotEmpty)
              Container(
                height: 70,
                margin: const EdgeInsets.only(bottom: 20),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  itemCount: capturedItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final note = capturedItems[capturedItems.length - 1 - index];
                    return GestureDetector(
                      onTap: () => onItemTap(note),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                          image: DecorationImage(
                            image: FileImage(File(note.imagePath!)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
    
            // 2. Main Controls (Row)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // LEFT BUTTON (Discard or Spacer)
                  if (isBatchMode && capturedItems.isNotEmpty)
                    _buildActionButton(
                      context,
                      label: "Discard",
                      icon: Icons.delete_forever,
                      color: Colors.redAccent,
                      onTap: () => _confirmDiscard(context),
                    )
                  else
                    const SizedBox(width: 60), 
    
                  // CENTER: SHUTTER BUTTON
                  GestureDetector(
                    onTap: onTakePicture,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: Colors.transparent, // Ring
                      ),
                      child: Center(
                         child: Container(
                           width: 70, 
                           height: 70,
                           decoration: BoxDecoration(
                             color: Colors.white,
                             shape: BoxShape.circle,
                           ),
                         ),
                      ),
                    ),
                  ),
    
                  // RIGHT BUTTON (Finish or Spacer)
                  if (isBatchMode)
                     if (capturedItems.isNotEmpty)
                      _buildActionButton(
                        context,
                        label: "Done (${capturedItems.length})",
                        icon: Icons.check_circle,
                        color: Colors.tealAccent,
                        onTap: onFinishBatch,
                      )
                     else 
                       const SizedBox(width: 60) // Show nothing if no items in batch yet
                  else
                    const SizedBox(width: 60), // Single Mode Spacer
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (Rest of helpers remain same)
  Widget _buildActionButton(BuildContext context, {required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: Colors.white24,
            radius: 20,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmDiscard(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Discard All?", style: TextStyle(color: Colors.white)),
        content: const Text("This will delete all photos in this batch.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDiscardBatch();
            },
            child: const Text("Discard", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
