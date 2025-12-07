
import '../models/checklist_item.dart';

class ChecklistUtils {
  static List<ChecklistItem> parse(String content) {
    // Basic checklists parse from plain text for now.
    return content.split('\n').where((line) => line.isNotEmpty).map((line) {
      bool checked = line.startsWith('[x] ');
      String text = line.replaceFirst(RegExp(r'^\[[ x]\] '), '');
      return ChecklistItem(isChecked: checked, text: text);
    }).toList();
  }

  static String toContent(List<ChecklistItem> items) {
    return items.map((item) {
      return "${item.isChecked ? '[x]' : '[ ]'} ${item.text}";
    }).join('\n');
  }
}
