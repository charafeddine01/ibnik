import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:babymonitor/features/parent_unit/widgets/decibel_meter.dart';

void main() {
  testWidgets('DecibelMeter renders correctly for Quiet state', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DecibelMeter(currentDb: 30.0, alertThreshold: 65.0),
        ),
      ),
    );

    expect(find.text('30 dB'), findsOneWidget);
    expect(find.text('Quiet'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('DecibelMeter renders Cry Alert when threshold exceeded', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DecibelMeter(currentDb: 80.0, alertThreshold: 65.0),
        ),
      ),
    );

    expect(find.text('80 dB'), findsOneWidget);
    expect(find.text('Cry Alert!'), findsOneWidget);
  });
}
