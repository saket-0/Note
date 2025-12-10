import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Commands sent to the AssetWorker isolate
sealed class AssetWorkerCommand {
  final String id;
  const AssetWorkerCommand(this.id);
}

/// Request to load an image file from disk
class LoadImageCommand extends AssetWorkerCommand {
  final String path;
  final bool priority;
  
  const LoadImageCommand({
    required String id,
    required this.path,
    this.priority = false,
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

/// Responses from the AssetWorker isolate
sealed class AssetWorkerResponse {
  final String commandId;
  const AssetWorkerResponse(this.commandId);
}

/// Successful image load response
class ImageLoadedResponse extends AssetWorkerResponse {
  final String path;
  final Uint8List bytes;
  
  const ImageLoadedResponse({
    required String commandId,
    required this.path,
    required this.bytes,
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

/// AssetWorker - Long-lived background isolate for disk I/O
/// 
/// Design Philosophy:
/// - Main thread NEVER calls File.readAsBytes()
/// - Uses synchronous file APIs inside isolate for maximum throughput
/// - Single isolate handles all asset loading (avoids spawn overhead)
/// - Priority queue for on-screen items
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
  
  /// Initialize the worker isolate
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _receivePort = ReceivePort();
    
    _isolate = await Isolate.spawn(
      _workerEntryPoint,
      _receivePort!.sendPort,
    );
    
    // First message is the worker's SendPort
    final completer = Completer<SendPort>();
    
    _receivePort!.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is AssetWorkerResponse) {
        _responseController.add(message);
      }
    });
    
    _sendPort = await completer.future;
    _isInitialized = true;
    
    debugPrint('[AssetWorker] Initialized and ready');
  }
  
  /// Send a command to the worker
  void sendCommand(AssetWorkerCommand command) {
    if (!_isInitialized || _sendPort == null) {
      debugPrint('[AssetWorker] Warning: Not initialized, dropping command');
      return;
    }
    _sendPort!.send(command);
  }
  
  /// Load an image file (convenience method)
  void loadImage(String path, {bool priority = false}) {
    final id = '${DateTime.now().microsecondsSinceEpoch}_$path';
    sendCommand(LoadImageCommand(
      id: id,
      path: path,
      priority: priority,
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
  static void _workerEntryPoint(SendPort mainSendPort) {
    final workerReceivePort = ReceivePort();
    
    // Send our SendPort back to main isolate
    mainSendPort.send(workerReceivePort.sendPort);
    
    debugPrint('[AssetWorker:Isolate] Started');
    
    workerReceivePort.listen((message) {
      if (message is AssetWorkerCommand) {
        _handleCommand(message, mainSendPort);
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
    }
  }
  
  /// Load image from disk (SYNCHRONOUS for max throughput in isolate)
  static void _handleLoadImage(LoadImageCommand command, SendPort sendPort) {
    try {
      final file = File(command.path);
      
      // SYNCHRONOUS read - safe in isolate, maximum throughput
      if (!file.existsSync()) {
        sendPort.send(AssetErrorResponse(
          commandId: command.id,
          path: command.path,
          error: 'File not found',
        ));
        debugPrint('[AssetWorker:Isolate] File not found: ${command.path}');
        return;
      }
      
      final bytes = file.readAsBytesSync();
      
      sendPort.send(ImageLoadedResponse(
        commandId: command.id,
        path: command.path,
        bytes: bytes,
      ));
      
      debugPrint('[AssetWorker:Isolate] Disk Read: ${command.path} (${bytes.length} bytes)');
    } catch (e) {
      sendPort.send(AssetErrorResponse(
        commandId: command.id,
        path: command.path,
        error: e.toString(),
      ));
      debugPrint('[AssetWorker:Isolate] Error loading ${command.path}: $e');
    }
  }
  
  /// Generate thumbnail (placeholder for future implementation)
  static void _handleGenerateThumbnail(GenerateThumbnailCommand command, SendPort sendPort) {
    // TODO: Implement thumbnail generation
    // This would use image package to resize
    debugPrint('[AssetWorker:Isolate] Thumbnail generation not yet implemented');
    
    sendPort.send(AssetErrorResponse(
      commandId: command.id,
      path: command.sourcePath,
      error: 'Thumbnail generation not implemented',
    ));
  }
}
