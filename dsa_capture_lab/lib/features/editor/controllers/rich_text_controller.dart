import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

enum StyleType {
  bold,
  italic,
  underline,
  header1,
  header2,
}

class FormattingSpan {
  int start;
  int end;
  final StyleType type;

  FormattingSpan(this.start, this.end, this.type);

  FormattingSpan copyWith({int? start, int? end, StyleType? type}) {
    return FormattingSpan(
      start ?? this.start,
      end ?? this.end,
      type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      'type': type.index,
    };
  }

  factory FormattingSpan.fromJson(Map<String, dynamic> json) {
    return FormattingSpan(
      json['start'],
      json['end'],
      StyleType.values[json['type']],
    );
  }
}

class RichTextController extends TextEditingController {
  final List<FormattingSpan> _spans = [];

  RichTextController({super.text});

  @override
  set value(TextEditingValue newValue) {
    final  oldValue = value;
    final textChanged = oldValue.text != newValue.text;
    
    if (textChanged) {
      // Calculate diff
      final oldText = oldValue.text;
      final newText = newValue.text;
      
      // We need to know WHAT changed to shift spans.
      // Simple algorithm:
      // 1. Find common prefix.
      // 2. Find common suffix (from end).
      // 3. The middle is what changed.
      
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
      for (int i = 0; i < _spans.length; i++) {
        final span = _spans[i];
        
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
      _spans.removeWhere((s) => s.end <= s.start);
    }
    
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
     final List<TextSpan> children = [];
     final text = this.text;
     style ??= const TextStyle(color: Colors.white);
     
     // We need to flatten overlapping spans.
     // Simple way: Array of char styles.
     if (text.isEmpty) return TextSpan(style: style, text: "");
     
     // Optimization: List of style points.
     // Let's just do char loop for robustness since text is usually small (<100k chars for note).
     // Actually, simple span building:
     // Sort markers (start/end events).
     
     List<int> boundaries = {0, text.length}.toList();
     for (var s in _spans) {
       boundaries.add(s.start.clamp(0, text.length));
       boundaries.add(s.end.clamp(0, text.length));
     }
     boundaries = boundaries.toSet().toList()..sort();
     
     for (int i = 0; i < boundaries.length - 1; i++) {
        int start = boundaries[i];
        int end = boundaries[i+1];
        if (start >= end) continue;
        
        // Find active styles for this segment
        TextStyle segmentStyle = style;
        // Priority: H1 > H2 > B > I > U
        bool isBold = false;
        bool isItalic = false;
        bool isUnderline = false;
        bool isH1 = false;
        bool isH2 = false;
        
        for (var s in _spans) {
           if (s.start <= start && s.end >= end) {
              if (s.type == StyleType.bold) isBold = true;
              if (s.type == StyleType.italic) isItalic = true;
              if (s.type == StyleType.underline) isUnderline = true;
              if (s.type == StyleType.header1) isH1 = true;
              if (s.type == StyleType.header2) isH2 = true;
           }
        }
        
        if (isH1) {
           segmentStyle = segmentStyle.copyWith(fontSize: 24, fontWeight: FontWeight.bold);
        } else if (isH2) {
           segmentStyle = segmentStyle.copyWith(fontSize: 20, fontWeight: FontWeight.bold);
        }
        
        // Apply others (merging if header didn't override)
        if (isBold) segmentStyle = segmentStyle.copyWith(fontWeight: FontWeight.bold);
        if (isItalic) segmentStyle = segmentStyle.copyWith(fontStyle: FontStyle.italic);
        if (isUnderline) segmentStyle = segmentStyle.copyWith(decoration: TextDecoration.underline);
        
        children.add(TextSpan(text: text.substring(start, end), style: segmentStyle));
     }
     
     return TextSpan(style: style, children: children);
  }

  Set<StyleType> get currentStyles {
    final selection = this.selection;
    if (!selection.isValid) return {};
    
    final styles = <StyleType>{};
    for (var s in _spans) {
       // Check for inclusion.
       // For collapsed selection (cursor):
       if (selection.isCollapsed) {
          // If we are INSIDE a span [0, 5] and cursor is 3. Yes.
          // If we are at END [0, 5] and cursor is 5. Yes.
          // If we are at START [0, 5] and cursor is 0. Yes.
          if (s.start <= selection.start && s.end >= selection.start) {
             styles.add(s.type);
          }
       } else {
          // For range selection:
          // If the range overlaps with the span? 
          // Usually, toolbar highlights if ANY part is bold, or ALL is bold?
          // Google Docs: highlights if the START is bold.
          if (s.start <= selection.start && s.end > selection.start) {
             styles.add(s.type);
          }
       }
    }
    return styles;
  }

  void toggleStyle(StyleType type) {
    final selection = this.selection;
    if (!selection.isValid) return;
    
    final start = selection.start;
    final end = selection.end;
    
    // Check if a span of this type ENCLOSES the selection or is active at cursor
    FormattingSpan? enclosing;
    for (var s in _spans) {
       if (s.type == type) {
          // Exact match or Enclosing checks
          if (s.start <= start && s.end >= end) {
             enclosing = s;
             break;
          }
       }
    }
    
    if (enclosing != null) {
       // Turn OFF (remove/split)
       _spans.remove(enclosing);
       // Add back parts outside selection
       if (enclosing.start < start) {
         _spans.add(enclosing.copyWith(end: start));
       }
       if (enclosing.end > end) {
         _spans.add(enclosing.copyWith(start: end));
       }
    } else {
       // Turn ON
       _spans.add(FormattingSpan(start, end, type));
       _mergeSpans(type);
    }
    notifyListeners();
  }
  
  void _mergeSpans(StyleType type) {
    // Sort spans of type
    final typeSpans = _spans.where((s) => s.type == type).toList()
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
    _spans.removeWhere((s) => s.type == type);
    _spans.addAll(merged);
  }
  
  void clearFormatting() {
    final selection = this.selection;
    if (!selection.isValid) return;
    
    // Remove all spans intersecting selection
    // If partial intersection, clip them.
    for (int i = _spans.length - 1; i >= 0; i--) {
       final s = _spans[i];
       if (s.start < selection.end && s.end > selection.start) {
          _spans.removeAt(i);
          // Add back residuals
           if (s.start < selection.start) {
             _spans.add(s.copyWith(end: selection.start));
           }
           if (s.end > selection.end) {
             _spans.add(s.copyWith(start: selection.end));
           }
       }
    }
    notifyListeners();
  }

  String serialize() {
    // Save as JSON: { "text": "...", "spans": [...] }
    final data = {
      "text": text,
      "spans": _spans.map((s) => s.toJson()).toList(),
    };
    return jsonEncode(data);
  }

  void load(String data) {
    try {
      if (!data.trim().startsWith('{')) {
         // Assume Plain Text / Legacy Markdown
         text = data;
         _spans.clear();
         return;
      }
      
      final json = jsonDecode(data);
      text = json['text'] ?? "";
      _spans.clear();
      if (json['spans'] != null) {
        for (var s in json['spans']) {
          _spans.add(FormattingSpan.fromJson(s));
        }
      }
    } catch(e) {
      // Fallback
      text = data;
      _spans.clear();
    }
  }
}
