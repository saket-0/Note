import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_state.dart';

class DashboardDrawer extends ConsumerWidget {
  final DashboardFilter currentFilter;
  
  const DashboardDrawer({
    super.key,
    required this.currentFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      width: 280,
      child: Container(
        color: const Color(0xFF202124),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'DSA Notes',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 8),
              _buildDrawerItem(
                icon: Icons.lightbulb_outline,
                label: 'Notes',
                selected: currentFilter == DashboardFilter.active,
                onTap: () {
                  ref.read(activeFilterProvider.notifier).state = DashboardFilter.active;
                  ref.read(currentFolderProvider.notifier).state = null;
                  Navigator.pop(context);
                },
              ),
              _buildDrawerItem(
                icon: Icons.archive_outlined,
                label: 'Archive',
                selected: currentFilter == DashboardFilter.archived,
                onTap: () {
                  ref.read(activeFilterProvider.notifier).state = DashboardFilter.archived;
                  Navigator.pop(context);
                },
              ),
              _buildDrawerItem(
                icon: Icons.delete_outline,
                label: 'Trash',
                selected: currentFilter == DashboardFilter.trash,
                onTap: () {
                  ref.read(activeFilterProvider.notifier).state = DashboardFilter.trash;
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.teal.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              Icon(icon, color: selected ? Colors.tealAccent : Colors.white70, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.tealAccent : Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
