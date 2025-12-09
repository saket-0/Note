import 'dart:io';
import 'package:flutter/material.dart';
import '../data/data_repository.dart';
import '../domain/entities/entities.dart';

/// Service to preload images into Flutter's image cache for instant display.
/// This eliminates visible loading lag when navigating to folders with images.
/// 
/// Supports "Neighborhood Preloading" - preloads images for the current folder
/// and its subfolders in the background to prepare for likely navigation paths.
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

  /// Preload images for a folder and its immediate subfolders.
  /// 
  /// This implements "Neighborhood Preloading" strategy:
  /// - Step A: Preload current folder's images immediately (high priority)
  /// - Step B: Get subfolder IDs for lookahead
  /// - Step C: Iterate subfolders with yielding delays to keep UI smooth
  /// 
  /// The 50ms delay between subfolders prevents precacheImage from
  /// monopolizing the main thread and dropping frames.
  Future<void> preloadNeighborhood(
    int? centerFolderId,
    DataRepository repo,
    BuildContext context,
  ) async {
    // Guard: context must be mounted
    if (!context.mounted) return;
    
    // Step A: Preload current folder's images immediately
    final currentNotes = repo.getNotesForFolder(centerFolderId);
    await preloadNotesImages(currentNotes, context);
    
    // Step B: Get subfolder IDs for lookahead
    final subfolderIds = repo.getSubfolderIds(centerFolderId);
    
    // Step C: Background loop through subfolders with yielding
    for (final subfolderId in subfolderIds) {
      // Safety check: stop if widget is disposed
      if (!context.mounted) return;
      
      final subNotes = repo.getNotesForFolder(subfolderId);
      await preloadNotesImages(subNotes, context);
      
      // Yield to main thread to prevent frame drops
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }
}
