
import '../models/formatting_span.dart';
import 'dart:math';

class SpanUtils {
  
  static void shiftSpans({
    required String oldText,
    required String newText,
    required List<FormattingSpan> spans,
  }) {
    final textChanged = oldText != newText;
    
    if (textChanged) {
      // Calculate diff logic
      int commonPrefix = 0;
      while (commonPrefix < oldText.length && 
             commonPrefix < newText.length && 
             oldText[commonPrefix] == newText[commonPrefix]) {
        commonPrefix++;
      }
      
      int commonSuffix = 0;
      // We must not overlap with prefix
      while (commonSuffix < oldText.length - commonPrefix && 
             commonSuffix < newText.length - commonPrefix &&
             oldText[oldText.length - 1 - commonSuffix] == newText[newText.length - 1 - commonSuffix]) {
        commonSuffix++;
      }
      
      final oldSelectionLength = oldText.length - commonPrefix - commonSuffix;
      final newSelectionLength = newText.length - commonPrefix - commonSuffix;
      
      final delta = newSelectionLength - oldSelectionLength;
      
      int mapIndex(int idx) {
         if (idx <= commonPrefix) return idx;
         if (idx >= commonPrefix + oldSelectionLength) return idx + delta;
         return commonPrefix; 
      }
      
      // Update spans
      for (int i = 0; i < spans.length; i++) {
        final span = spans[i];
        
        // Cases:
        // 1. Change is strictly AFTER span: No effect.
        if (commonPrefix > span.end) continue;
        
        // 2. Change is strictly BEFORE span: Shift span by delta.
        if (commonPrefix + oldSelectionLength < span.start) {
            span.start += delta;
            span.end += delta;
            continue;
        }

        // 3. Change OVERLAPS/INSIDE span:
        // If inserting inside, expand span.
        // If deleting inside, shrink span.
        
        // Special case: Insertion inside/boundary of span
        if (oldSelectionLength == 0 && newSelectionLength > 0) {
             // Insertion
             if (commonPrefix >= span.start && commonPrefix <= span.end) {
                if (commonPrefix == span.start) {
                   if (span.start == span.end) {
                      // Empty span at insertion point -> EXPAND (Toggle -> Type case)
                      span.end += delta;
                   } else {
                      // Non-empty span -> Shift (Right affinity at start of span)
                      span.start += delta;
                      span.end += delta;
                   }
                } else {
                   // Inside or at End -> Expand
                   span.end += delta;
                }
                continue;
             }
        }
        
        span.start = mapIndex(span.start);
        span.end = mapIndex(span.end);
        
        // Sanity check
        if (span.end < span.start) span.end = span.start; // Collapsed
      }
      
      // Remove collapsed spans? Maybe keep them for a moment if we want empty bold? 
      // For clean up:
      spans.removeWhere((s) => s.end <= s.start);
    }
  }

  static void mergeSpans(List<FormattingSpan> spans, StyleType type) {
    // Sort spans of type
    final typeSpans = spans.where((s) => s.type == type).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
      
    if (typeSpans.isEmpty) return;
    
    // Merge
    final List<FormattingSpan> merged = [];
    FormattingSpan current = typeSpans.first;
    
    for (int i = 1; i < typeSpans.length; i++) {
       final next = typeSpans[i];
       if (next.start <= current.end) {
          // Overlap or touching -> Merge
          current.end = max(current.end, next.end);
       } else {
          merged.add(current);
          current = next;
       }
    }
    merged.add(current);
    
    // Rebuild main list
    spans.removeWhere((s) => s.type == type);
    spans.addAll(merged);
  }
}
