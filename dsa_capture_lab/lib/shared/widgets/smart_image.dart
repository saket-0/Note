import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/asset_pipeline/asset_pipeline_service.dart';

/// SmartImage - 3-Tier Cache-Aware Image Widget
/// 
/// Tier 1 (Hot): Flutter's native ImageCache (decoded bitmaps)
/// Tier 2 (Warm): AssetPipelineService (Uint8List raw bytes)
/// Tier 3 (Cold): Disk via AssetWorker isolate
/// 
/// Features:
/// - Synchronous cache lookup for instant display
/// - RepaintBoundary for isolated repaints (kills drag jitter)
/// - gaplessPlayback to prevent white flashes
/// - Priority loading for on-screen items
/// - No BuildContext dependency for caching
class SmartImage extends ConsumerStatefulWidget {
  /// Unique identifier for this image (used for ValueKey)
  final String fileId;
  
  /// Path to the image file
  final String path;
  
  final BoxFit fit;
  final double? height;
  final double? width;

  SmartImage({
    required this.fileId,
    required this.path,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
  }) : super(key: ValueKey('smart_$fileId'));

  @override
  ConsumerState<SmartImage> createState() => _SmartImageState();
}

class _SmartImageState extends ConsumerState<SmartImage> {
  Uint8List? _cachedBytes;
  bool _hasPrioritized = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  @override
  void didUpdateWidget(SmartImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _cachedBytes = null;
      _hasPrioritized = false;
      _isLoading = false;
      _checkCache();
    }
  }

  void _checkCache() {
    final pipeline = ref.read(assetPipelineServiceProvider);
    final bytes = pipeline.getCached(widget.path);
    
    if (bytes != null) {
      setState(() {
        _cachedBytes = bytes;
      });
    } else if (!_hasPrioritized) {
      _hasPrioritized = true;
      _isLoading = true;
      
      // Request priority load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          pipeline.prioritize(widget.path);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pipeline = ref.read(assetPipelineServiceProvider);
    
    // === TIER 2: Check Warm Cache (Uint8List) ===
    // This is synchronous and instant
    final bytes = _cachedBytes ?? pipeline.getCached(widget.path);
    
    if (bytes != null) {
      // Cache hit - store for future builds
      _cachedBytes = bytes;
      _isLoading = false;
      
      // CRITICAL: RepaintBoundary isolates this image's painting
      // Prevents repaints from bubbling up during grid reordering
      return RepaintBoundary(
        child: Image.memory(
          bytes,
          fit: widget.fit,
          width: widget.width ?? double.infinity,
          height: widget.height,
          gaplessPlayback: true, // Hold old texture during transitions
          frameBuilder: _buildFrame,
          errorBuilder: (context, error, stack) => _buildPlaceholder(isError: true),
        ),
      );
    }
    
    // === CACHE MISS: Show placeholder and wait for load ===
    if (!_hasPrioritized) {
      _hasPrioritized = true;
      _isLoading = true;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          pipeline.prioritize(widget.path);
        }
      });
    }
    
    // Listen for cache updates to rebuild when ready
    return ValueListenableBuilder<int>(
      valueListenable: pipeline.cacheUpdateNotifier,
      builder: (context, _, child) {
        // Check again in case cache was updated
        final updatedBytes = pipeline.getCached(widget.path);
        
        if (updatedBytes != null) {
          _cachedBytes = updatedBytes;
          _isLoading = false;
          
          return RepaintBoundary(
            child: Image.memory(
              updatedBytes,
              fit: widget.fit,
              width: widget.width ?? double.infinity,
              height: widget.height,
              gaplessPlayback: true,
              frameBuilder: _buildFrame,
              errorBuilder: (context, error, stack) => _buildPlaceholder(isError: true),
            ),
          );
        }
        
        return _buildPlaceholder();
      },
    );
  }

  /// Frame builder for smooth fade-in animation
  Widget _buildFrame(BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
    if (wasSynchronouslyLoaded) return child;
    
    return AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: child,
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
            : _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey,
                    ),
                  )
                : Icon(Icons.image, color: Colors.grey.shade700, size: 24),
      ),
    );
  }
}
