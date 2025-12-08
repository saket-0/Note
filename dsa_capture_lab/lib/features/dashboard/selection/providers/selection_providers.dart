/// Selection Module - Providers
/// 
/// Isolated state management for multi-select functionality.
/// Errors here do not affect other dashboard features.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================
// SELECTION STATE PROVIDERS
// ============================================

/// Set of selected item keys: "note_123" or "folder_456"
final selectedItemsProvider = StateProvider<Set<String>>((ref) => {});

/// Convenience: Is selection mode currently active?
final isSelectionModeProvider = Provider<bool>((ref) {
  return ref.watch(selectedItemsProvider).isNotEmpty;
});

/// Convenience: Current selection count
final selectionCountProvider = Provider<int>((ref) {
  return ref.watch(selectedItemsProvider).length;
});

/// Check if a specific item is selected
final isItemSelectedProvider = Provider.family<bool, String>((ref, itemKey) {
  return ref.watch(selectedItemsProvider).contains(itemKey);
});

// ============================================
// DRAG STATE PROVIDER
// ============================================

/// Is any item currently being dragged?
/// Used to hide the top bar during active drag
final isDraggingProvider = StateProvider<bool>((ref) => false);

