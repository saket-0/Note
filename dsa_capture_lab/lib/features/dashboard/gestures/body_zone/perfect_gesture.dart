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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../selection/selection.dart';

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
  touching,       // Finger down, waiting for 350ms
  selected,       // 350ms passed, item selected/lifted, waiting for movement
  dragging,       // User crossed drag threshold, actively moving
}

/// A widget that implements the Perfect Gesture Protocol.
/// 
/// The key insight: Long press (350ms) selects but does NOT immediately drag.
/// User must move > 10px AFTER selection to start dragging.
/// 
/// IMPORTANT: This widget reads isSelectionModeProvider DIRECTLY in gesture
/// handlers to avoid stale state bugs. Do NOT rely on passed-in isSelectionMode.
/// 
/// Normal Mode:
/// - Tap (<200ms): Open item
/// - Hold (350ms): Enter selection + haptic (NO movement yet)
/// - Hold + Move (>10px): Start dragging
/// 
/// Selection Mode (locked grid):
/// - Tap (<200ms): Toggle selection
/// - Hold (350ms): Visual feedback only
/// - Movement: Treated as scroll, NOT drag
class PerfectGestureDetector extends ConsumerStatefulWidget {
  final Widget child;
  
  /// Called when user taps (< 200ms, no movement)
  final VoidCallback? onTap;
  
  /// Called when long press triggers (at 350ms, still holding)
  final VoidCallback? onLongPress;
  
  /// Called when drag starts (after 350ms + movement > 10px)
  final VoidCallback? onDragStart;
  
  /// Called during drag with position updates
  final void Function(Offset globalPosition)? onDragUpdate;
  
  /// Called when drag ends
  final VoidCallback? onDragEnd;
  
  /// Called when drag state changes (true = dragging, false = stopped)
  /// Use this to hide/show the top bar
  final void Function(bool isDragging)? onDragStateChanged;
  
  /// Whether this item is currently selected (for visual feedback)
  final bool isSelected;
  
  const PerfectGestureDetector({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragStateChanged,
    this.isSelected = false,
  });
  
  @override
  ConsumerState<PerfectGestureDetector> createState() => _PerfectGestureDetectorState();
}

class _PerfectGestureDetectorState extends ConsumerState<PerfectGestureDetector> {
  GestureState _state = GestureState.idle;
  Offset? _startPosition;
  Offset? _longPressPosition; // Position when long press triggered
  DateTime? _startTime;
  Timer? _longPressTimer;
  
  // THE DRAG GATE: Only true after 350ms AND movement > DRAG_SLOP
  bool _hasCrossedDragThreshold = false;
  
  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }
  
  void _onPointerDown(PointerDownEvent event) {
    _startPosition = event.position;
    _startTime = DateTime.now();
    _state = GestureState.touching;
    _hasCrossedDragThreshold = false;
    _longPressPosition = null;
    
    // Start 350ms timer
    _longPressTimer?.cancel();
    _longPressTimer = Timer(
      const Duration(milliseconds: GestureConfig.longPressDelay),
      _onLongPressTriggered,
    );
  }
  
  void _onLongPressTriggered() {
    if (_state != GestureState.touching || !mounted) return;
    
    // 350ms passed while holding still - item is now SELECTED
    // But NOT yet dragging! User must move to drag.
    _state = GestureState.selected;
    _longPressPosition = _startPosition; // Remember where we were when selected
    
    // READ LIVE STATE: Check current selection mode from provider
    // Guard: ensure widget is still mounted before accessing ref
    if (!mounted) return;
    final isSelectionMode = ref.read(isSelectionModeProvider);
    
    // Haptic feedback
    if (isSelectionMode) {
      // Already in selection mode - light haptic for "ready"
      HapticFeedback.lightImpact();
    } else {
      // Entering selection mode - heavy haptic
      HapticFeedback.heavyImpact();
    }
    
    // Notify: Long press triggered (selection happens)
    widget.onLongPress?.call();
   
    // Force rebuild for visual feedback (scale, etc.)
    if (mounted) setState(() {});
  }
  
  void _onPointerMove(PointerMoveEvent event) {
    if (_startPosition == null) return;
    
    final distanceFromStart = (event.position - _startPosition!).distance;
    
    switch (_state) {
      case GestureState.touching:
        // Still waiting for 350ms timer
        if (distanceFromStart > GestureConfig.dragSlop) {
          // User moved too much during wait - this is a SCROLL, not selection
          // Cancel everything and let parent ScrollView handle it
          _cancelGesture();
        }
        break;
        
      case GestureState.selected:
        // Item is selected, waiting for drag threshold
        
        // Guard: ensure widget is still mounted before accessing ref
        if (!mounted) return;
        
        // READ LIVE STATE: Check current selection mode from provider
        // This fixes the 'stale state' bug where other items don't know selection mode changed
        final isSelectionMode = ref.read(isSelectionModeProvider);
        
        // CRITICAL: In Selection Mode, disable ALL drag-to-reorder logic
        // Grid should be locked. Movement = scroll, not drag.
        if (isSelectionMode) {
          // In selection mode: treat movement as scroll, cancel gesture
          if (distanceFromStart > GestureConfig.dragSlop) {
            _cancelGesture(); // Let parent ScrollView handle it
          }
          break;
        }
        
        // Normal mode: allow drag after crossing threshold
        final distanceFromLongPress = _longPressPosition != null 
            ? (event.position - _longPressPosition!).distance 
            : distanceFromStart;
        
        if (!_hasCrossedDragThreshold) {
          if (distanceFromLongPress > GestureConfig.dragSlop) {
            // GATE OPENED - User deliberately moved after selection
            _hasCrossedDragThreshold = true;
            _state = GestureState.dragging;
            
            // Notify: Drag state changed (hide top bar)
            widget.onDragStateChanged?.call(true);
            widget.onDragStart?.call();
          }
          // If not crossed threshold, do nothing - finger shake tolerance
        }
        break;
        
      case GestureState.dragging:
        // Already dragging - update position
        widget.onDragUpdate?.call(event.position);
        break;
        
      case GestureState.idle:
        break;
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
        // Released before 350ms - this is a TAP
        if (distance < GestureConfig.dragSlop) {
          widget.onTap?.call();
        }
        break;
        
      case GestureState.selected:
        // Long press happened but NO drag (gate never opened)
        // Item stays selected, note "drops" back to original slot
        // Selection already happened in onLongPressTriggered - do nothing more
        break;
        
      case GestureState.dragging:
        // User was dragging - finalize
        widget.onDragEnd?.call();
        // Notify: Drag state changed (show top bar again)
        widget.onDragStateChanged?.call(false);
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
      widget.onDragStateChanged?.call(false);
    }
    _reset();
  }
  
  void _reset() {
    _longPressTimer?.cancel();
    _startPosition = null;
    _startTime = null;
    _longPressPosition = null;
    _hasCrossedDragThreshold = false;
    if (mounted) {
      setState(() => _state = GestureState.idle);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Visual scale based on state
    double scale = 1.0;
    if (_state == GestureState.selected) {
      scale = 1.02; // Slight lift when selected (ready to drag)
    } else if (_state == GestureState.dragging) {
      scale = 1.05; // Larger lift when actively dragging
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
