import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/presentation/home/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Radar header packs four things onto one line: the mark, the
/// greeting, the Premium pill and Filters. Three of those are fixed-width, so
/// the greeting is the only thing that can give — which makes this the most
/// likely place in the app to overflow.
Widget _host(Widget child, {double textScale = 1.0}) => MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('fits a narrow phone with a long name', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      const RadarHeader(
        name: 'Bartholomew Fitzgerald',
        city: 'Visakhapatnam',
      ),
    ));

    expect(tester.takeException(), isNull);
  });

  testWidgets('fits at 1.3x text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      const RadarHeader(name: 'M Tarun', city: 'Hyderabad'),
      textScale: 1.3,
    ));

    expect(tester.takeException(), isNull);
  });

  testWidgets('Filters is reachable, and nothing sells Premium here',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      const RadarHeader(name: 'M Tarun', city: 'Hyderabad'),
    ));

    // Filters moved here precisely so it is not buried behind eight intent
    // chips in a horizontal scroller.
    expect(find.bySemanticsLabel('Filters'), findsOneWidget);
    // The Premium pill used to sit beside it, squeezing the greeting into an
    // ellipsis to advertise on the screen people open the app to use.
    expect(find.bySemanticsLabel('Radius Premium'), findsNothing);
  });

  testWidgets('survives having no name or city yet', (tester) async {
    await tester.pumpWidget(_host(const RadarHeader()));
    expect(find.text('Your radar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
