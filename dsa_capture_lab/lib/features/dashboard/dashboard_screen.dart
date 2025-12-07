import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ui/gradient_background.dart';
import '../../core/ui/page_routes.dart';
import '../camera/camera_screen.dart';
import '../editor/editor_screen.dart';
import 'controllers/dashboard_controller.dart';
import 'providers/dashboard_state.dart';
import 'widgets/dashboard_app_bar.dart';
import 'widgets/dashboard_content.dart';
import 'widgets/dashboard_drawer.dart';
import 'widgets/radial_fab_menu.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime? _lastBackPress;
  
  @override
  Widget build(BuildContext context) {
    final currentFolderId = ref.watch(currentFolderProvider);
    final currentFilter = ref.watch(activeFilterProvider);
    final viewMode = ref.watch(viewModeProvider);
    
    // MEMORY-FIRST: Synchronous reads - NO LOADING STATE!
    final List<dynamic> items;
    if (currentFilter == DashboardFilter.active) {
       items = ref.watch(activeContentProvider(currentFolderId));
    } else if (currentFilter == DashboardFilter.archived) {
       items = ref.watch(archivedContentProvider);
    } else {
       items = ref.watch(trashContentProvider);
    }
    
    // Instantiate Controller
    final controller = DashboardController(context, ref);
    
    // Determine if we are at "Root" context
    final bool isRoot = currentFolderId == null || currentFilter != DashboardFilter.active;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        // If in a folder, navigate up
        if (currentFolderId != null && currentFilter == DashboardFilter.active) {
          controller.navigateUp(currentFolderId);
          return;
        }
        
        // If in Archive/Trash, go back to Notes
        if (currentFilter != DashboardFilter.active) {
          ref.read(activeFilterProvider.notifier).state = DashboardFilter.active;
          return;
        }
        
        // At root - double tap to exit
        final now = DateTime.now();
        if (_lastBackPress != null && now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
        } else {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        drawer: DashboardDrawer(currentFilter: currentFilter),
        appBar: DashboardAppBar(
          isRoot: isRoot,
          controller: controller,
          currentFolderId: currentFolderId,
        ),
        body: Stack(
          children: [
            GradientBackground(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: DashboardContent(
                    items: items,
                    currentFilter: currentFilter,
                    controller: controller,
                    viewMode: viewMode,
                  ),
                ),
              ),
            ),
            
            // manually positioned FABs
            if (currentFilter == DashboardFilter.active)
              Positioned(
                right: 16,
                // Ensure we respect bottom padding (safe area) + visual margin
                bottom: MediaQuery.of(context).padding.bottom + 16, 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: 'camera_fab',
                      onPressed: () async {
                         await Navigator.push(
                           context, 
                           SlideUpPageRoute(page: CameraScreen(folderId: currentFolderId)),
                         );
                         // Optimistic updates already handled - no cache reload needed!
                         // The cache was updated in real-time by camera_view_model
                      },
                      backgroundColor: const Color(0xFF202124),
                      child: const Icon(Icons.camera_alt, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    RadialFabMenu(
                      onCreateNote: () async {
                        await Navigator.push(
                          context, 
                          SlideUpPageRoute(page: EditorScreen(folderId: currentFolderId)),
                        );
                        // Optimistic updates already handled - no cache reload needed!
                        // The cache was updated in real-time by editor_controller
                      },
                      onImportFile: () => controller.importFile(),
                      onCreateFolder: () => controller.showCreateFolderDialog(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
