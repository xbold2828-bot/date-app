import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/presentation/common/widgets/widgets.dart';
import 'package:dating_app/presentation/home/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Radar header packs four things onto one line: the band radar, the
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
        band: DistanceRing.regional,
      ),
    ));

    expect(tester.takeException(), isNull);
  });

  testWidgets('fits at 1.3x text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      const RadarHeader(
        name: 'M Tarun',
        city: 'Hyderabad',
        band: DistanceRing.regional,
      ),
      textScale: 1.3,
    ));

    expect(tester.takeException(), isNull);
  });

  testWidgets('Filters and Premium are both reachable without scrolling',
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
    expect(find.bySemanticsLabel('Radius Premium'), findsOneWidget);
  });

  testWidgets('survives having no name, city or band yet', (tester) async {
    await tester.pumpWidget(_host(const RadarHeader()));
    expect(find.text('Your radar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
