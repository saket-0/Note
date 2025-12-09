import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/smart_cache_engine.dart';

/// LazyImage v2 - Fast & Lightweight
/// 
/// Features:
/// - **No VisibilityDetector**: Removed for performance
/// - **Cache-first**: Instant render if cached
/// - **Prioritize on-screen**: Tells engine to load immediately
/// - **gaplessPlayback**: Holds old texture, no white flashes
/// - **didUpdateWidget**: Handles path changes properly
class LazyImage extends ConsumerStatefulWidget {
  final String path;
  final BoxFit fit;
  final int cacheWidth;
  final double? height;
  final double? width;

  const LazyImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.cacheWidth = 400,
    this.height,
    this.width,
  });

  @override
  ConsumerState<LazyImage> createState() => _LazyImageState();
}

class _LazyImageState extends ConsumerState<LazyImage> {
  bool _hasPrioritized = false;

  @override
  void didUpdateWidget(LazyImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Path changed - need to re-prioritize
    if (oldWidget.path != widget.path) {
      _hasPrioritized = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(smartCacheEngineProvider(context));
    final isCached = engine.isCached(widget.path);
    
    if (isCached) {
      // INSTANT: Image is cached, render immediately
      return _buildImage();
    }
    
    // NOT CACHED: Show placeholder and prioritize loading
    if (!_hasPrioritized) {
      _hasPrioritized = true;
      // Tell engine: "I'm on screen, load me NOW!"
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          engine.prioritize(widget.path);
        }
      });
    }
    
    // Listen for cache updates to rebuild when ready
    return ValueListenableBuilder<Set<String>>(
      valueListenable: engine.cachedPathsNotifier,
      builder: (context, cachedPaths, child) {
        if (cachedPaths.contains(widget.path)) {
          return _buildImage();
        }
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildImage() {
    return Image.file(
      File(widget.path),
      fit: widget.fit,
      width: widget.width ?? double.infinity,
      height: widget.height,
      cacheWidth: widget.cacheWidth,
      // CRITICAL: Holds old texture until new one is ready
      gaplessPlayback: true,
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

  Widget _buildPlaceholder({bool isError = false}) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 100,
      color: Colors.grey.shade800,
      child: Center(
        child: isError
            ? Icon(Icons.broken_image, color: Colors.grey.shade600, size: 32)
            : const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.grey,
                ),
              ),
      ),
    );
  }
}
