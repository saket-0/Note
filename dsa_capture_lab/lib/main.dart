import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/providers/dashboard_state.dart';
import 'shared/database/drift/app_database.dart';
import 'shared/services/asset_pipeline/asset_pipeline_service.dart';
import 'shared/services/asset_pipeline/memory_governor.dart';
import 'shared/services/hydrated_state.dart';
import 'shared/services/image_optimization_service.dart';

void main() {
  runApp(const ProviderScope(child: DsaCaptureApp()));
}

class DsaCaptureApp extends ConsumerStatefulWidget {
  const DsaCaptureApp({super.key});

  @override
  ConsumerState<DsaCaptureApp> createState() => _DsaCaptureAppState();
}

class _DsaCaptureAppState extends ConsumerState<DsaCaptureApp> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    
    // === MEMORY GOVERNANCE ===
    // Let the OS manage image cache sizing.
    // Flutter's default ImageCache is well-tuned for most devices.
    // Manual limits cause premature eviction and re-decoding jank.
    // (Removed "Titanium Cache Configuration" block)
    
    // === INITIALIZATION CHAIN ===
    // 1. Load Phoenix state (persisted session)
    // 2. Initialize Drift database (background isolate)
    // 3. Initialize image optimization service
    // 4. Restore navigation state from Phoenix
    // 5. Initialize asset pipeline and memory governor
    _initFuture = _initialize();
  }
  
  Future<void> _initialize() async {
    // 1. Load Phoenix state FIRST (fast, from SharedPreferences)
    final phoenixState = await HydratedState.load();
    
    // 2. Initialize Drift database (runs in background isolate)
    // Just reading the provider triggers lazy initialization
    final db = ref.read(driftDatabaseProvider);
    debugPrint('[App] Drift database initialized (background isolate)');
    
    // 3. Initialize image optimization service
    await ref.read(imageOptimizationServiceProvider).initialize();
    debugPrint('[App] Image optimization service initialized');
    
    // 4. Restore navigation state from Phoenix
    if (phoenixState.currentFolderId != null) {
      ref.read(currentFolderProvider.notifier).state = phoenixState.currentFolderId;
      debugPrint('[Phoenix] Restored to folder: ${phoenixState.currentFolderId}');
    }
    
    // 5. Initialize asset pipeline and memory governor
    await ref.read(assetPipelineServiceProvider).initialize();
    ref.read(memoryGovernorProvider); // Just reading initializes it
    
    debugPrint('[App] Initialization complete - Drift + Reactive Streams ready');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSA Capture Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8AB4F8),
          brightness: Brightness.dark,
          surface: const Color(0xFF202124),
          primary: const Color(0xFF8AB4F8),
          secondary: const Color(0xFFE8EAED),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF202124),
        cardColor: const Color(0xFF525355),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF202124),
          scrolledUnderElevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF303134),
          foregroundColor: Color(0xFF8AB4F8),
          elevation: 4,
        ),
      ),
      home: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        const Text("Initialization Failed", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(snapshot.error.toString(), style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () { 
                             setState(() {
                                _initFuture = _initialize();
                             });
                          },
                          child: const Text("Retry"),
                        )
                      ],
                    ),
                  ),
                ),
              );
            }
            return const DashboardScreen();
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}