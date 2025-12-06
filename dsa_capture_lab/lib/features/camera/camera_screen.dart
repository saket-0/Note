import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

import 'controllers/camera_view_model.dart';
import 'screens/single_preview_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  final int? folderId;
  const CameraScreen({super.key, this.folderId});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  // Local state for Single Mode preview only
  String? _singleCapturedPath;
  int? _singleCapturedId;

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraViewModelProvider);
    final viewModel = ref.read(cameraViewModelProvider.notifier);

    // If Single Mode has a capture, show Preview (Already Saved)
    if (!cameraState.isBatchMode && _singleCapturedPath != null) {
      return SinglePreviewScreen(
        imagePath: _singleCapturedPath!,
        folderId: widget.folderId,
        onDiscard: () async {
          // DELETE (User rejected the instantly saved photo)
           if (_singleCapturedId != null) {
             await viewModel.deleteNote(_singleCapturedId!);
           }
           setState(() {
             _singleCapturedPath = null;
             _singleCapturedId = null;
           });
        },
        onSave: () {
          // DONE (User accepted the already saved photo)
          if (context.mounted) Navigator.pop(context);
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // CAMERA
          CameraAwesomeBuilder.awesome(
            saveConfig: SaveConfig.photo(
              pathBuilder: (sensors) async {
                final Directory extDir = await getApplicationDocumentsDirectory();
                final String dirPath = '${extDir.path}/dsa_captures';
                await Directory(dirPath).create(recursive: true);
                final String filePath = '$dirPath/${const Uuid().v4()}.jpg';
                return SingleCaptureRequest(filePath, sensors.first);
              },
            ),
            
            topActionsBuilder: (state) => _buildTopBar(cameraState, viewModel),
            
            // On Capture
            onMediaCaptureEvent: (event) {
               if (event.status == MediaCaptureStatus.success) {
                 event.captureRequest.when(
                   single: (single) async {
                     final path = single.file?.path;
                     if (path != null) {
                       if (cameraState.isBatchMode) {
                         // Batch: Add to list, no preview
                         viewModel.addPhoto(path);
                       } else {
                         // Single: INSTANT SAVE & Show Preview
                         // We save first to ensure persistence
                         final id = await viewModel.saveSingle(path, widget.folderId);
                         if (mounted) {
                           setState(() {
                             _singleCapturedPath = path;
                             _singleCapturedId = id;
                           });
                         }
                       }
                     }
                   },
                   multiple: (_) {},
                 );
               }
            },
          ),

          // BATCH COUNTER & DONE BUTTON (Overlay)
          if (cameraState.isBatchMode && cameraState.capturedPaths.isNotEmpty)
            Positioned(
              bottom: 120, // Above shutter area usually
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Counter Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54, 
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24)
                    ),
                    child: Text(
                      "${cameraState.capturedPaths.length} Photos",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // Done Button
                  FloatingActionButton.extended(
                    heroTag: "batch_done",
                    onPressed: () async {
                      await viewModel.saveBatch(widget.folderId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Batch Saved!")));
                        Navigator.pop(context);
                      }
                    },
                    label: const Text("Done"),
                    icon: const Icon(Icons.check),
                    backgroundColor: Colors.teal,
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BatchCameraState state, CameraViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back
          CircleAvatar(
            backgroundColor: Colors.black45,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Mode Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20)
            ),
            child: Row(
              children: [
                const Text("Quick", style: TextStyle(color: Colors.white, fontSize: 12)),
                Switch(
                  value: state.isBatchMode,
                  onChanged: (val) => viewModel.toggleMode(val),
                  activeColor: Colors.amber,
                  activeTrackColor: Colors.amber.withOpacity(0.3),
                ),
                Text("Batch", style: TextStyle(color: state.isBatchMode ? Colors.amber : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }
}