import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app_theme.dart';
import 'package:mobile/features/subscription/subscription_screen.dart';
import 'package:mobile/l10n/l10n.dart';

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.lightTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: localizationsDelegates,
      home: home,
    );

/// A tall phone viewport so the whole page is laid out (the ListView doesn't
/// lazily drop the Pro card below the fold). Reset after each test.
void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('has exactly one primary (filled) button — Hick\'s Law', (tester) async {
    _tallPhone(tester);
    await tester.pumpWidget(_app(const SubscriptionScreen()));
    await tester.pumpAndSettle();

    // One obvious main action: the CTA, defaulting to the recommended plan.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Start Plus'), findsOneWidget);
  });

  testWidgets('shows all three plans', (tester) async {
    _tallPhone(tester);
    await tester.pumpWidget(_app(const SubscriptionScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Free'), findsWidgets);
    expect(find.text('Plus'), findsWidgets);
    expect(find.text('Pro'), findsOneWidget);
  });

  testWidgets('selecting Pro updates the single CTA', (tester) async {
    _tallPhone(tester);
    await tester.pumpWidget(_app(const SubscriptionScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Start Pro'), findsOneWidget);
    expect(find.text('Start Plus'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('the CTA fails honestly — no fake success', (tester) async {
    _tallPhone(tester);
    await tester.pumpWidget(_app(const SubscriptionScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Plus'));
    await tester.pumpAndSettle();

    // Honest "coming soon", never a pretend purchase (ADR-006).
    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('does not overflow at a narrow phone width', (tester) async {
    tester.view.physicalSize = const Size(320, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const SubscriptionScreen()));
    await tester.pumpAndSettle();

    // A RenderFlex overflow throws during layout and fails the test.
    expect(tester.takeException(), isNull);
    expect(find.byType(SubscriptionScreen), findsOneWidget);
  });
}
