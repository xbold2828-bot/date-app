// Smoke test. The real MyApp boots Supabase in main(), so it isn't pumped here;
// the data-layer behaviour is covered by models_test.dart and network_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a trivial widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Radius'))),
    );
    expect(find.text('Radius'), findsOneWidget);
  });
}
