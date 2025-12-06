import 'package:flutter/material.dart';
import '../controllers/camera_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CameraTopBar extends ConsumerWidget {
  final bool isBatchMode;
  final Function(bool) onModeChanged;
  final VoidCallback onBack;

  const CameraTopBar({
    super.key,
    required this.isBatchMode,
    required this.onModeChanged,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button (Glass style)
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),

          // Mode Toggle (Pill style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(30),
               border: Border.all(color: Colors.white12, width: 1),
            ),
            child: Row(
              children: [
                _buildModeTab("Quick", !isBatchMode),
                _buildModeTab("Batch", isBatchMode),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, bool isActive) {
    return GestureDetector(
      onTap: () => onModeChanged(label == "Batch"),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
