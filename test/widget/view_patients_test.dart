import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dermascan/admin/view_patients.dart';

void main() {
  testWidgets('ViewPatientsPage should show Search Bar', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ViewPatientsPage(),
    ));

    // Verify header title
    expect(find.text('Patient Records'), findsOneWidget);
    
    // Verify search field exists
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search patients...'), findsOneWidget);
  });
}
