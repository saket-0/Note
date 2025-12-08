/// Smart Drag Gesture Handler
/// 
/// Isolated gesture handler that distinguishes between:
/// 1. Tap (<200ms, no movement) → onTap
/// 2. Long press (>300ms, still) → onLongPress (selection mode)
/// 3. Long press + drag (>300ms, moved) → onDragStart
/// 
/// This mimics Google Keep's behavior where holding still selects,
/// but holding and moving starts dragging.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Configuration for gesture timings (matching Google Keep)
class SmartDragConfig {
  /// Max duration for a tap (ms)
  static const int tapThreshold = 200;
  
  /// Min duration for long press to trigger selection (ms)
  static const int longPressThreshold = 300;
  
  /// Movement threshold to consider as "moved" (pixels)
  static const double moveThreshold = 10.0;
}

/// A widget that intelligently handles tap, long press selection, and drag.
/// 
/// Key behavior: Long press only triggers AFTER user holds still for 300ms.
/// If they move during that time, it becomes a drag instead.
class SmartDraggable<T extends Object> extends StatefulWidget {
  /// Data to be passed when dragging
  final T data;
  
  /// The child widget
  final Widget child;
  
  /// Widget shown while dragging
  final Widget feedback;
  
  /// Widget shown in original position while dragging
  final Widget? childWhenDragging;
  
  /// Called on quick tap (< 200ms)
  final VoidCallback? onTap;
  
  /// Called on long press without movement (> 300ms, still)
  final VoidCallback? onLongPress;
  
  /// Called when drag starts (after long press + movement)
  final VoidCallback? onDragStarted;
  
  /// Called when drag ends
  final void Function(DraggableDetails)? onDragEnd;
  
  /// Called when drag completes successfully
  final VoidCallback? onDragCompleted;
  
  /// Whether dragging is currently enabled (e.g., disable in selection mode for normal items)
  final bool dragEnabled;
  
  const SmartDraggable({
    super.key,
    required this.data,
    required this.child,
    required this.feedback,
    this.childWhenDragging,
    this.onTap,
    this.onLongPress,
    this.onDragStarted,
    this.onDragEnd,
    this.onDragCompleted,
    this.dragEnabled = true,
  });
  
  @override
  State<SmartDraggable<T>> createState() => _SmartDraggableState<T>();
}

class _SmartDraggableState<T extends Object> extends State<SmartDraggable<T>> {
  // Gesture state
  Offset? _startPosition;
  DateTime? _startTime;
  Timer? _longPressTimer;
  bool _longPressTriggered = false;
  bool _isDragging = false;
  
  // For Draggable
  final GlobalKey _draggableKey = GlobalKey();
  
  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }
  
  void _onPointerDown(PointerDownEvent event) {
    _startPosition = event.position;
    _startTime = DateTime.now();
    _longPressTriggered = false;
    _isDragging = false;
    
    // Start long press timer
    _longPressTimer?.cancel();
    _longPressTimer = Timer(
      const Duration(milliseconds: SmartDragConfig.longPressThreshold),
      () {
        // Check if we're still holding and haven't moved much
        if (_startPosition != null && !_isDragging && mounted) {
          _longPressTriggered = true;
          HapticFeedback.heavyImpact();
          widget.onLongPress?.call();
        }
      },
    );
  }
  
  void _onPointerMove(PointerMoveEvent event) {
    if (_startPosition == null) return;
    
    final distance = (event.position - _startPosition!).distance;
    
    // If moved beyond threshold and long press hasn't triggered yet
    if (distance > SmartDragConfig.moveThreshold && !_longPressTriggered) {
      // Cancel long press timer - this is a drag, not a selection
      _longPressTimer?.cancel();
      
      // Check if we've held long enough to start dragging
      final holdDuration = DateTime.now().difference(_startTime!).inMilliseconds;
      if (holdDuration >= SmartDragConfig.longPressThreshold && widget.dragEnabled) {
        // Start drag
        _isDragging = true;
      }
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
    
    // Tap: Short press, no movement
    if (duration < SmartDragConfig.tapThreshold && 
        distance < SmartDragConfig.moveThreshold) {
      widget.onTap?.call();
    }
    
    _reset();
  }
  
  void _onPointerCancel(PointerCancelEvent event) {
    _longPressTimer?.cancel();
    _reset();
  }
  
  void _reset() {
    _startPosition = null;
    _startTime = null;
    _longPressTriggered = false;
    _isDragging = false;
  }
  
  @override
  Widget build(BuildContext context) {
    // Use standard Draggable wrapped with our gesture detection
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: LongPressDraggable<T>(
        key: _draggableKey,
        data: widget.data,
        delay: Duration(milliseconds: SmartDragConfig.longPressThreshold),
        feedback: widget.feedback,
        childWhenDragging: widget.childWhenDragging ?? Opacity(opacity: 0.3, child: widget.child),
        onDragStarted: () {
          // Only allow drag if long press already happened OR we moved
          if (_longPressTriggered || _isDragging) {
            widget.onDragStarted?.call();
          }
        },
        onDragEnd: widget.onDragEnd,
        onDragCompleted: widget.onDragCompleted,
        child: widget.child,
      ),
    );
  }
}

/// Simpler version: Just add tap/long press detection on top of existing Draggable
/// Use this as a wrapper around LongPressDraggable to add "hold still" detection
class TapLongPressDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  
  const TapLongPressDetector({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
  });
  
  @override
  State<TapLongPressDetector> createState() => _TapLongPressDetectorState();
}

class _TapLongPressDetectorState extends State<TapLongPressDetector> {
  Offset? _startPosition;
  DateTime? _startTime;
  Timer? _longPressTimer;
  bool _longPressTriggered = false;
  
  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _startPosition = event.position;
        _startTime = DateTime.now();
        _longPressTriggered = false;
        
        _longPressTimer?.cancel();
        _longPressTimer = Timer(
          const Duration(milliseconds: SmartDragConfig.longPressThreshold),
          () {
            // Check if still near start position
            if (_startPosition != null && mounted) {
              _longPressTriggered = true;
              HapticFeedback.heavyImpact();
              widget.onLongPress?.call();
            }
          },
        );
      },
      onPointerMove: (event) {
        if (_startPosition == null) return;
        
        final distance = (event.position - _startPosition!).distance;
        if (distance > SmartDragConfig.moveThreshold) {
          // User moved - cancel long press detection
          _longPressTimer?.cancel();
          _startPosition = null;
        }
      },
      onPointerUp: (event) {
        _longPressTimer?.cancel();
        
        if (_startTime == null || _startPosition == null || _longPressTriggered) {
          _reset();
          return;
        }
        
        final duration = DateTime.now().difference(_startTime!).inMilliseconds;
        final distance = (event.position - _startPosition!).distance;
        
        if (duration < SmartDragConfig.tapThreshold && 
            distance < SmartDragConfig.moveThreshold) {
          widget.onTap?.call();
        }
        
        _reset();
      },
      onPointerCancel: (_) {
        _longPressTimer?.cancel();
        _reset();
      },
      child: widget.child,
    );
  }
  
  void _reset() {
    _startPosition = null;
    _startTime = null;
    _longPressTriggered = false;
  }
}
