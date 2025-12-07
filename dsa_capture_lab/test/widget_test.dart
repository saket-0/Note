// Basic Flutter smoke test (updated for DsaCaptureApp)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_capture_lab/main.dart';

void main() {
  testWidgets('App launches with loading screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: DsaCaptureApp()));

    // Verify that a loading indicator shows initially
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
