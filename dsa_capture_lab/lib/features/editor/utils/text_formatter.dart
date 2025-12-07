import 'package:flutter/material.dart';

class TextFormatter {
  static TextEditingValue format(TextEditingValue value, String prefix, String suffix) {
    final text = value.text;
    final selection = value.selection;
    
    if (!selection.isValid) return value;
    
    // 1. Check if selection is EXACTLY wrapped (Outer check)
    // E.g. [**text**]
    int checkStart = selection.start - prefix.length;
    int checkEnd = selection.end + suffix.length;
    
    if (checkStart >= 0 && checkEnd <= text.length) {
      final potentialPrefix = text.substring(checkStart, selection.start);
      final potentialSuffix = text.substring(selection.end, checkEnd);
      if (potentialPrefix == prefix && potentialSuffix == suffix) {
         // Unwrap
         final newText = text.replaceRange(selection.end, checkEnd, "").replaceRange(checkStart, selection.start, "");
         return value.copyWith(
           text: newText,
           selection: TextSelection(baseOffset: checkStart, extentOffset: selection.end - prefix.length),
         );
      }
    }

    // 2. Check if cursor/selection is INSIDE a formatted block (Inner check)
    // Simpler approach: Find matches of pattern, see if selection overlaps?
    // Regex e.g. \*\*.*?\*\*
    // Note: Regex is tricky with nesting but okay for simple key-pairs.
    
    String pattern;
    if (prefix == "**") pattern = r'\*\*([\s\S]+?)\*\*';
    else if (prefix == "_") pattern = r'_([\s\S]+?)_';
    else if (prefix == "<u>") pattern = r'<u>([\s\S]+?)</u>';
    else pattern = "";
    
    if (pattern.isNotEmpty) {
      final matches = RegExp(pattern).allMatches(text);
      for (final m in matches) {
         // If selection is fully inside this match (or matches exactly the content)
         // m.start is index of prefix start. m.end is index after suffix.
         // Inner content is m.start+len to m.end-len.
         
         if (selection.start >= m.start && selection.end <= m.end) {
            // We are inside. Remove the tags of THIS match.
            // Note: m.group(0) is whole match.
            final prefixStart = m.start;
            final prefixEnd = m.start + prefix.length;
            final suffixStart = m.end - suffix.length; // m.end is exclusive index
            final suffixEnd = m.end;
             
            final newText = text.replaceRange(suffixStart, suffixEnd, "").replaceRange(prefixStart, prefixEnd, "");
            
            // Adjust selection to keep relative position
            // If selection was after prefix, it shifts left by len.
            int newBase = selection.baseOffset - prefix.length;
            if (newBase < prefixStart) newBase = prefixStart; // clamped
            
            int newExtent = selection.extentOffset - prefix.length;
            if (newExtent < prefixStart) newExtent = prefixStart;

            return value.copyWith(
              text: newText,
              selection: TextSelection(baseOffset: newBase, extentOffset: newExtent),
            );
         }
      }
    }
    
    // 3. Else Apply (Wrap)
    if (selection.isCollapsed) {
       final newText = text.replaceRange(selection.start, selection.end, "$prefix$suffix");
       return value.copyWith(
         text: newText,
         selection: TextSelection.collapsed(offset: selection.start + prefix.length),
       );
    }
    
    final selectedText = text.substring(selection.start, selection.end);
    final newText = text.replaceRange(selection.start, selection.end, "$prefix$selectedText$suffix");
    return value.copyWith(
      text: newText,
      selection: TextSelection(baseOffset: selection.start, extentOffset: selection.start + prefix.length + selectedText.length + suffix.length), 
    );
  }

  static TextEditingValue formatHeader(TextEditingValue value, int level) {
    final text = value.text;
    final selection = value.selection;
    if (!selection.isValid) return value;

    // Find start of the current line
    final lineStart = text.lastIndexOf('\n', selection.baseOffset - 1);
    final start = lineStart == -1 ? 0 : lineStart + 1;
    
    // Check if line starts with header
    final headerPrefix = "#" * level + " ";
    // Use regex to find ANY header to toggle? Or specific level?
    // Let's simplified: If starts with requested level, remove it. If starts with other level, replace it. If no header, add it.
    
    // Get line content to check
    final lineEnd = text.indexOf('\n', start);
    final validLineEnd = lineEnd == -1 ? text.length : lineEnd;
    final currentLine = text.substring(start, validLineEnd);
    
    if (currentLine.startsWith(headerPrefix)) {
      // Remove
       final newText = text.replaceRange(start, start + headerPrefix.length, "");
       return value.copyWith(
         text: newText,
         selection: TextSelection.collapsed(offset: selection.baseOffset - headerPrefix.length), // Adjust cursor
       );
    } else {
      // Check if it has OTHER header
      final match = RegExp(r'^(#+ )').firstMatch(currentLine);
      if (match != null) {
        // Replace existing header
        final oldHeader = match.group(0)!;
        final newText = text.replaceRange(start, start + oldHeader.length, headerPrefix);
         return value.copyWith(
           text: newText,
           selection: TextSelection.collapsed(offset: selection.baseOffset + (headerPrefix.length - oldHeader.length)),
         );
      } else {
        // Add header
        final newText = text.replaceRange(start, start, headerPrefix);
        return value.copyWith(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.baseOffset + headerPrefix.length),
        );
      }
    }
  }

  static TextEditingValue clearFormatting(TextEditingValue value) {
    // Simple implementation: Remove common markdown symbols from selection or line
    final text = value.text;
    final selection = value.selection;
    if (!selection.isValid) return value;
    
    final start = selection.start;
    final end = selection.end;
    
    if (selection.isCollapsed) {
       // Clear line formatting (Headers)?
       // TODO: Implement more robust clear
       return value;
    }
    
    String selectedText = text.substring(start, end);
    // Remove bold/italic/...
    selectedText = selectedText.replaceAll(RegExp(r'(\*\*|__|#|_)'), '');
    selectedText = selectedText.replaceAll('<u>', '').replaceAll('</u>', '');
    
    final newText = text.replaceRange(start, end, selectedText);
    return value.copyWith(
      text: newText,
      selection: TextSelection(baseOffset: start, extentOffset: start + selectedText.length),
    );
  }
}
