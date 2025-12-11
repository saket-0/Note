import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Image Optimization Service - Generates compressed thumbnails for grid display.
/// 
/// **Strategy:**
/// - Dashboard grid loads thumbnails (300px, 80% quality) for fast rendering
/// - Editor loads original full-resolution images
/// - Thumbnails are stored separately in `/thumbnails/` directory
/// 
/// **Performance:**
/// - Smaller file size = faster decode = smoother scrolling
/// - Compression runs asynchronously, doesn't block UI
class ImageOptimizationService {
  // Thumbnail configuration
  static const int thumbnailMaxWidth = 300;
  static const int thumbnailMaxHeight = 300;
  static const int thumbnailQuality = 80;
  
  Directory? _thumbnailDir;
  
  /// Initialize the thumbnail directory.
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _thumbnailDir = Directory(p.join(appDir.path, 'thumbnails'));
    
    if (!await _thumbnailDir!.exists()) {
      await _thumbnailDir!.create(recursive: true);
      debugPrint('[ImageOptimizationService] Created thumbnail directory: ${_thumbnailDir!.path}');
    }
  }
  
  /// Generate a compressed thumbnail for an image.
  /// 
  /// Returns the path to the generated thumbnail, or the original path if
  /// compression fails (graceful fallback).
  /// 
  /// **Parameters:**
  /// - `originalPath`: Path to the original full-resolution image
  /// 
  /// **Returns:** Path to the thumbnail (or original if compression fails)
  Future<String> generateThumbnail(String originalPath) async {
    try {
      // Ensure directory is initialized
      if (_thumbnailDir == null) {
        await initialize();
      }
      
      // Validate source file exists
      final originalFile = File(originalPath);
      if (!await originalFile.exists()) {
        debugPrint('[ImageOptimizationService] Original file not found: $originalPath');
        return originalPath;
      }
      
      // Generate unique thumbnail filename
      final fileName = p.basenameWithoutExtension(originalPath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final thumbnailPath = p.join(_thumbnailDir!.path, '${fileName}_${timestamp}_thumb.jpg');
      
      // Compress the image
      final result = await FlutterImageCompress.compressAndGetFile(
        originalPath,
        thumbnailPath,
        minWidth: thumbnailMaxWidth,
        minHeight: thumbnailMaxHeight,
        quality: thumbnailQuality,
        format: CompressFormat.jpeg,
      );
      
      if (result != null) {
        debugPrint('[ImageOptimizationService] Generated thumbnail: ${result.path}');
        debugPrint('[ImageOptimizationService] Original: ${await originalFile.length()} bytes');
        debugPrint('[ImageOptimizationService] Thumbnail: ${await result.length()} bytes');
        return result.path;
      } else {
        debugPrint('[ImageOptimizationService] Compression returned null, using original');
        return originalPath;
      }
    } catch (e) {
      debugPrint('[ImageOptimizationService] Error generating thumbnail: $e');
      return originalPath; // Graceful fallback
    }
  }
  
  /// Generate thumbnails for multiple images.
  /// 
  /// Returns a map of originalPath -> thumbnailPath
  Future<Map<String, String>> generateThumbnails(List<String> originalPaths) async {
    final results = <String, String>{};
    
    for (final path in originalPaths) {
      results[path] = await generateThumbnail(path);
    }
    
    return results;
  }
  
  /// Delete a thumbnail file.
  /// 
  /// Call this when the associated note/image is permanently deleted.
  Future<void> deleteThumbnail(String thumbnailPath) async {
    try {
      final file = File(thumbnailPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[ImageOptimizationService] Deleted thumbnail: $thumbnailPath');
      }
    } catch (e) {
      debugPrint('[ImageOptimizationService] Error deleting thumbnail: $e');
    }
  }
  
  /// Clean up orphaned thumbnails.
  /// 
  /// Call this periodically to remove thumbnails that no longer have
  /// associated notes. Pass a set of valid thumbnail paths.
  Future<int> cleanupOrphanedThumbnails(Set<String> validThumbnailPaths) async {
    if (_thumbnailDir == null) {
      await initialize();
    }
    
    int deletedCount = 0;
    
    try {
      final files = _thumbnailDir!.listSync();
      
      for (final file in files) {
        if (file is File && !validThumbnailPaths.contains(file.path)) {
          await file.delete();
          deletedCount++;
        }
      }
      
      debugPrint('[ImageOptimizationService] Cleaned up $deletedCount orphaned thumbnails');
    } catch (e) {
      debugPrint('[ImageOptimizationService] Error during cleanup: $e');
    }
    
    return deletedCount;
  }
  
  /// Get the thumbnail directory path.
  Future<String> getThumbnailDirectory() async {
    if (_thumbnailDir == null) {
      await initialize();
    }
    return _thumbnailDir!.path;
  }
  
  /// Check if a thumbnail exists for a given path.
  Future<bool> thumbnailExists(String thumbnailPath) async {
    return File(thumbnailPath).exists();
  }
}

// =============================================================================
// PROVIDER
// =============================================================================

final imageOptimizationServiceProvider = Provider<ImageOptimizationService>((ref) {
  final service = ImageOptimizationService();
  // Initialize lazily on first use
  return service;
});

/// Async provider for initialized service
final imageOptimizationServiceInitializedProvider = FutureProvider<ImageOptimizationService>((ref) async {
  final service = ref.read(imageOptimizationServiceProvider);
  await service.initialize();
  return service;
});
