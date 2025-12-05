import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// IMPORTS: Feature-First structure
import 'features/dashboard/dashboard_screen.dart';

void main() {
  // 1. ProviderScope is required for Riverpod to manage state (Database, etc.)
  runApp(const ProviderScope(child: DsaCaptureApp()));
}

class DsaCaptureApp extends StatelessWidget {
  const DsaCaptureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSA Capture Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // We are using a custom Gradient Background, so the theme background is less relevant,
        // but we set it to dark to match the vibe.
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F2027), // Matches gradient start
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3), 
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        
        // Consistent App Bar Theme
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