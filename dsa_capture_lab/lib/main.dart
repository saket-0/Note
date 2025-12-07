import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// IMPORTS: Feature-First structure
import 'features/dashboard/dashboard_screen.dart';
import 'core/cache/cache_service.dart';
import 'core/database/app_database.dart';

void main() {
  runApp(const ProviderScope(child: DsaCaptureApp()));
}

class DsaCaptureApp extends ConsumerStatefulWidget {
  const DsaCaptureApp({super.key});

  @override
  ConsumerState<DsaCaptureApp> createState() => _DsaCaptureAppState();
}

class _DsaCaptureAppState extends ConsumerState<DsaCaptureApp> {
  late Future<void> _cacheLoadFuture;

  @override
  void initState() {
    super.initState();
    // MEMORY-FIRST ARCHITECTURE: Load ALL data into cache at startup
    final cache = ref.read(cacheServiceProvider);
    final db = ref.read(dbProvider);
    _cacheLoadFuture = cache.load(db);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSA Capture Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8AB4F8), // Google Blue
          brightness: Brightness.dark,
          surface: const Color(0xFF202124), // Google Dark Background
          background: const Color(0xFF202124),
          primary: const Color(0xFF8AB4F8),
          secondary: const Color(0xFFE8EAED), // White/Grey Text/Icon
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF202124), // Solid Google Dark
        cardColor: const Color(0xFF525355), // Lighter grey for elements
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF202124), // Match background
          scrolledUnderElevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF303134), // Slightly lighter than background
          foregroundColor: Color(0xFF8AB4F8), // Blue Accent
          elevation: 4,
        ),
      ),
      home: FutureBuilder<void>(
        future: _cacheLoadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return const DashboardScreen();
          }
          // Minimal splash while cache loads (usually < 100ms)
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}