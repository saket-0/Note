
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dsa_capture_lab/features/dashboard/widgets/joystick_geometry.dart';

void main() {
  group('JoystickGeometry Smart-Shift', () {
    const double radius = 80.0;
    // Default Margin in implementation is radius + 16 = 96.0
    // But now we can pass explicit.
    const double hMargin = 96.0; 
    const Size screenSize = Size(1000, 2000);

    test('Center: No shift when far from edges', () {
      final ballPos = Offset(500, 1000); 
      
      final layout = JoystickGeometry.calculateLayout(
        ballPosition: ballPos,
        screenSize: screenSize,
        radius: radius,
        horizontalMargin: hMargin,
        itemCount: 4,
      );
      
      expect(layout.centerOffset.dx, 0.0);
      expect(layout.centerOffset.dy, 0.0);
    });

    test('Left Edge: Shifts Right with Custom Margin', () {
      final ballPos = Offset(0, 1000); // Left edge
      // Ball Center = (8, 1008)
      // Custom Margin = 200
      // SafeX should be 200.
      // ShiftX = 200 - 8 = 192.
      
      final layout = JoystickGeometry.calculateLayout(
        ballPosition: ballPos,
        screenSize: screenSize,
        radius: radius,
        horizontalMargin: 200.0,
        itemCount: 4,
      );
      
      expect(layout.centerOffset.dx, closeTo(192.0, 0.1));
    });

    test('Right Edge: Shifts Left', () {
      final ballPos = Offset(990, 1000); // Right edge (Width 1000)
      // Ball Center = (998, 1008)
      // SafeX should be Width - Margin = 1000 - 96 = 904.
      // ShiftX = 904 - 998 = -94.
      
      final layout = JoystickGeometry.calculateLayout(
        ballPosition: ballPos,
        screenSize: screenSize,
        radius: radius,
        itemCount: 4,
      );
      
      expect(layout.centerOffset.dx, closeTo(-94.0, 0.1));
      expect(layout.centerOffset.dy, 0.0);
    });
    
    test('Top Edge: Shifts Down', () {
      final ballPos = Offset(500, 0); 
      // Ball Center = (508, 8)
      // SafeY = 96
      // ShiftY = 96 - 8 = 88
      
      final layout = JoystickGeometry.calculateLayout(
        ballPosition: ballPos,
        screenSize: screenSize,
        radius: radius,
        itemCount: 4,
      );
      
      expect(layout.centerOffset.dy, closeTo(88.0, 0.1));
    });
    
    test('Corner: Shifts Diagonal', () {
      final ballPos = Offset(0, 0);
      final layout = JoystickGeometry.calculateLayout(
        ballPosition: ballPos,
        screenSize: screenSize,
        radius: radius,
        itemCount: 4,
      );
      
      expect(layout.centerOffset.dx, closeTo(88.0, 0.1));
      expect(layout.centerOffset.dy, closeTo(88.0, 0.1));
    });
  });
}
