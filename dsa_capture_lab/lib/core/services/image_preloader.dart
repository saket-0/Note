import 'dart:io';
import 'package:flutter/material.dart';
import '../database/app_database.dart';

/// Service to preload images into Flutter's image cache for instant display.
/// This eliminates visible loading lag when navigating to folders with images.
class ImagePreloader {
  static final ImagePreloader _instance = ImagePreloader._internal();
  factory ImagePreloader() => _instance;
  ImagePreloader._internal();
  
  final Set<String> _preloadedPaths = {};
  
  /// Preload all images for a list of notes.
  /// Should be called when loading folder contents.
  Future<void> preloadNotesImages(List<Note> notes, BuildContext context) async {
    for (final note in notes) {
      await _preloadNoteImages(note, context);
    }
  }
  
  Future<void> _preloadNoteImages(Note note, BuildContext context) async {
    // Preload images list
    for (final imagePath in note.images) {
      await _preloadImage(imagePath, context);
    }
    
    // Preload single image path if present
    if (note.imagePath != null && note.imagePath!.isNotEmpty) {
      await _preloadImage(note.imagePath!, context);
    }
  }
  
  Future<void> _preloadImage(String path, BuildContext context) async {
    if (_preloadedPaths.contains(path)) return;
    
    try {
      final file = File(path);
      if (await file.exists()) {
        final imageProvider = ResizeImage(
          FileImage(file),
          width: 400, // Match the cacheWidth used in display
        );
        
        await precacheImage(imageProvider, context);
        _preloadedPaths.add(path);
      }
    } catch (e) {
      // Silently ignore preload failures
    }
  }
  
  /// Clear the cache (useful when images are deleted)
  void clearCache() {
    _preloadedPaths.clear();
    PaintingBinding.instance.imageCache.clear();
  }
  
  /// Preload images for folder contents at startup
  Future<void> preloadAllImagesFromCache(
    Map<int?, List<Note>> notesByFolder,
    BuildContext context,
  ) async {
    for (final notes in notesByFolder.values) {
      for (final note in notes) {
        await _preloadNoteImages(note, context);
      }
    }
  }
}
