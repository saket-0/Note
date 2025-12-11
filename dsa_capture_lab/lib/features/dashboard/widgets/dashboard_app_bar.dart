import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/data/notes_repository.dart';
import '../../../shared/database/drift/app_database.dart';
import '../controllers/dashboard_controller.dart';
import '../providers/dashboard_state.dart';

class DashboardAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool isRoot;
  final DashboardController controller;
  final int? currentFolderId;

  const DashboardAppBar({
    super.key,
    required this.isRoot,
    required this.controller,
    required this.currentFolderId,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF525355),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            // Hamburger menu (only at root)
            if (isRoot)
              Builder(
                builder: (ctx) => Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Scaffold.of(ctx).openDrawer(),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.menu, color: Colors.white70, size: 24),
                    ),
                  ),
                ),
              ),
            // Search placeholder
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showSearchDialog(context, ref),
                child: Padding(
                  padding: EdgeInsets.only(left: isRoot ? 0 : 16),
                  child: Text(
                    'Search your notes',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
            // Grid/List view toggle
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  final current = ref.read(viewModeProvider);
                  ref.read(viewModeProvider.notifier).state =
                      current == ViewMode.grid ? ViewMode.list : ViewMode.grid;
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    ref.watch(viewModeProvider) == ViewMode.grid
                        ? Icons.view_agenda_outlined
                        : Icons.grid_view,
                    color: Colors.white70,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: isRoot
          ? const SizedBox.shrink()
          : DragTarget<String>(
              onAccept: (key) => controller.moveItemToParent(key),
              builder: (context, candidates, rejects) {
                final isHovering = candidates.isNotEmpty;
                return IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: isHovering ? Colors.tealAccent : Colors.white,
                    size: isHovering ? 28 : 24,
                  ),
                  onPressed: () => controller.navigateUp(currentFolderId!),
                );
              },
            ),
      leadingWidth: isRoot ? 0 : 56,
    );
  }

  void _showSearchDialog(BuildContext context, WidgetRef ref) {
    final repo = ref.read(notesRepositoryProvider);
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF202124),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => FutureBuilder<List<Note>>(
        future: repo.getNotesForFolder(null), // Get all notes from root
        builder: (context, snapshot) {
          final allNotes = snapshot.data ?? [];
          
          return StatefulBuilder(
            builder: (context, setState) {
              final query = searchController.text.toLowerCase();
              final filtered = query.isEmpty
                  ? <Note>[]
                  : allNotes
                      .where((n) =>
                          n.title.toLowerCase().contains(query) ||
                          n.content.toLowerCase().contains(query))
                      .toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (_, scrollController) => Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search notes...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 12),
                // Results
                Expanded(
                  child: filtered.isEmpty && query.isNotEmpty
                      ? Center(
                          child: Text(
                            'No results',
                            style: TextStyle(color: Colors.white.withOpacity(0.5)),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: query.isEmpty
                              ? (allNotes.length > 5 ? 5 : allNotes.length)
                              : filtered.length,
                          itemBuilder: (_, i) {
                            List<Note> displayList;
                            if (query.isEmpty) {
                              displayList = List.from(allNotes);
                              displayList = displayList.take(5).toList();
                            } else {
                              displayList = filtered;
                            }

                            if (displayList.isEmpty) return const SizedBox.shrink();

                            final note = displayList[i];
                            return ListTile(
                              leading: Icon(
                                note.isChecklist ? Icons.checklist : Icons.note,
                                color: Colors.tealAccent,
                              ),
                              title: Text(
                                note.title.isNotEmpty ? note.title : 'Untitled',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                note.content.isEmpty
                                    ? 'No content'
                                    : note.content.substring(0, note.content.length.clamp(0, 50)),
                                style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                DashboardController(context, ref).openFile(note);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
            }, // StatefulBuilder builder
          );  // StatefulBuilder
        }, // FutureBuilder builder
      ), // FutureBuilder
    );  // showModalBottomSheet
  }
}

