import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/models/discovery_user_model.dart';
import 'package:dating_app/data/models/map_user_model.dart';
import 'package:dating_app/presentation/explore/widgets/explore_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The composer is the bottom of the Explore column, so whatever height it
/// takes comes straight out of the map.
MapUser _person(String name) => MapUser(
      card: DiscoveryCard(id: name.toLowerCase(), displayName: name),
      latitude: 13.6,
      longitude: 79.4,
    );

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Column(children: [const Spacer(), child])),
      ),
    );

void main() {
  // It used to render a disabled field reading "Pick someone to message" — a
  // permanent bar across the bottom of the map whose only content was an
  // instruction not to use it.
  testWidgets('collapses to nothing when nobody is selected', (tester) async {
    await tester.pumpWidget(_host(const ExploreComposer(recipient: null)));

    expect(tester.getSize(find.byType(ExploreComposer)).height, 0);
    expect(find.text('Pick someone to message'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('appears, addressed to them, once somebody is picked',
      (tester) async {
    await tester.pumpWidget(
      _host(ExploreComposer(recipient: _person('Aman'))),
    );

    expect(tester.getSize(find.byType(ExploreComposer)).height, greaterThan(0));
    expect(find.text('Message Aman…'), findsOneWidget);
  });

  // Their face is the only thing on this bar identifying who the message is
  // going to, so it is the way to check who that is.
  testWidgets('the avatar is a button onto their profile', (tester) async {
    await tester.pumpWidget(
      _host(ExploreComposer(recipient: _person('Aman'))),
    );

    expect(find.bySemanticsLabel("Open Aman's profile"), findsOneWidget);
  });
}
