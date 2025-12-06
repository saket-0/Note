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
                         // Batch: INSTANT SAVE
                         await viewModel.captureBatchPhoto(path, widget.folderId);
                       } else {
                         // Single: INSTANT SAVE & Show Preview
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

          // BATCH UI: Thumbnail Strip & Done
          if (cameraState.isBatchMode && cameraState.capturedItems.isNotEmpty)
            Positioned(
              bottom: 120, 
              left: 0,
              right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // DONE BUTTON
                  Padding(
                    padding: const EdgeInsets.only(right: 20, bottom: 10),
                    child: FloatingActionButton.extended(
                      heroTag: "batch_done",
                      onPressed: () {
                         // Just finish the session, data is already saved
                         viewModel.endBatchSession();
                         Navigator.pop(context);
                      },
                      label: Text("Finish (${cameraState.capturedItems.length})"),
                      icon: const Icon(Icons.check),
                      backgroundColor: Colors.teal,
                    ),
                  ),
                  
                  // THUMBNAIL STRIP
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: cameraState.capturedItems.length,
                      itemBuilder: (context, index) {
                        final note = cameraState.capturedItems[cameraState.capturedItems.length - 1 - index]; // Show newest first
                        return GestureDetector(
                          onTap: () => _showBatchItemPreview(context, note, viewModel),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 2),
                              image: DecorationImage(
                                image: FileImage(File(note.imagePath!)),
                                fit: BoxFit.cover
                              ),
                            ),
                            child: const Icon(Icons.zoom_in, color: Colors.white54),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showBatchItemPreview(BuildContext context, dynamic note, CameraViewModel viewModel) {
     showDialog(
       context: context, 
       builder: (ctx) => Dialog(
         backgroundColor: Colors.transparent,
         insetPadding: const EdgeInsets.all(20),
         child: Stack(
           clipBehavior: Clip.none,
           alignment: Alignment.center,
           children: [
             ClipRRect(
               borderRadius: BorderRadius.circular(20),
               child: Image.file(File(note.imagePath!), fit: BoxFit.contain),
             ),
             Positioned(
               bottom: -30,
               child: FloatingActionButton(
                 backgroundColor: Colors.red,
                 onPressed: () async {
                   await viewModel.deleteBatchPhoto(note);
                   if (ctx.mounted) Navigator.pop(ctx);
                 },
                 child: const Icon(Icons.delete, color: Colors.white),
               ),
             ),
             Positioned(
               top: -10,
               right: -10,
               child: CircleAvatar(
                 backgroundColor: Colors.white,
                 child: IconButton(
                   icon: const Icon(Icons.close, color: Colors.black),
                   onPressed: () => Navigator.pop(ctx),
                 ),
               ),
             )
           ],
         ),
       )
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