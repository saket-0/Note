import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CameraAwesomeBuilder.awesome(
        // 1. Configuration: Photo mode only for now
        saveConfig: SaveConfig.photo(
          pathBuilder: (sensors) async {
            // 2. Logic: Where do we save the file? 
            // We save it to the App's private documents directory (Hidden from Gallery)
            final Directory extDir = await getApplicationDocumentsDirectory();
            final String dirPath = '${extDir.path}/dsa_captures';
            await Directory(dirPath).create(recursive: true);
            
            // Generate a unique filename
            final String filePath = '$dirPath/${const Uuid().v4()}.jpg';
            return SingleCaptureRequest(filePath, sensors.first);
          },
        ),
        
        // 3. UI Customization (Top Bar)
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

        // 4. What happens when a photo is taken?
        // 4. What happens when a photo is taken?
        onMediaTap: (mediaCapture) {
          // FIX: Access the path through the captureRequest
          mediaCapture.captureRequest.when(
            single: (single) {
              final filePath = single.file?.path;
              if (filePath != null) {
                print("📸 Capture saved at: $filePath");
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Saved: ${filePath.split('/').last}")),
                );
              }
            },
            multiple: (multiple) {
              // Handle multiple cameras if needed (not for this step)
            },
          );
        },
      ),
    );
  }
}