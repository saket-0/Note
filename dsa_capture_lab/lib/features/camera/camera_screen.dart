import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../core/database/app_database.dart';

class CameraScreen extends ConsumerWidget {
  final int? folderId;
  const CameraScreen({super.key, this.folderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        onMediaTap: (mediaCapture) {
          mediaCapture.captureRequest.when(
            single: (single) async {
              final filePath = single.file?.path;
              if (filePath != null) {
                print("📸 Capture saved at: $filePath");
                
                // Save reference to DB
                final db = ref.read(dbProvider);
                await db.createNote(
                  title: "Snapshot ${DateTime.now().minute}:${DateTime.now().second}",
                  content: "",
                  imagePath: filePath,
                  folderId: folderId,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Saved to ${folderId == null ? 'Dashboard' : 'Folder'}")),
                  );
                }
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