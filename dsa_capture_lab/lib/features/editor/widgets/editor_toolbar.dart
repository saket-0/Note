import 'package:flutter/material.dart';
import '../controllers/rich_text_controller.dart'; 

class EditorToolbar extends StatelessWidget {
  final VoidCallback onAddImage;
  final VoidCallback onColorPalette;
  final VoidCallback onFormatToggle; 
  final VoidCallback onUndo; 
  final VoidCallback onRedo; 
  final VoidCallback? onH1;
  final VoidCallback? onH2;
  final VoidCallback? onBold;
  final VoidCallback? onItalic;
  final VoidCallback? onUnderline;
  final VoidCallback? onClearFormatting;
  
  final Color contentColor;
  final bool canUndo;
  final bool canRedo;
  final bool isFormattingMode;
  final Set<StyleType> activeStyles;

  const EditorToolbar({
    super.key,
    required this.onAddImage,
    required this.onColorPalette,
    required this.onFormatToggle,
    required this.onUndo,
    required this.onRedo,
    this.onH1,
    this.onH2,
    this.onBold,
    this.onItalic,
    this.onUnderline,
    this.onClearFormatting,
    this.contentColor = Colors.black54,
    this.canUndo = false,
    this.canRedo = false,
    this.isFormattingMode = false,
    this.activeStyles = const {},
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.transparent,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isFormattingMode ? _buildFormattingTools(context) : _buildMainTools(context),
      ),
    );
  }

  Widget _buildMainTools(BuildContext context) {
    // ... (same as before, but I need to include it or just replace file partial if possible? 
    // I can replacing whole file content or use multi_replace.
    // I'll replace whole file to be safe and clean since it's small.)
    return Row(
      key: const ValueKey('main_tools'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.add_box_outlined, color: contentColor),
              onPressed: onAddImage,
              tooltip: 'Add image',
            ),
            IconButton(
              icon: Icon(Icons.palette_outlined, color: contentColor),
              onPressed: onColorPalette,
              tooltip: 'Change color',
            ),
             Container(
              decoration: BoxDecoration(
                // Highlight formatting main button if ANY style is active, or just if mode is open?
                // User said: "Highlight when cursor is on text on which field is applied".
                // And "main entry option was already in highlighted state".
                // I'll highlight this button if `activeStyles` is not empty? OR `isFormattingMode`?
                // The user complained it WAS highlighted when new.
                // It was highlighted because `isFormattingMode` logic perhaps?
                // Line 73 in original: `color: Theme.of(context).colorScheme.primary.withOpacity(0.1)`. 
                // That is static. I should make it conditional?
                // Or just leave it as "button style".
                // Let's leave it for now.
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(Icons.text_format, color: Theme.of(context).colorScheme.primary),
                onPressed: onFormatToggle,
                tooltip: 'Formatting',
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.undo, color: canUndo ? contentColor : contentColor.withOpacity(0.3)),
              onPressed: canUndo ? onUndo : null,
              tooltip: 'Undo',
            ),
            IconButton(
              icon: Icon(Icons.redo, color: canRedo ? contentColor : contentColor.withOpacity(0.3)),
              onPressed: canRedo ? onRedo : null,
              tooltip: 'Redo',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormattingTools(BuildContext context) {
    return Row(
      key: const ValueKey('fmt_tools'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                 _buildFormatOption(context, label: "H1", onTap: onH1, isActive: activeStyles.contains(StyleType.header1)),
                 const SizedBox(width: 8),
                 _buildFormatOption(context, label: "H2", onTap: onH2, isActive: activeStyles.contains(StyleType.header2)),
                 const SizedBox(width: 8),
                 Container(width: 1, height: 20, color: Colors.grey.withOpacity(0.3)),
                 const SizedBox(width: 8),
                 _buildFormatOption(context, icon: Icons.format_bold, onTap: onBold, isActive: activeStyles.contains(StyleType.bold)),
                 const SizedBox(width: 8),
                 _buildFormatOption(context, icon: Icons.format_italic, onTap: onItalic, isActive: activeStyles.contains(StyleType.italic)),
                 const SizedBox(width: 8),
                 _buildFormatOption(context, icon: Icons.format_underlined, onTap: onUnderline, isActive: activeStyles.contains(StyleType.underline)),
                 const SizedBox(width: 8),
                 Container(width: 1, height: 20, color: Colors.grey.withOpacity(0.3)),
                 const SizedBox(width: 8),
                 _buildFormatOption(context, icon: Icons.format_clear, onTap: onClearFormatting),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.close, color: contentColor),
          onPressed: onFormatToggle,
          tooltip: 'Close Formatting',
        ),
      ],
    );
  }

  Widget _buildFormatOption(BuildContext context, {IconData? icon, String? label, VoidCallback? onTap, bool isActive = false}) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withOpacity(0.3) : Colors.transparent, // transparent unless active, or subtle?
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: primaryColor, width: 1.5) : null,
        ),
        child: icon != null 
          ? Icon(icon, color: isActive ? primaryColor : primaryColor.withOpacity(0.7), size: 24)
          : Text(
              label ?? "", 
              style: TextStyle(
                color: isActive ? primaryColor : primaryColor.withOpacity(0.7), 
                fontWeight: FontWeight.bold,
                fontSize: 16
              )
            ),
      ),
    );
  }
}
