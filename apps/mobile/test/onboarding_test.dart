import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/app/app_theme.dart';
import 'package:mobile/app/theme_controller.dart';
import 'package:mobile/features/onboarding/onboarding_screen.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

Widget _app(Widget home) => ValueListenableBuilder<Locale?>(
      valueListenable: ThemeController.locale,
      builder: (context, locale, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        locale: locale,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  setUp(() => ThemeController.locale.value = null);

  test('fresh installs see onboarding; people who used the app do not', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await Onboarding.shouldShow(), isTrue);
    SharedPreferences.setMockInitialValues({'calfit.disclaimer_acknowledged.v1': true});
    expect(await Onboarding.shouldShow(), isFalse);
    SharedPreferences.setMockInitialValues({'calfit.onboarded.v1': true});
    expect(await Onboarding.shouldShow(), isFalse);
  });

  testWidgets('picks are added to the profile, nothing existing is lost', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Map<String, dynamic>? saved;
    var done = false;
    final api = ApiService(
      baseUrl: 'http://test',
      tokenStore: MemoryAuthTokenStore(),
      client: MockClient((req) async {
        if (req.url.path == '/api/v1/auth/device') return _json({'user_id': 'u', 'token': 't'});
        if (req.method == 'PUT') {
          saved = jsonDecode(req.body) as Map<String, dynamic>;
          return _json({'user_id': 'u', ...saved!});
        }
        return _json({'user_id': 'u', 'name': 'Suhail', 'allergies': ['sesame'],
                      'health_goals': ['weight_loss'], 'height_cm': 172});
      }),
    );
    await tester.pumpWidget(_app(OnboardingScreen(apiService: api, onDone: () => done = true)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Peanut'));
    await tester.tap(find.text('Hypertension'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    // The app swaps screens on done; here the spinner stays, so pump in steps.
    for (var i = 0; i < 10 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(done, isTrue);
    expect(saved!['allergies'], containsAll(['sesame', 'peanut']));
    expect(saved!['health_conditions'], ['hypertension']);
    expect(saved!['health_goals'], ['weight_loss']);
    expect(saved!['height_cm'], 172);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('calfit.onboarded.v1'), isTrue);
    expect(prefs.getBool('calfit.disclaimer_acknowledged.v1'), isTrue);
  });

  testWidgets('choosing a language on the welcome page switches the app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiService(baseUrl: 'http://test', tokenStore: MemoryAuthTokenStore(),
        client: MockClient((_) async => _json({})));
    await tester.pumpWidget(_app(OnboardingScreen(apiService: api, onDone: () {})));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('বাংলা'), 200,
        scrollable: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();
    expect(find.text('পরের'), findsOneWidget); // "Next" in Bengali
  });
}
