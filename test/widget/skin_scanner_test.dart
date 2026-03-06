import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dermascan/admin/skin_scanner.dart';

void main() {
  testWidgets('SkinScannerPage should show Camera and Gallery options', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: const SkinScannerPage(),
      ),
    ));

    // Verify that the title is present
    expect(find.text('Skin Scanner'), findsOneWidget);
    
    // Verify that the Camera button is present
    expect(find.text('Camera'), findsOneWidget);
    
    // Verify that the Gallery button is present
    expect(find.text('Gallery'), findsOneWidget);
    
    // Verify that the initial state shows "Select a patient"
    expect(find.text('Select a patient'), findsOneWidget);
  });
}
