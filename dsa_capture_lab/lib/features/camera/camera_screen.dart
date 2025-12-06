import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

import 'controllers/camera_view_model.dart';
import 'screens/single_preview_screen.dart';
import 'widgets/camera_top_bar.dart';
import 'widgets/camera_control_bar.dart';

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
        onDiscard: () {
          // DELETE (User rejected the instantly saved photo)
           if (_singleCapturedId != null) {
              viewModel.deleteNote(_singleCapturedId!); // Optimistic
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
            // Performance Tuning: Fixed Aspect Ratio & Back Camera default
            sensorConfig: SensorConfig.single(
              sensor: Sensor.position(SensorPosition.back),
              aspectRatio: CameraAspectRatios.ratio_16_9, 
              flashMode: FlashMode.auto,
            ),
            saveConfig: SaveConfig.photo(
              pathBuilder: (sensors) async {
                final Directory extDir = await getApplicationDocumentsDirectory();
                final String dirPath = '${extDir.path}/dsa_captures';
                await Directory(dirPath).create(recursive: true);
                final String filePath = '$dirPath/${const Uuid().v4()}.jpg';
                return SingleCaptureRequest(filePath, sensors.first);
              },
            ),
            
            // Custom UI Overlays
            topActionsBuilder: (state) => const SizedBox.shrink(), // We use TopBar overlay
            middleContentBuilder: (state) => const SizedBox.shrink(),
            
            bottomActionsBuilder: (state) {
               return CameraControlBar(
                  isBatchMode: cameraState.isBatchMode,
                  capturedItems: cameraState.capturedItems,
                  onDiscardBatch: () => viewModel.discardBatch(),
                  onFinishBatch: () {
                     viewModel.endBatchSession();
                     Navigator.pop(context);
                  },
                  onTakePicture: () {
                    state.when(
                      onPhotoMode: (photoState) => photoState.takePhoto(),
                      onVideoMode: (videoState) => videoState.startRecording(),
                      onPreparingCamera: (_) {},
                      onVideoRecordingMode: (_) {},
                    );
                  },
                  onItemTap: (note) => _showBatchItemPreview(context, note, viewModel),
                );
            },
            
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
          
          // TOP BAR
          Positioned(
            top: 0, left: 0, right: 0,
            child: CameraTopBar(
              isBatchMode: cameraState.isBatchMode,
              onModeChanged: (val) => viewModel.toggleMode(val),
              onBack: () => Navigator.pop(context),
            ),
          ),


        ],
      ),
    );
  }

  void _showBatchItemPreview(BuildContext context, dynamic note, CameraViewModel viewModel) {
     showDialog(
       context: context, 
       barrierDismissible: true,
       builder: (ctx) => Dialog(
         backgroundColor: Colors.transparent,
         insetPadding: const EdgeInsets.all(10),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             ClipRRect(
               borderRadius: BorderRadius.circular(20),
               child: Image.file(File(note.imagePath!), fit: BoxFit.contain),
             ),
             const SizedBox(height: 20),
             FloatingActionButton.extended(
               label: const Text("Delete"),
               icon: const Icon(Icons.delete),
               backgroundColor: Colors.red,
               onPressed: () {
                 // Optimistic Delete: Close dialog immediately, VM handles state & DB
                 Navigator.pop(ctx);
                 viewModel.deleteBatchPhoto(note);
               },
             ),
           ],
         ),
       )
     );
  }
}