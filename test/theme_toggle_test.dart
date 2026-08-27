import 'package:dating_app/core/theme/app_colors.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/core/theme/palette_scope.dart';
import 'package:dating_app/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A widget the framework has no reason to rebuild when the theme changes.
///
/// It is `const`, so its parent hands the element the *same widget instance*
/// on every rebuild and the element is skipped. It reads no [InheritedWidget],
/// so there is no dependency to invalidate. And it paints from a static token,
/// which is how nearly every surface in this app is coloured.
///
/// That combination is precisely the stale-colour case [PaletteScope]'s rebuild
/// sweep exists for. Without the sweep this box keeps its light colour on a
/// dark screen.
class _StaticTokenBox extends StatelessWidget {
  const _StaticTokenBox();

  @override
  Widget build(BuildContext context) =>
      Container(key: const Key('box'), color: AppColors.card);
}

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      builder: (context, child) => PaletteScope(child: child!),
      home: const Scaffold(body: _StaticTokenBox()),
    );
  }
}

Color? boxColour(WidgetTester tester) =>
    tester.widget<Container>(find.byKey(const Key('box'))).color;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColors.use(Brightness.light);
  });

  tearDown(() => AppColors.use(Brightness.light));

  testWidgets('flipping the switch repaints widgets that read static tokens',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _Host()),
    );
    await tester.pumpAndSettle();

    expect(boxColour(tester), RadiusPalette.light.card);

    await container.read(themeModeProvider.notifier).toggle(dark: true);
    await tester.pumpAndSettle();

    expect(
      boxColour(tester),
      RadiusPalette.dark.card,
      reason: 'the sweep did not reach a const widget reading AppColors',
    );

    await container.read(themeModeProvider.notifier).toggle(dark: false);
    await tester.pumpAndSettle();

    expect(boxColour(tester), RadiusPalette.light.card);
  });

  testWidgets('the swap keeps State alive rather than remounting the tree',
      (tester) async {
    // The sweep marks elements dirty; it must never replace them. If it did,
    // flipping the theme would empty the navigation stack and every text field
    // on screen.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _Host()),
    );
    await tester.pumpAndSettle();

    final before = tester.state(find.byType(Scaffold));

    await container.read(themeModeProvider.notifier).toggle(dark: true);
    await tester.pumpAndSettle();

    expect(identical(tester.state(find.byType(Scaffold)), before), isTrue);
  });

  group('ThemeController', () {
    test('starts on the system setting', () {
      SharedPreferences.setMockInitialValues({});
      expect(ThemeController().state, ThemeMode.system);
    });

    test('remembers an explicit choice', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = ThemeController();
      await controller.toggle(dark: true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('restores the remembered choice on the next launch', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final controller = ThemeController();
      // The read is async; the constructor cannot await it.
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, ThemeMode.dark);
    });

    test('falls back to the system on a value it does not recognise', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
      final controller = ThemeController();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, ThemeMode.system);
    });
  });
}
