import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hardware_cache_engine.dart';

/// StableImage - V4 "Hardware-Native" Widget
/// 
/// Features:
/// - **RepaintBoundary**: Isolates painting from layout (kills drag jitter)
/// - **Synchronous lookup**: Uses cached ImageProvider immediately
/// - **Gapless playback**: Holds old texture during transitions
/// - **ValueKey enforcement**: Uses fileId for stable identity
/// - **No BuildContext dependency**: Uses singleton HardwareCacheEngine
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
    final engine = ref.watch(hardwareCacheEngineProvider);
    
    // SYNCHRONOUS: Always check cache first in build (survives parent rebuilds)
    final cachedProvider = engine.getProvider(widget.path);
    if (cachedProvider != null) {
      _cachedProvider = cachedProvider;
    } else if (!_hasPrioritized) {
      // Prioritize if not cached and not already prioritized
      _hasPrioritized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          engine.prioritize(widget.path);
        }
      });
    }
    
    // Listen for cache updates (for images not yet cached)
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
          child: _cachedProvider != null 
              ? _buildImage(_cachedProvider!)
              : _buildFallbackImage(),
        );
      },
    );
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
}
