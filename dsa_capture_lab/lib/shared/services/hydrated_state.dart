import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phoenix Protocol: Session state that survives process death
/// 
/// === INDUSTRY GRADE 10/10 PERFORMANCE ===
/// 
/// On AppLifecycleState.paused:
///   - Serialize currentFolderId + scrollOffset to SharedPreferences
/// 
/// On App Launch:
///   - Load persisted state synchronously (as fast as possible)
///   - Restore user to exact folder and scroll position
/// 
/// Result: User returns to EXACTLY where they left off, even after OS kills app
class HydratedState {
  static const _key = 'phoenix_state_v1';
  
  /// Current folder ID (null = root)
  int? currentFolderId;
  
  /// Scroll offset in the grid (for position restoration)
  double scrollOffset;
  
  /// Timestamp when state was saved (for debugging/staleness)
  DateTime? savedAt;
  
  HydratedState({
    this.currentFolderId,
    this.scrollOffset = 0.0,
    this.savedAt,
  });
  
  /// Load persisted state from SharedPreferences
  /// Returns empty state if nothing persisted or if data is stale (>24h)
  static Future<HydratedState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      
      if (json == null) {
        debugPrint('[Phoenix] No persisted state found');
        return HydratedState();
      }
      
      final map = jsonDecode(json) as Map<String, dynamic>;
      
      // Check staleness (discard if >24 hours old)
      final savedAt = map['savedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['savedAt'] as int)
          : null;
      if (savedAt != null && DateTime.now().difference(savedAt).inHours > 24) {
        debugPrint('[Phoenix] State too old (${DateTime.now().difference(savedAt).inHours}h), discarding');
        return HydratedState();
      }
      
      final state = HydratedState(
        currentFolderId: map['folderId'] as int?,
        scrollOffset: (map['scrollOffset'] as num?)?.toDouble() ?? 0.0,
        savedAt: savedAt,
      );
      
      debugPrint('[Phoenix] Loaded: folderId=${state.currentFolderId}, scroll=${state.scrollOffset}');
      return state;
    } catch (e) {
      debugPrint('[Phoenix] Load failed: $e');
      return HydratedState();
    }
  }
  
  /// Save current state to SharedPreferences
  /// Fire-and-forget, no await needed
  Future<void> save() async {
    try {
      savedAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode({
        'folderId': currentFolderId,
        'scrollOffset': scrollOffset,
        'savedAt': savedAt!.millisecondsSinceEpoch,
      }));
      
      debugPrint('[Phoenix] Saved: folderId=$currentFolderId, scroll=$scrollOffset');
    } catch (e) {
      debugPrint('[Phoenix] Save failed: $e');
    }
  }
  
  /// Clear persisted state (for debugging or logout)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    debugPrint('[Phoenix] State cleared');
  }
  
  @override
  String toString() => 'HydratedState(folderId: $currentFolderId, scroll: $scrollOffset)';
}

/// Provider for loading HydratedState at app startup
/// Use FutureProvider so UI can show loading while state is retrieved
final hydratedStateProvider = FutureProvider<HydratedState>((ref) async {
  return HydratedState.load();
});

/// StateNotifier for updating current scroll position
/// DashboardContent calls this on scroll to track position for Phoenix save
class ScrollPositionNotifier extends StateNotifier<double> {
  ScrollPositionNotifier() : super(0.0);
  
  void update(double offset) {
    state = offset;
  }
}

final scrollPositionProvider = StateNotifierProvider<ScrollPositionNotifier, double>((ref) {
  return ScrollPositionNotifier();
});
