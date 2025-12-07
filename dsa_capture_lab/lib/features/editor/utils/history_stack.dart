import 'package:flutter/material.dart';

class HistoryStack<T> {
  final List<T> _stack = [];
  int _index = -1;
  final int limit;

  HistoryStack({this.limit = 50});

  bool get canUndo => _index > 0;
  bool get canRedo => _index < _stack.length - 1;

  T? get currentState => _index >= 0 && _index < _stack.length ? _stack[_index] : null;

  void push(T state) {
    // If we are not at the end, remove everything after current index (branching)
    if (_index < _stack.length - 1) {
      _stack.removeRange(_index + 1, _stack.length);
    }
    
    // Add new state
    _stack.add(state);
    _index++;

    // Enforce limit
    if (_stack.length > limit) {
      _stack.removeAt(0);
      _index--; 
    }
  }

  T? undo() {
    if (!canUndo) return null;
    _index--;
    return _stack[_index];
  }

  T? redo() {
    if (!canRedo) return null;
    _index++;
    return _stack[_index];
  }

  void clear() {
    _stack.clear();
    _index = -1;
  }
}
