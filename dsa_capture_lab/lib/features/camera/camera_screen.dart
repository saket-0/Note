import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../core/database/app_database.dart';

class CameraScreen extends ConsumerStatefulWidget {
  final int? folderId;
  const CameraScreen({super.key, this.folderId});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  String? _capturedPath;

  @override
  Widget build(BuildContext context) {
    if (_capturedPath != null) {
      return _buildReviewScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: CameraAwesomeBuilder.awesome(
        saveConfig: SaveConfig.photo(
          pathBuilder: (sensors) async {
            final Directory extDir = await getApplicationDocumentsDirectory();
            final String dirPath = '${extDir.path}/dsa_captures';
            await Directory(dirPath).create(recursive: true);
            final String filePath = '$dirPath/${const Uuid().v4()}.jpg';
            return SingleCaptureRequest(filePath, sensors.first);
          },
        ),
        // Custom Top UI
        topActionsBuilder: (state) => Padding(
          padding: const EdgeInsets.only(top: 30, left: 20),
          child: CircleAvatar(
            backgroundColor: Colors.black45,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        // Intercept Capture Event
        onMediaCaptureEvent: (event) {
           if (event.status == MediaCaptureStatus.success) {
             event.captureRequest.when(
               single: (single) {
                 if (single.file?.path != null) {
                   setState(() {
                     _capturedPath = single.file!.path;
                   });
                 }
               },
               multiple: (_) {},
             );
           }
        },
      ),
    );
  }

  Widget _buildReviewScreen() {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Back Button = Auto Save
        await _saveAndClose();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Image Preview
            Positioned.fill(
              child: Image.file(
                File(_capturedPath!),
                fit: BoxFit.cover,
              ),
            ),
            
            // 2. Overlay Gradient for Controls
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

            // 3. Top Controls (Back = Save)
            Positioned(
              top: 40,
              left: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => _saveAndClose(), // Auto-save
                ),
              ),
            ),

            // 4. Bottom Controls (Discard / Done)
            Positioned(
              bottom: 40,
              left: 40,
              right: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Discard Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: "discard_btn",
                        backgroundColor: Colors.redAccent,
                        onPressed: _discardAndRetry,
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text("Discard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    ],
                  ),

                  // Done Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: "save_btn",
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        onPressed: _saveAndClose,
                        child: const Icon(Icons.check, size: 30),
                      ),
                      const SizedBox(height: 8),
                      const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _discardAndRetry() async {
    if (_capturedPath != null) {
      try {
        await File(_capturedPath!).delete();
      } catch (e) {
        print("Error deleting discarded file: $e");
      }
    }
    setState(() {
      _capturedPath = null; // Return to camera
    });
  }

  Future<void> _saveAndClose() async {
    if (_capturedPath == null) return;
    
    final db = ref.read(dbProvider);
    await db.createNote(
      title: "Snapshot ${DateTime.now().minute}:${DateTime.now().second}",
      content: "",
      imagePath: _capturedPath,
      folderId: widget.folderId,
      fileType: 'image'
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Saved to ${widget.folderId == null ? 'Dashboard' : 'Folder'}"),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 1),
        ),
      );
      Navigator.pop(context); // Close Camera Screen
    }
  }
}