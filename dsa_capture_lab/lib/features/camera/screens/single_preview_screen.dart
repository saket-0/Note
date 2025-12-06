import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/camera_view_model.dart';

class SinglePreviewScreen extends ConsumerWidget {
  final String imagePath;
  final int? folderId;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  const SinglePreviewScreen({
    super.key,
    required this.imagePath,
    required this.folderId,
    required this.onDiscard,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.file(
              File(imagePath),
              fit: BoxFit.cover,
            ),
          ),
          // Gradient
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 150,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Back Button
          Positioned(
            top: 40, left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onSave, // Auto-save on back
              ),
            ),
          ),
          // Actions
          Positioned(
            bottom: 40, left: 40, right: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    FloatingActionButton(
                      heroTag: "discard_S",
                      backgroundColor: Colors.redAccent,
                      onPressed: onDiscard,
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text("Discard", style: TextStyle(color: Colors.white))
                  ],
                ),
                Column(
                  children: [
                     FloatingActionButton(
                      heroTag: "save_S",
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      onPressed: onSave,
                      child: const Icon(Icons.check, size: 30),
                    ),
                    const SizedBox(height: 8),
                    const Text("Save", style: TextStyle(color: Colors.white))
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
