import 'package:dsa_capture_lab/camera_screen.dart'; // Add this at the top
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  // 1. Wrap the app in ProviderScope (Required for Riverpod)
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
        // 2. Explicit syntax fixes your "dot-shorthand" error
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3), // Tech Blue
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      // 3. We point to our Dashboard (which we define below)
      home: const DashboardScreen(),
    );
  }
}

// --- DASHBOARD SKELETON (We will expand this next) ---
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DSA Lab Capture'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No captures yet.\nTap the + button to start.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
  onPressed: () {
    // Navigate to the Camera Screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CameraScreen(),
      ),
    );
  },
  label: const Text("New Capture"),
  icon: const Icon(Icons.camera_alt),
),
    );
  }
}