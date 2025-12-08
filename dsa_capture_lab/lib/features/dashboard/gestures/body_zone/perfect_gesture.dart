/// Perfect Gesture Handler
/// 
/// Implements the "Perfect Timing & Action Protocol" for notes app.
/// This is a fluid state machine, not rigid switches.
/// 
/// Magic Numbers:
/// - TAP_TIMEOUT: 200ms - anything faster is a click
/// - LONG_PRESS_DELAY: 350ms - the sweet spot for selection/drag unlock
/// - DRAG_SLOP: 10px - minimum movement to consider as intentional drag
/// - GROUPING_DWELL: 600ms - hover time to create folder vs reorder
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Configuration constants - DO NOT CHANGE without UX testing
class GestureConfig {
  static const int tapTimeout = 200;        // ms
  static const int longPressDelay = 350;    // ms  
  static const double dragSlop = 10.0;      // pixels
  static const int groupingDwell = 600;     // ms
}

/// Gesture state machine states
enum GestureState {
  idle,           // No touch
  touching,       // Finger down, waiting
  selected,       // 350ms passed, item selected/ready
  dragging,       // User is moving the item
}

/// A widget that implements the Perfect Gesture Protocol.
/// 
/// Normal Mode:
/// - Tap (<200ms): Open item
/// - Hold (350ms): Enter selection + haptic
/// - Hold + Move: Drag single item
/// 
/// Selection Mode:
/// - Tap (<200ms): Toggle selection
/// - Hold (350ms): Visual "lift" ready to move
/// - Hold + Move: Drag ALL selected items
class PerfectGestureDetector extends StatefulWidget {
  final Widget child;
  
  /// Called when user taps (< 200ms, no movement)
  final VoidCallback? onTap;
  
  /// Called when long press triggers (at 350ms, still holding)
  final VoidCallback? onLongPress;
  
  /// Called when drag starts (after 350ms + movement)
  final VoidCallback? onDragStart;
  
  /// Called during drag with position updates
  final void Function(Offset globalPosition)? onDragUpdate;
  
  /// Called when drag ends
  final VoidCallback? onDragEnd;
  
  /// Whether we're currently in selection mode
  final bool isSelectionMode;
  
  /// Whether this item is currently selected
  final bool isSelected;
  
  const PerfectGestureDetector({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.isSelectionMode = false,
    this.isSelected = false,
  });
  
  @override
  State<PerfectGestureDetector> createState() => _PerfectGestureDetectorState();
}

class _PerfectGestureDetectorState extends State<PerfectGestureDetector> {
  GestureState _state = GestureState.idle;
  Offset? _startPosition;
  DateTime? _startTime;
  Timer? _longPressTimer;
  bool _dragUnlocked = false; // True after 350ms - drag is now allowed
  
  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }
  
  void _onPointerDown(PointerDownEvent event) {
    _startPosition = event.position;
    _startTime = DateTime.now();
    _state = GestureState.touching;
    _dragUnlocked = false;
    
    // Start 350ms timer
    _longPressTimer?.cancel();
    _longPressTimer = Timer(
      const Duration(milliseconds: GestureConfig.longPressDelay),
      _onLongPressTriggered,
    );
  }
  
  void _onLongPressTriggered() {
    if (_state != GestureState.touching || !mounted) return;
    
    // 350ms passed while holding still - UNLOCK drag and trigger selection
    _dragUnlocked = true;
    _state = GestureState.selected;
    
    // Haptic feedback
    if (widget.isSelectionMode) {
      // Already in selection mode - light haptic for "ready to move"
      HapticFeedback.lightImpact();
    } else {
      // Entering selection mode - heavy haptic
      HapticFeedback.heavyImpact();
    }
    
    // Notify: Long press triggered
    widget.onLongPress?.call();
   
    // Force rebuild for visual feedback (scale, etc.)
    if (mounted) setState(() {});
  }
  
  void _onPointerMove(PointerMoveEvent event) {
    if (_startPosition == null) return;
    
    final distance = (event.position - _startPosition!).distance;
    
    if (_state == GestureState.touching) {
      // Still in "waiting" phase (0-350ms)
      if (distance > GestureConfig.dragSlop) {
        // User moved too much during wait - this is a SCROLL, not a gesture
        // Cancel everything and let parent ScrollView handle it
        _cancelGesture();
        return;
      }
    } else if (_state == GestureState.selected && _dragUnlocked) {
      // After 350ms, user is moving - START DRAG
      if (distance > GestureConfig.dragSlop) {
        _state = GestureState.dragging;
        widget.onDragStart?.call();
      }
    } else if (_state == GestureState.dragging) {
      // Already dragging - update position
      widget.onDragUpdate?.call(event.position);
    }
  }
  
  void _onPointerUp(PointerUpEvent event) {
    _longPressTimer?.cancel();
    
    if (_startTime == null || _startPosition == null) {
      _reset();
      return;
    }
    
    final duration = DateTime.now().difference(_startTime!).inMilliseconds;
    final distance = (event.position - _startPosition!).distance;
    
    switch (_state) {
      case GestureState.touching:
        // Released before 350ms
        if (duration < GestureConfig.tapTimeout && distance < GestureConfig.dragSlop) {
          // Quick tap - execute tap action
          widget.onTap?.call();
        }
        // If 200-350ms and no movement, it's just a slow tap - still do tap
        else if (distance < GestureConfig.dragSlop) {
          widget.onTap?.call();
        }
        break;
        
      case GestureState.selected:
        // Long press happened but no drag - item is selected, don't toggle
        // (The selection already happened in onLongPressTriggered)
        break;
        
      case GestureState.dragging:
        // Drag ended
        widget.onDragEnd?.call();
        break;
        
      case GestureState.idle:
        break;
    }
    
    _reset();
  }
  
  void _onPointerCancel(PointerCancelEvent event) {
    _cancelGesture();
  }
  
  void _cancelGesture() {
    _longPressTimer?.cancel();
    if (_state == GestureState.dragging) {
      widget.onDragEnd?.call();
    }
    _reset();
  }
  
  void _reset() {
    _longPressTimer?.cancel();
    _startPosition = null;
    _startTime = null;
    _dragUnlocked = false;
    if (mounted) {
      setState(() => _state = GestureState.idle);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Visual scale based on state
    double scale = 1.0;
    if (_state == GestureState.selected || _state == GestureState.dragging) {
      scale = 1.03; // Slight lift when ready to drag or dragging
    }
    
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

/// Mixin for dwell-to-group logic on DragTarget
/// 
/// The 600ms dwell algorithm:
/// 1. User drags item A
/// 2. User crosses item B → Immediate reorder visual
/// 3. User pauses over B → Start 600ms timer
/// 4. If timer completes → Show "folder" indicator
/// 5. On drop: Check if timer completed
///    - Yes: Merge into folder
///    - No: Just reorder
mixin DwellToGroupMixin<T extends StatefulWidget> on State<T> {
  Timer? _dwellTimer;
  bool _dwellCompleted = false;
  String? _dwellTargetKey;
  
  /// Call when drag enters a potential drop target
  void startDwellTimer(String targetKey) {
    if (_dwellTargetKey == targetKey) return; // Already timing this target
    
    cancelDwellTimer();
    _dwellTargetKey = targetKey;
    _dwellCompleted = false;
    
    _dwellTimer = Timer(
      const Duration(milliseconds: GestureConfig.groupingDwell),
      () {
        if (mounted) {
          _dwellCompleted = true;
          HapticFeedback.mediumImpact(); // Double-click feel
          HapticFeedback.lightImpact();
          setState(() {}); // Trigger visual update
        }
      },
    );
  }
  
  /// Call when drag leaves the target
  void cancelDwellTimer() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _dwellTargetKey = null;
    _dwellCompleted = false;
  }
  
  /// Check if dwell completed (for deciding merge vs reorder)
  bool get shouldCreateFolder => _dwellCompleted;
  
  /// Current dwell target
  String? get dwellTargetKey => _dwellTargetKey;
  
  @override
  void dispose() {
    _dwellTimer?.cancel();
    super.dispose();
  }
}
