
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_capture_lab/features/editor/models/formatting_span.dart';
import 'package:dsa_capture_lab/features/editor/models/checklist_item.dart';
import 'package:dsa_capture_lab/features/editor/utils/span_utils.dart';
import 'package:dsa_capture_lab/features/editor/utils/checklist_utils.dart';

void main() {
  group('SpanUtils', () {
    test('shifts spans when inserting text before span', () {
      // "Hello " -> bold "World"
      // Insert "Big " at start -> "Big Hello " -> bold "World"
      final spans = [FormattingSpan(6, 11, StyleType.bold)]; // "World"
      final oldText = "Hello World";
      final newText = "Big Hello World"; // Inserted 4 chars "Big "
      
      SpanUtils.shiftSpans(oldText: oldText, newText: newText, spans: spans);
      
      expect(spans.length, 1);
      expect(spans[0].start, 10);
      expect(spans[0].end, 15);
    });

    test('expands span when appending text at span boundary (Sticky Behavior)', () {
      final spans = [FormattingSpan(0, 5, StyleType.bold)]; // "Hello"
      final oldText = "Hello";
      final newText = "Hello World";
      
      SpanUtils.shiftSpans(oldText: oldText, newText: newText, spans: spans);
      
      expect(spans[0].start, 0);
      expect(spans[0].end, 11); // Expanded to include " World"
    });

    test('does not shift spans when change is strictly after span', () {
      final spans = [FormattingSpan(0, 2, StyleType.bold)]; // "He"
      final oldText = "Hello";
      final newText = "Hello World";
      
      SpanUtils.shiftSpans(oldText: oldText, newText: newText, spans: spans);
      
      expect(spans[0].start, 0);
      expect(spans[0].end, 2); // Should remain "He"
    });
    
    test('expands span when typing inside span', () {
      // "He[llo] World" -> "He[lXlo] World"
      // Span on "llo" (2, 5)
      final spans = [FormattingSpan(2, 5, StyleType.bold)];
      final oldText = "Hello World";
      final newText = "HelXlo World";
      
      SpanUtils.shiftSpans(oldText: oldText, newText: newText, spans: spans);
      
      expect(spans[0].start, 2);
      expect(spans[0].end, 6); // Expanded by 1
    });

    test('shrinks span when deleting inside span', () {
      // "He[llo] World" -> "He[lo] World"
      final spans = [FormattingSpan(2, 5, StyleType.bold)];
      final oldText = "Hello World";
      final newText = "Helo World"; 
      
      SpanUtils.shiftSpans(oldText: oldText, newText: newText, spans: spans);
      
      expect(spans[0].start, 2);
      expect(spans[0].end, 4); // Shrunk by 1
    });
    
     test('merges overlapping spans of same type', () {
      final spans = [
        FormattingSpan(0, 5, StyleType.bold),
        FormattingSpan(4, 10, StyleType.bold), // Overlap
      ];
      
      SpanUtils.mergeSpans(spans, StyleType.bold);
      
      expect(spans.length, 1);
      expect(spans[0].start, 0);
      expect(spans[0].end, 10);
    });
  });

  group('ChecklistUtils', () {
    test('parses checklist correctly', () {
      final content = "[x] Item 1\n[ ] Item 2";
      final items = ChecklistUtils.parse(content);
      
      expect(items.length, 2);
      expect(items[0].isChecked, true);
      expect(items[0].text, "Item 1");
      expect(items[1].isChecked, false);
      expect(items[1].text, "Item 2");
    });
    
    test('converts back to string correctly', () {
      final items = [
        ChecklistItem(isChecked: true, text: "Done"),
        ChecklistItem(isChecked: false, text: "Todo"),
      ];
      
      final content = ChecklistUtils.toContent(items);
      expect(content, "[x] Done\n[ ] Todo");
    });
  });
}
