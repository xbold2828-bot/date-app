import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/core/utils/app_haptics.dart';
import 'package:dating_app/presentation/common/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

Widget target({
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  Haptic? haptic,
  PressFeedback feedback = PressFeedback.scale,
}) =>
    Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      haptic: haptic,
      feedback: feedback,
      child: const SizedBox(width: 120, height: 48, child: Text('Go')),
    );

/// The scale the press is drawing right now; 1 at rest.
double scaleOf(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find.descendant(
        of: find.byType(Pressable),
        matching: find.byType(ScaleTransition),
      ),
    )
    .scale
    .value;

void main() {
  late List<String> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('shows the press on touch-down, and acts only on the lift',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(target(onTap: () => taps++)));

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump();

    expect(scaleOf(tester), closeTo(0.97, 1e-9),
        reason: 'the press is on screen the frame the finger lands');
    expect(taps, 0, reason: 'nothing runs until the finger lifts');

    await gesture.up();
    await tester.pump();
    expect(taps, 1);

    await tester.pumpAndSettle();
    expect(scaleOf(tester), closeTo(1, 1e-3));
  });

  testWidgets('sliding off cancels the tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(target(onTap: () => taps++)));

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 60));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(taps, 0, reason: 'sliding away is how people back out of a tap');
    expect(scaleOf(tester), closeTo(1, 1e-3));
  });

  testWidgets('inside a list, holds the press briefly so scrolls do not flash',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
      SizedBox(
        height: 300,
        child: ListView(children: [target(onTap: () => taps++)]),
      ),
    ));

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump(const Duration(milliseconds: 40));
    expect(scaleOf(tester), 1, reason: 'the finger may be starting a scroll');

    await tester.pump(const Duration(milliseconds: 80));
    expect(scaleOf(tester), closeTo(0.97, 1e-9));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('a quick tap in a list still flashes its press', (tester) async {
    await tester.pumpWidget(host(
      SizedBox(
        height: 300,
        child: ListView(children: [target(onTap: () {})]),
      ),
    ));

    await tester.tap(find.byType(Pressable));
    await tester.pump();
    expect(scaleOf(tester), lessThan(0.99),
        reason: 'a tap shorter than the hold must not lose its feedback');
  });

  testWidgets('without callbacks it is inert', (tester) async {
    await tester.pumpWidget(host(target()));

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump();
    expect(scaleOf(tester), 1);
    await gesture.up();
  });

  testWidgets('plays its haptic as the tap commits, not as the finger lands',
      (tester) async {
    await tester.pumpWidget(
      host(target(onTap: () {}, haptic: Haptic.selection)),
    );

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump();
    expect(haptics, isEmpty);

    await gesture.up();
    await tester.pump();
    expect(haptics, ['HapticFeedbackType.selectionClick']);
  });

  testWidgets('an ordinary tap is silent', (tester) async {
    await tester.pumpWidget(host(target(onTap: () {})));
    await tester.tap(find.byType(Pressable));
    await tester.pump();
    expect(haptics, isEmpty);
  });

  testWidgets('a long press fires with a medium impact', (tester) async {
    var longPresses = 0;
    await tester.pumpWidget(host(target(onLongPress: () => longPresses++)));

    await tester.longPress(find.byType(Pressable));
    await tester.pumpAndSettle();

    expect(longPresses, 1);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    expect(scaleOf(tester), closeTo(1, 1e-3),
        reason: 'the press never outlives the finger');
  });

  testWidgets('a long-press-only target does not flash for a tap',
      (tester) async {
    await tester.pumpWidget(host(target(onLongPress: () {})));

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump();
    expect(scaleOf(tester), 1);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a dim press fades rather than shrinks', (tester) async {
    await tester.pumpWidget(
      host(target(onTap: () {}, feedback: PressFeedback.dim)),
    );

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump();
    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(Pressable),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, closeTo(0.4, 1e-9));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a translucent target lets touches through to what lies beneath',
      (tester) async {
    // The case that matters: tap zones laid over a PageView or a map must not
    // swallow the swipe that starts under them.
    var downsBeneath = 0;
    const area = Key('area');
    await tester.pumpWidget(host(
      SizedBox(
        key: area,
        width: 200,
        height: 200,
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => downsBeneath++,
              ),
            ),
            Positioned.fill(
              child: Pressable(
                onTap: () {},
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    ));

    await tester.tapAt(tester.getCenter(find.byKey(area)));
    await tester.pumpAndSettle();
    expect(downsBeneath, 1);
  });

  testWidgets('only the innermost target under the finger shows its press',
      (tester) async {
    // A row with a button in it: holding the button must not light the row.
    var rowTaps = 0;
    var buttonTaps = 0;
    await tester.pumpWidget(host(
      SizedBox(
        height: 300,
        child: ListView(
          children: [
            Pressable(
              key: const Key('row'),
              onTap: () => rowTaps++,
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Pressable(
                    key: const Key('button'),
                    onTap: () => buttonTaps++,
                    feedback: PressFeedback.dim,
                    child: const SizedBox(width: 44, height: 44),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ));

    double rowScale() => tester
        .widget<ScaleTransition>(find.descendant(
          of: find.byKey(const Key('row')),
          matching: find.byType(ScaleTransition),
        ).first)
        .scale
        .value;

    final onButton =
        await tester.startGesture(tester.getCenter(find.byKey(const Key('button'))));
    await tester.pump(const Duration(milliseconds: 150));
    expect(rowScale(), 1, reason: 'the row the button sits in stays still');
    await onButton.up();
    await tester.pumpAndSettle();
    expect((buttonTaps, rowTaps), (1, 0));

    // The row itself, touched beside the button, still presses.
    final onRow = await tester.startGesture(
      tester.getTopLeft(find.byKey(const Key('row'))) + const Offset(10, 10),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(rowScale(), closeTo(0.97, 1e-9));
    await onRow.up();
    await tester.pumpAndSettle();
    expect(rowTaps, 1);
  });

  testWidgets('keyboard and switch users can reach and activate it',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(target(onTap: () => taps++)));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('screen readers get the tap action', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(host(target(onTap: () => taps++)));

    // The route gives each actionable child its own node, so look it up from
    // the label rather than from the Pressable above it.
    expect(
      tester.getSemantics(find.text('Go')),
      isSemantics(label: 'Go', hasTapAction: true),
    );
    handle.dispose();
  });
}
