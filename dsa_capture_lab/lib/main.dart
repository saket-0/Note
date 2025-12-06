import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// IMPORTS: Feature-First structure
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/providers/dashboard_state.dart'; // Import providers

void main() {
  runApp(const ProviderScope(child: DsaCaptureApp()));
}

class DsaCaptureApp extends ConsumerStatefulWidget {
  const DsaCaptureApp({super.key});

  @override
  ConsumerState<DsaCaptureApp> createState() => _DsaCaptureAppState();
}

class _DsaCaptureAppState extends ConsumerState<DsaCaptureApp> {
  
  @override
  void initState() {
    super.initState();
    // OPTIMIZATION: Seamless Background Loading
    // Start fetching root folder data immediately on app launch.
    // By the time the UI builds, data is likely ready or cached.
    WidgetsBinding.instance.addPostFrameCallback((_) {
       ref.read(contentProvider(null).notifier).load(silent: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSA Capture Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D9488), // Teal 600
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
          background: const Color(0xFF0F172A),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent, // Allow gradient to show
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}