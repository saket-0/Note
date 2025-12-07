
import 'dart:math' as math;
import 'package:flutter/material.dart';

class JoystickLayout {
  final List<Offset> itemOffsets; // Relative to Ball Center
  final Offset centerOffset;      // Virtual Center relative to Ball Center

  JoystickLayout(this.itemOffsets, this.centerOffset);
}

class JoystickGeometry {
  /// Calculates positions using "Smart-Shift" logic.
  /// 
  /// instead of deforming the menu, we shift the center of the menu away from edges
  /// so that the full circle fits on screen.
  static JoystickLayout calculateLayout({
    required Offset ballPosition,
    required Size screenSize,
    required double radius,
    required int itemCount,
    double? horizontalMargin,
    double? verticalMargin,
  }) {
    // 1. Define margins (Default: Radius + 16, or explicit)
    final double hMargin = horizontalMargin ?? (radius + 16.0);
    final double vMargin = verticalMargin ?? (radius + 16.0);
    
    // 2. Ball Center (Global)
    final double bx = ballPosition.dx + 8;
    final double by = ballPosition.dy + 8;
    
    // 3. Calculate "Safe Center" (Clamped to screen bounds)
    double safeX = bx;
    double safeY = by;
    
    if (screenSize.width > 2 * hMargin) {
      safeX = bx.clamp(hMargin, screenSize.width - hMargin);
    } else {
      safeX = screenSize.width / 2;
    }
    
    if (screenSize.height > 2 * vMargin) {
      safeY = by.clamp(vMargin, screenSize.height - vMargin);
    } else {
      safeY = screenSize.height / 2;
    }
    
    // 4. Calculate Shift (Virtual Center relative to Ball)
    final double shiftX = safeX - bx;
    final double shiftY = safeY - by;
    final Offset centerOffset = Offset(shiftX, shiftY);
    
    // 5. Generate Item Positions (Circle around Safe Center)
    final List<Offset> itemOffsets = [];
    final double startAngle = -math.pi / 2; // Start from top
    final double step = (2 * math.pi) / itemCount;
    
    for (int i = 0; i < itemCount; i++) {
       final double theta = startAngle + (i * step);
       // Polar coord relative to Safe Center
       final double px = radius * math.cos(theta);
       final double py = radius * math.sin(theta);
       
       // Result relative to Ball Center = Shift + Polar
       itemOffsets.add(Offset(shiftX + px, shiftY + py));
    }
    
    return JoystickLayout(itemOffsets, centerOffset);
  }
}
