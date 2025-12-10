import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Commands sent to the AssetWorker isolate
sealed class AssetWorkerCommand {
  final String id;
  const AssetWorkerCommand(this.id);
}

/// Request to load and compress an image file from disk
class LoadImageCommand extends AssetWorkerCommand {
  final String path;
  final bool priority;
  final int targetWidth;
  final int targetHeight;
  final int quality;
  
  const LoadImageCommand({
    required String id,
    required this.path,
    this.priority = false,
    this.targetWidth = 400,
    this.targetHeight = 400,
    this.quality = 70,
  }) : super(id);
}

/// Request to generate a thumbnail (future use)
class GenerateThumbnailCommand extends AssetWorkerCommand {
  final String sourcePath;
  final String targetPath;
  final int maxWidth;
  
  const GenerateThumbnailCommand({
    required String id,
    required this.sourcePath,
    required this.targetPath,
    this.maxWidth = 300,
  }) : super(id);
}

/// Request to save bytes to disk asynchronously
/// Used by ingestImmediate() for "RAM-First, Disk-Later" pattern
class SaveToFileCommand extends AssetWorkerCommand {
  final String path;
  final Uint8List bytes;
  
  const SaveToFileCommand({
    required String id,
    required this.path,
    required this.bytes,
  }) : super(id);
}

/// Responses from the AssetWorker isolate
sealed class AssetWorkerResponse {
  final String commandId;
  const AssetWorkerResponse(this.commandId);
}

/// Successful image load response
class ImageLoadedResponse extends AssetWorkerResponse {
  final String path;
  final Uint8List bytes;
  final bool wasCompressed;
  
  const ImageLoadedResponse({
    required String commandId,
    required this.path,
    required this.bytes,
    this.wasCompressed = false,
  }) : super(commandId);
}

/// Error response
class AssetErrorResponse extends AssetWorkerResponse {
  final String path;
  final String error;
  
  const AssetErrorResponse({
    required String commandId,
    required this.path,
    required this.error,
  }) : super(commandId);
}

/// Thumbnail generated response (future use)
class ThumbnailGeneratedResponse extends AssetWorkerResponse {
  final String sourcePath;
  final String targetPath;
  
  const ThumbnailGeneratedResponse({
    required String commandId,
    required this.sourcePath,
    required this.targetPath,
  }) : super(commandId);
}

/// File saved response - confirms async disk write completion
class FileSavedResponse extends AssetWorkerResponse {
  final String path;
  final bool success;
  
  const FileSavedResponse({
    required String commandId,
    required this.path,
    required this.success,
  }) : super(commandId);
}

/// Initialization data passed to the worker isolate
class _WorkerInitData {
  final SendPort sendPort;
  final RootIsolateToken? rootIsolateToken;
  
  const _WorkerInitData({
    required this.sendPort,
    required this.rootIsolateToken,
  });
}

/// AssetWorker - Long-lived background isolate for disk I/O with compression
/// 
/// Design Philosophy:
/// - Main thread NEVER calls File.readAsBytes() or File.writeAsBytes()
/// - Compresses images to 400px / 70% quality (~30KB vs 5MB original)
/// - Uses RootIsolateToken for platform channel access in isolate
/// - Single isolate handles all asset loading (avoids spawn overhead)
/// - Priority queue for on-screen items
/// 
/// === RAM-FIRST, DISK-LATER SUPPORT ===
/// - writeToDisk(): Async file persistence for ingestImmediate()
/// - Ensures UI thread never blocks on disk writes
class AssetWorker {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  
  final StreamController<AssetWorkerResponse> _responseController = 
      StreamController<AssetWorkerResponse>.broadcast();
  
  /// Stream of responses from the worker
  Stream<AssetWorkerResponse> get responses => _responseController.stream;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  // Initialization lock to prevent race conditions
  Completer<void>? _initCompleter;
  
  /// Initialize the worker isolate
  /// Uses a Completer lock to prevent double initialization
  Future<void> initialize() async {
    // Already initialized
    if (_isInitialized) return;
    
    // Initialization in progress - wait for it
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    
    // Start initialization with lock
    _initCompleter = Completer<void>();
    
    try {
      _receivePort = ReceivePort();
      
      // Capture the RootIsolateToken for platform channel access in isolate
      final rootIsolateToken = RootIsolateToken.instance;
      
      _isolate = await Isolate.spawn(
        _workerEntryPoint,
        _WorkerInitData(
          sendPort: _receivePort!.sendPort,
          rootIsolateToken: rootIsolateToken,
        ),
      );
      
      // First message is the worker's SendPort
      final sendPortCompleter = Completer<SendPort>();
      
      _receivePort!.listen((message) {
        if (message is SendPort && !sendPortCompleter.isCompleted) {
          sendPortCompleter.complete(message);
        } else if (message is AssetWorkerResponse) {
          _responseController.add(message);
        }
      });
      
      _sendPort = await sendPortCompleter.future;
      _isInitialized = true;
      
      debugPrint('[AssetWorker] Initialized with RAM-First architecture support');
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('[AssetWorker] Initialization failed: $e');
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }
  
  /// Send a command to the worker
  void sendCommand(AssetWorkerCommand command) {
    if (!_isInitialized || _sendPort == null) {
      debugPrint('[AssetWorker] Warning: Not initialized, dropping command');
      return;
    }
    _sendPort!.send(command);
  }
  
  /// Load an image file with compression (convenience method)
  void loadImage(String path, {bool priority = false}) {
    final id = '${DateTime.now().microsecondsSinceEpoch}_$path';
    sendCommand(LoadImageCommand(
      id: id,
      path: path,
      priority: priority,
    ));
  }
  
  /// Write bytes to disk asynchronously (for RAM-First pattern)
  /// Called by AssetPipelineService.ingestImmediate()
  void writeToDisk(String path, Uint8List bytes) {
    final id = 'save_${DateTime.now().microsecondsSinceEpoch}_$path';
    sendCommand(SaveToFileCommand(
      id: id,
      path: path,
      bytes: bytes,
    ));
  }
  
  /// Dispose the worker
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
    _sendPort = null;
    _responseController.close();
    _isInitialized = false;
    
    debugPrint('[AssetWorker] Disposed');
  }
  
  /// Entry point for the worker isolate
  static void _workerEntryPoint(_WorkerInitData initData) {
    // Initialize platform channel access in this isolate
    if (initData.rootIsolateToken != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(initData.rootIsolateToken!);
    }
    
    final workerReceivePort = ReceivePort();
    
    // Send our SendPort back to main isolate
    initData.sendPort.send(workerReceivePort.sendPort);
    
    debugPrint('[AssetWorker:Isolate] Started with RAM-First architecture support');
    
    workerReceivePort.listen((message) {
      if (message is AssetWorkerCommand) {
        _handleCommand(message, initData.sendPort);
      }
    });
  }
  
  /// Handle commands inside the isolate
  static void _handleCommand(AssetWorkerCommand command, SendPort sendPort) {
    switch (command) {
      case LoadImageCommand():
        _handleLoadImage(command, sendPort);
        break;
      case GenerateThumbnailCommand():
        _handleGenerateThumbnail(command, sendPort);
        break;
      case SaveToFileCommand():
        _handleSaveToFile(command, sendPort);
        break;
    }
  }
  
  /// Load and compress image from disk
  static Future<void> _handleLoadImage(LoadImageCommand command, SendPort sendPort) async {
    try {
      final file = File(command.path);
      
      if (!file.existsSync()) {
        sendPort.send(AssetErrorResponse(
          commandId: command.id,
          path: command.path,
          error: 'File not found',
        ));
        debugPrint('[AssetWorker:Isolate] File not found: ${command.path}');
        return;
      }
      
      // Check file extension to determine if we should compress
      final extension = command.path.split('.').last.toLowerCase();
      final isCompressibleImage = ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(extension);
      
      Uint8List bytes;
      bool wasCompressed = false;
      
      if (isCompressibleImage) {
        // Try to compress the image
        try {
          final compressedBytes = await FlutterImageCompress.compressWithFile(
            command.path,
            minWidth: command.targetWidth,
            minHeight: command.targetHeight,
            quality: command.quality,
            format: CompressFormat.jpeg,
          );
          
          if (compressedBytes != null && compressedBytes.isNotEmpty) {
            bytes = compressedBytes;
            wasCompressed = true;
            debugPrint('[AssetWorker:Isolate] Compressed: ${command.path} (${bytes.length} bytes)');
          } else {
            // Compression returned null, fall back to raw read
            bytes = file.readAsBytesSync();
            debugPrint('[AssetWorker:Isolate] Compression null, raw read: ${command.path}');
          }
        } catch (compressError) {
          // Compression failed, fall back to raw read
          debugPrint('[AssetWorker:Isolate] Compression failed, falling back: $compressError');
          bytes = file.readAsBytesSync();
        }
      } else {
        // Not a compressible image (gif, bmp, etc), read raw
        bytes = file.readAsBytesSync();
        debugPrint('[AssetWorker:Isolate] Non-image/GIF, raw read: ${command.path}');
      }
      
      sendPort.send(ImageLoadedResponse(
        commandId: command.id,
        path: command.path,
        bytes: bytes,
        wasCompressed: wasCompressed,
      ));
      
    } catch (e) {
      sendPort.send(AssetErrorResponse(
        commandId: command.id,
        path: command.path,
        error: e.toString(),
      ));
      debugPrint('[AssetWorker:Isolate] Error loading ${command.path}: $e');
    }
  }
  
  /// Save bytes to disk (for RAM-First, Disk-Later pattern)
  /// This runs in the background isolate, never blocking the UI thread
  static Future<void> _handleSaveToFile(SaveToFileCommand command, SendPort sendPort) async {
    try {
      final file = File(command.path);
      
      // Ensure directory exists
      final directory = file.parent;
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      
      // Write bytes with flush to ensure durability
      await file.writeAsBytes(command.bytes, flush: true);
      
      sendPort.send(FileSavedResponse(
        commandId: command.id,
        path: command.path,
        success: true,
      ));
      
      debugPrint('[AssetWorker:Isolate] Saved to disk: ${command.path} (${command.bytes.length} bytes)');
    } catch (e) {
      sendPort.send(FileSavedResponse(
        commandId: command.id,
        path: command.path,
        success: false,
      ));
      debugPrint('[AssetWorker:Isolate] Failed to save ${command.path}: $e');
    }
  }
  
  /// Generate thumbnail (placeholder for future implementation)
  static void _handleGenerateThumbnail(GenerateThumbnailCommand command, SendPort sendPort) {
    debugPrint('[AssetWorker:Isolate] Thumbnail generation not yet implemented');
    
    sendPort.send(AssetErrorResponse(
      commandId: command.id,
      path: command.sourcePath,
      error: 'Thumbnail generation not implemented',
    ));
  }
}
