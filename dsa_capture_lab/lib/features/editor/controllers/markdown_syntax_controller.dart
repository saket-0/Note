import 'package:flutter/material.dart';

class MarkdownSyntaxController extends TextEditingController {
  MarkdownSyntaxController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Default style
    style ??= const TextStyle(color: Colors.white);
    final hiddenStyle = style.copyWith(color: Colors.transparent, fontSize: 0.1); // 0.1 to minimize space but keep valid? 0 might crash on some devices? 0 is usually fine. Let's use 0.001 or just transparent. 
    // User complaint: "Extra space". So font size MUST be small. 
    // Let's try fontSize: 0.0. 
    final syntaxStyle = style.copyWith(color: Colors.transparent, fontSize: 0.0);
    
    final text = value.text;
    final List<TextSpan> children = [];
    
    // Parser State
    bool isBold = false;
    bool isItalic = false;
    bool isUnderline = false;
    bool isHeader1 = false;
    bool isHeader2 = false;
    
    int i = 0;
    int start = 0;
    
    void flush(int end) {
      if (end > start) {
         TextStyle current = style!;
         if (isHeader1) current = current.copyWith(fontSize: 24, fontWeight: FontWeight.bold);
         else if (isHeader2) current = current.copyWith(fontSize: 20, fontWeight: FontWeight.bold);
         
         if (isBold) current = current.copyWith(fontWeight: FontWeight.bold);
         if (isItalic) current = current.copyWith(fontStyle: FontStyle.italic);
         if (isUnderline) current = current.copyWith(decoration: TextDecoration.underline);
         
         children.add(TextSpan(text: text.substring(start, end), style: current));
      }
      start = end;
    }
    
    while (i < text.length) {
      // Check for Tokens
      
      // Header 1: '# ' at start of line
      // Issue: We need to know if we are at start of line.
      bool atLineStart = (i == 0 || text[i-1] == '\n');
      
      if (atLineStart && text.startsWith('# ', i)) {
         flush(i);
         children.add(TextSpan(text: '# ', style: syntaxStyle));
         isHeader1 = true;
         i += 2;
         start = i;
         continue;
      }
      
      // Header 2: '## ' at start of line
      if (atLineStart && text.startsWith('## ', i)) {
         flush(i);
         children.add(TextSpan(text: '## ', style: syntaxStyle));
         isHeader2 = true;
         i += 3;
         start = i;
         continue;
      }
      
      // Newline: Reset Header
      if (text[i] == '\n') {
        flush(i);
        isHeader1 = false;
        isHeader2 = false;
        children.add(const TextSpan(text: '\n')); // Standard new line
        i++;
        start = i;
        continue;
      }
      
      // Bold: '**'
      if (text.startsWith('**', i)) {
        flush(i);
        children.add(TextSpan(text: '**', style: syntaxStyle));
        isBold = !isBold;
        i += 2;
        start = i;
        continue;
      }
      
      // Underline: '<u>' or '</u>'
      if (text.startsWith('<u>', i)) {
        flush(i);
        children.add(TextSpan(text: '<u>', style: syntaxStyle));
        isUnderline = true;
        i += 3;
        start = i;
        continue;
      }
      
      if (text.startsWith('</u>', i)) {
        flush(i);
        children.add(TextSpan(text: '</u>', style: syntaxStyle));
        isUnderline = false; // logic assumes proper nesting, but toggle is safer? No, close tag closes.
        i += 4;
        start = i;
        continue;
      }
      
      // Italic: '_'
      // logic: avoid matching inside words? Standard markdown is `_` anywhere.
      if (text[i] == '_') {
        flush(i);
        children.add(TextSpan(text: '_', style: syntaxStyle));
        isItalic = !isItalic;
        i += 1;
        start = i;
        continue;
      }
      
      // Standard char
      i++;
    }
    
    flush(text.length); // Flush remaining
    
    return TextSpan(style: style, children: children);
  }

}

