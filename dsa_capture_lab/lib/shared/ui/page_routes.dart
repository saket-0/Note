import 'package:flutter/material.dart';

/// Custom page route with smooth slide-up animation for screens
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  
  SlideUpPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.05);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            
            var fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeIn,
            );
            
            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: offsetAnimation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 150),
        );
}

/// Custom page route with scale animation (for dialogs/modals)
class ScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  
  ScalePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const curve = Curves.easeOutBack;
            
            var scaleAnimation = Tween(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: curve),
            );
            
            var fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeIn,
            );
            
            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 150),
        );
}
