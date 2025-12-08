/// Body Zone Gesture Handler
/// 
/// Isolated gesture logic for the note/folder body (Zone A).
/// Handles: Tap, Long Press, Drag-to-Reorder, Dwell-to-Group.
/// Errors here do not affect other features.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Configuration for body zone gesture timings
class BodyZoneConfig {
  /// Maximum duration for a tap (ms)
  static const int tapThreshold = 200;
  
  /// Minimum duration for long press to trigger selection (ms)
  static const int longPressThreshold = 300;
  
  /// Dwell time on another item to trigger merge/group (ms)
  static const int dwellToMergeThreshold = 600;
  
  /// Scale factor when item is selected
  static const double selectedScale = 0.95;
  
  /// Scale factor when item is being dragged
  static const double draggingScale = 1.05;
}

/// Gesture state for body zone
enum BodyZoneState {
  idle,
  pressing,
  selected,
  dragging,
  hoveringForMerge,
}

/// Callback types for gesture events
typedef OnItemTap = void Function();
typedef OnItemLongPress = void Function();
typedef OnItemDragStart = void Function();
typedef OnItemDragUpdate = void Function(Offset position);
typedef OnItemDragEnd = void Function(Offset position);
typedef OnItemDrop = void Function(String targetKey, String zone);

/// Mixin to add body zone gesture handling to a StatefulWidget state
mixin BodyZoneGestureMixin<T extends StatefulWidget> on State<T> {
  
  // Hover state for merge detection
  DateTime? _hoverStartTime;
  Timer? _mergeTimer;
  bool _isHoveringForMerge = false;
  
  /// Start tracking hover time for merge detection
  void startHoverTracking() {
    _hoverStartTime = DateTime.now();
    _mergeTimer?.cancel();
    _mergeTimer = Timer(
      const Duration(milliseconds: BodyZoneConfig.dwellToMergeThreshold),
      () {
        if (mounted && _hoverStartTime != null) {
          setState(() => _isHoveringForMerge = true);
          HapticFeedback.mediumImpact();
        }
      },
    );
  }
  
  /// Reset hover tracking
  void resetHoverTracking() {
    _hoverStartTime = null;
    _mergeTimer?.cancel();
    _mergeTimer = null;
    if (_isHoveringForMerge && mounted) {
      setState(() => _isHoveringForMerge = false);
    }
  }
  
  /// Check if currently hovering long enough for merge
  bool get isHoveringForMerge => _isHoveringForMerge;
  
  /// Get current hover zone ('merge' or 'reorder')
  String get currentHoverZone => _isHoveringForMerge ? 'merge' : 'reorder';
  
  @override
  void dispose() {
    _mergeTimer?.cancel();
    super.dispose();
  }
}

/// Widget that provides the "Folder Ring" merge indicator animation
class MergeIndicator extends StatelessWidget {
  final bool showMergeRing;
  final Widget child;
  
  const MergeIndicator({
    super.key,
    required this.showMergeRing,
    required this.child,
  });
  
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: showMergeRing 
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.blueAccent,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          )
        : null,
      child: child,
    );
  }
}
