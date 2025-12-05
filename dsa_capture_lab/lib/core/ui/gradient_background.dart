import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027), // Deep Dark Blue
            Color(0xFF203A43), // Teal-ish Dark
            Color(0xFF2C5364), // Lighter Teal/Blue
          ],
        ),
      ),
      child: child,
    );
  }
}
