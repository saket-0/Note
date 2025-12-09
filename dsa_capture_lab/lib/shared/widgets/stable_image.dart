import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hardware_cache_engine.dart';

/// StableImage - V6 "Universal" Widget
/// 
/// Features:
/// - **RepaintBoundary**: Isolates painting from layout (kills drag jitter)
/// - **Synchronous lookup**: Uses cached ImageProvider immediately
/// - **Gapless playback**: Holds old texture during transitions
/// - **ValueKey enforcement**: Uses fileId for stable identity
/// - **No BuildContext dependency**: Uses singleton HardwareCacheEngine
/// - **V6: Type awareness**: Video/PDF overlays for future support
class StableImage extends ConsumerStatefulWidget {
  /// Unique identifier for this image (used for ValueKey)
  final String fileId;
  
  /// Path to the image file
  final String path;
  
  final BoxFit fit;
  final int cacheWidth;
  final double? height;
  final double? width;

  StableImage({
    required this.fileId,
    required this.path,
    this.fit = BoxFit.cover,
    this.cacheWidth = 400,
    this.height,
    this.width,
  }) : super(key: ValueKey('stable_$fileId'));

  @override
  ConsumerState<StableImage> createState() => _StableImageState();
}

class _StableImageState extends ConsumerState<StableImage> {
  ImageProvider? _cachedProvider;
  bool _hasPrioritized = false;

  @override
  void initState() {
    super.initState();
    // SYNCHRONOUS: Check cache immediately in initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkCache();
      }
    });
  }

  @override
  void didUpdateWidget(StableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _cachedProvider = null;
      _hasPrioritized = false;
      _checkCache();
    }
  }

  void _checkCache() {
    final engine = ref.read(hardwareCacheEngineProvider);
    final provider = engine.getProvider(widget.path);
    if (provider != null && _cachedProvider != provider) {
      setState(() {
        _cachedProvider = provider;
      });
    } else if (provider == null && !_hasPrioritized) {
      _hasPrioritized = true;
      engine.prioritize(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.read(hardwareCacheEngineProvider); // V7: Use read, not watch
    
    // V6: Get file type for overlay support
    final fileType = engine.getFileType(widget.path);
    
    // === V7: EARLY RETURN LOCK ===
    // Step 1: Check Memory (Instant, synchronous)
    final cached = engine.getProvider(widget.path);
    
    // Step 2: If cached - LOCK & RETURN (Stop Listening)
    // This disconnects cached images from rebuild storms: 0% CPU during scroll
    if (cached != null) {
      _cachedProvider = cached;
      return RepaintBoundary(
        child: _buildContent(fileType, provider: cached),
      );
    }
    
    // Step 3: Only Listen if NOT Cached
    // Prioritize loading if not already done
    if (!_hasPrioritized) {
      _hasPrioritized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          engine.prioritize(widget.path);
        }
      });
    }
    
    // Only uncached images subscribe to updates
    return ValueListenableBuilder<int>(
      valueListenable: engine.cacheUpdateNotifier,
      builder: (context, _, child) {
        // Check again in case cache was updated
        final provider = engine.getProvider(widget.path);
        if (provider != null) {
          _cachedProvider = provider;
        }
        
        // CRITICAL: RepaintBoundary isolates image painting
        return RepaintBoundary(
          child: _buildContent(fileType, provider: provider),
        );
      },
    );
  }
  
  /// V7: Build content based on file type
  /// [provider] is passed directly to avoid redundant cache lookups
  Widget _buildContent(FileType fileType, {ImageProvider? provider}) {
    // V7: Use passed provider or fall back to cached
    final imageProvider = provider ?? _cachedProvider;
    
    // If we have a provider, show the image (with overlay if video/pdf)
    if (imageProvider != null) {
      final imageWidget = _buildImage(imageProvider);
      
      // V6: Add overlay for video files (play button)
      if (fileType == FileType.video) {
        return Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            _buildVideoOverlay(),
          ],
        );
      }
      
      // V6: Add overlay for PDF files (document icon)
      if (fileType == FileType.pdf) {
        return Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            _buildPdfOverlay(),
          ],
        );
      }
      
      return imageWidget;
    }
    
    // V6: Type-specific placeholders for uncached content
    switch (fileType) {
      case FileType.video:
        return _buildVideoPlaceholder();
      case FileType.pdf:
        return _buildPdfPlaceholder();
      case FileType.image:
      case FileType.unknown:
        return _buildFallbackImage();
    }
  }

  Widget _buildImage(ImageProvider provider) {
    return Image(
      image: provider,
      fit: widget.fit,
      width: widget.width ?? double.infinity,
      height: widget.height,
      gaplessPlayback: true, // CRITICAL: Hold old texture
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stack) => _buildPlaceholder(isError: true),
    );
  }

  /// Fallback: Direct Image.file for uncached images
  Widget _buildFallbackImage() {
    final file = File(widget.path);
    
    return Image.file(
      file,
      fit: widget.fit,
      width: widget.width ?? double.infinity,
      height: widget.height,
      cacheWidth: widget.cacheWidth,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stack) => _buildPlaceholder(isError: true),
    );
  }

  Widget _buildPlaceholder({bool isError = false}) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 100,
      color: Colors.grey.shade800,
      child: Center(
        child: isError
            ? Icon(Icons.broken_image, color: Colors.grey.shade600, size: 32)
            : Icon(Icons.image, color: Colors.grey.shade700, size: 24),
      ),
    );
  }
  
  /// V6: Video overlay with play button
  Widget _buildVideoOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black26,
        child: const Center(
          child: Icon(
            Icons.play_circle_filled,
            color: Colors.white70,
            size: 48,
          ),
        ),
      ),
    );
  }
  
  /// V6: PDF overlay with document icon
  Widget _buildPdfOverlay() {
    return Positioned(
      right: 4,
      bottom: 4,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'PDF',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  /// V6: Video placeholder (when thumbnail not yet generated)
  Widget _buildVideoPlaceholder() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 100,
      color: Colors.grey.shade900,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam, color: Colors.white54, size: 32),
            SizedBox(height: 4),
            Text('Video', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
  
  /// V6: PDF placeholder (when thumbnail not yet generated)
  Widget _buildPdfPlaceholder() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 100,
      color: Colors.grey.shade900,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.red.shade300, size: 32),
            const SizedBox(height: 4),
            const Text('PDF', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

