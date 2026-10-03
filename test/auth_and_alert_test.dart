import 'dart:io';

import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/core/utils/input_formatters.dart';
import 'package:dating_app/presentation/auth/screens/login_screen.dart';
import 'package:dating_app/presentation/auth/screens/otp_screen.dart';
import 'package:dating_app/presentation/common/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

TextEditingValue _type(
  DigitGroupsFormatter f,
  TextEditingValue old,
  String text, {
  int? cursor,
}) => f.formatEditUpdate(
  old,
  TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor ?? text.length),
  ),
);

void main() {
  group('DigitGroupsFormatter', () {
    test('groups digits the way the number is said', () {
      final f = DigitGroupsFormatter([5, 5]);
      final v = _type(f, TextEditingValue.empty, '9876543210');
      expect(v.text, '98765 43210');
      expect(v.selection.baseOffset, v.text.length);
    });

    test('groups a US number 3-3-4', () {
      final f = DigitGroupsFormatter([3, 3, 4]);
      expect(
        _type(f, TextEditingValue.empty, '5551234567').text,
        '555 123 4567',
      );
    });

    test('drops anything that is not a digit, and stops at the limit', () {
      final f = DigitGroupsFormatter([5, 5]);
      expect(
        _type(f, TextEditingValue.empty, '+91 (98765) 43210 99').text,
        '91987 65432',
      );
    });

    test('backspace over the space deletes the digit before it', () {
      final f = DigitGroupsFormatter([5, 5]);
      const old = TextEditingValue(
        text: '98765 4',
        selection: TextSelection.collapsed(offset: 6),
      );
      // The person's backspace removed the space at index 5.
      final v = _type(f, old, '987654', cursor: 5);
      // Five digits left, so no group break yet.
      expect(v.text, '98764');
      expect(v.selection.baseOffset, 4);
    });

    test('digitsOf reads back the number without spacing', () {
      expect(DigitGroupsFormatter.digitsOf('98765 43210'), '9876543210');
    });
  });

  group('displayPhoneNumber', () {
    test('spaces an Indian number', () {
      expect(displayPhoneNumber('+918688712132'), '+91 86887 12132');
    });

    test('spaces a US number', () {
      expect(displayPhoneNumber('+15551234567'), '+1 555 123 4567');
    });

    test('leaves anything else alone', () {
      expect(displayPhoneNumber('+447700900123'), '+447700900123');
    });
  });

  group('showRadiusConfirm', () {
    Future<bool?> open(WidgetTester tester) async {
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    answer = await showRadiusConfirm(
                      context,
                      title: 'Delete photo?',
                      message: 'It cannot be undone.',
                      confirmLabel: 'Delete',
                      destructive: true,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('answers true from the confirm row', (tester) async {
      await open(tester);
      expect(find.text('Delete photo?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete photo?'), findsNothing);
    });

    testWidgets('answers false from Cancel and from the scrim', (tester) async {
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    answer = await showRadiusConfirm(
                      context,
                      title: 'Unblock Ava?',
                      confirmLabel: 'Unblock',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(answer, isFalse);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(answer, isFalse);
    });

    testWidgets('fits a narrow phone with a large text size', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showRadiusConfirm(
                  context,
                  title: 'Sign out of cozune?',
                  message:
                      'Your profile and chats stay as they are. You just '
                      "won't get notifications until you sign back in.",
                  confirmLabel: 'Sign out',
                  destructive: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Sign out'), findsOneWidget);
    });
  });

  group('LoginScreen', () {
    setUpAll(() async {
      // The real faces, so the layout checks measure the app's own line
      // breaks rather than the test font's much wider squares.
      for (final (family, path) in [
        ('Fraunces', 'assets/fonts/Fraunces.ttf'),
        ('DM Sans', 'assets/fonts/DMSans.ttf'),
      ]) {
        final loader = FontLoader(
          family,
        )..addFont(File(path).readAsBytes().then((b) => b.buffer.asByteData()));
        await loader.load();
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/shared_preferences'),
            (call) async => call.method == 'getAll' ? <String, Object>{} : null,
          );
      try {
        await Supabase.initialize(
          url: 'http://localhost:54321',
          publishableKey: 'test-publishable-key',
          authOptions: const FlutterAuthClientOptions(
            localStorage: EmptyLocalStorage(),
            autoRefreshToken: false,
            detectSessionInUri: false,
          ),
        );
      } catch (_) {
        // Already initialised by an earlier test in this isolate.
      }
    });

    RadiusButton sendCode(WidgetTester tester) => tester.widget<RadiusButton>(
      find.widgetWithText(RadiusButton, 'Send code'),
    );

    testWidgets('keeps "Send code" off until the number is whole', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      );

      expect(sendCode(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '98765');
      await tester.pump();
      expect(sendCode(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '9123456780');
      await tester.pump();
      expect(find.text('91234 56780'), findsOneWidget);
      expect(sendCode(tester).onPressed, isNotNull);
    });

    testWidgets('fits an iPhone SE with nothing hidden behind the footer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      );
      expect(tester.takeException(), isNull);

      final field = tester.getRect(find.byType(TextField));
      final button = tester.getRect(
        find.widgetWithText(RadiusButton, 'Send code'),
      );
      expect(field.bottom, lessThanOrEqualTo(button.top));
    });
  });
}
