import '../domain/entities/entities.dart';

class LayoutService {
  static const int kSpacing = 1000000;

  /// Get position for a new item (TOP of the list).
  /// Assumes items are sorted by position DESC.
  static int getNewItemPosition(List<dynamic> items) {
    if (items.isEmpty) return kSpacing;
    
    // Find absolute max position regardless of sort
    int maxPos = 0; 
    for (final item in items) {
       int pos = 0;
       if (item is Note) pos = item.position;
       else if (item is Folder) pos = item.position;
       if (pos > maxPos) maxPos = pos;
    }
    
    // Always ensure new position is strictly greater than max
    return maxPos + kSpacing;
  }
  
  /// Get position to move an item to the TOP.
  static int getMoveToTopPosition(List<dynamic> items) {
    return getNewItemPosition(items);
  }

  /// Recalculate all positions with spacing (DESC order).
  /// [items] should be passed in the DESIRED order (Top to Bottom).
  static List<({dynamic item, int position})> reorderItems(List<dynamic> items) {
    final updates = <({dynamic item, int position})>[];
    final total = items.length;
    
    // Top item (index 0) gets highest position
    // Pos = (Total - Index) * Spacing
    for (int i = 0; i < total; i++) {
      final newPos = (total - i) * kSpacing;
      updates.add((item: items[i], position: newPos));
    }
    return updates;
  }
}
