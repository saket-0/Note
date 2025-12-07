import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/formatting_span.dart';
import '../utils/span_utils.dart';


class RichTextController extends TextEditingController {
  final List<FormattingSpan> _spans = [];

  RichTextController({super.text});

  @override
  set value(TextEditingValue newValue) {
    final  oldValue = value;
    final textChanged = oldValue.text != newValue.text;
    
    if (textChanged) {
      SpanUtils.shiftSpans(
        oldText: oldValue.text,
        newText: newValue.text,
        spans: _spans,
      );
    }
    
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
     final List<TextSpan> children = [];
     final text = this.text;
     style ??= const TextStyle(color: Colors.white);
     
     if (text.isEmpty) return TextSpan(style: style, text: "");
     
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
        
        TextStyle segmentStyle = style;
        
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
       if (selection.isCollapsed) {
          if (s.start <= selection.start && s.end >= selection.start) {
             styles.add(s.type);
          }
       } else {
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
    
    FormattingSpan? enclosing;
    for (var s in _spans) {
       if (s.type == type) {
          if (s.start <= start && s.end >= end) {
             enclosing = s;
             break;
          }
       }
    }
    
    if (enclosing != null) {
       _spans.remove(enclosing);
       if (enclosing.start < start) {
         _spans.add(enclosing.copyWith(end: start));
       }
       if (enclosing.end > end) {
         _spans.add(enclosing.copyWith(start: end));
       }
    } else {
       _spans.add(FormattingSpan(start, end, type));
       SpanUtils.mergeSpans(_spans, type);
    }
    notifyListeners();
  }
  
  void clearFormatting() {
    final selection = this.selection;
    if (!selection.isValid) return;
    
    for (int i = _spans.length - 1; i >= 0; i--) {
       final s = _spans[i];
       if (s.start < selection.end && s.end > selection.start) {
          _spans.removeAt(i);
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
    final data = {
      "text": text,
      "spans": _spans.map((s) => s.toJson()).toList(),
    };
    return jsonEncode(data);
  }

  void load(String data) {
    try {
      if (!data.trim().startsWith('{')) {
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
      text = data;
      _spans.clear();
    }
  }
}
