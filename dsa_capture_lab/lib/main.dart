import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/dashboard/dashboard_screen.dart';
import 'shared/data/data_repository.dart';
import 'shared/services/asset_pipeline/asset_pipeline_service.dart';
import 'shared/services/asset_pipeline/memory_governor.dart';

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
    
    // === V7: RAM "PERFORMANCE AGGRESSIVE" - 8GB Target Devices ===
    // 1.5GB is the safe upper limit for 8GB devices (leaves ~6.5GB for OS/apps)
    // 3000 images covers deep navigation without eviction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PaintingBinding.instance.imageCache.maximumSizeBytes = 1536 * 1024 * 1024; // 1.5GB
      PaintingBinding.instance.imageCache.maximumSize = 3000; // 3000 images
    });
    
    // Initialize DataRepository (loads cache from DB)
    final repo = ref.read(dataRepositoryProvider);
    _initFuture = repo.initialize().then((_) {
      // Initialize the new asset pipeline and memory governor
      ref.read(assetPipelineServiceProvider).initialize();
      ref.read(memoryGovernorProvider); // Just reading initializes it
    });
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
                                final repo = ref.read(dataRepositoryProvider);
                                _initFuture = repo.initialize();
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