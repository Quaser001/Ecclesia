import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/app/app_theme.dart';
import 'package:mobile/app/theme_controller.dart';
import 'package:mobile/features/profile/body_details_sheet.dart';
import 'package:mobile/features/settings/settings_screen.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/navigation/bottom_navigation.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

/// Mirrors main.dart: the app rebuilds when the saved language changes.
Widget _app(Widget home) => ValueListenableBuilder<Locale?>(
      valueListenable: ThemeController.locale,
      builder: (context, locale, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: localizationsDelegates,
        home: home,
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'calfit.disclaimer_acknowledged.v1': true});
    ThemeController.locale.value = null;
  });

  testWidgets('choosing Hindi in Settings switches the app to Hindi', (tester) async {
    final api = ApiService(baseUrl: 'http://test', client: MockClient((_) async => _json({})),
        tokenStore: MemoryAuthTokenStore());
    await tester.pumpWidget(_app(SettingsScreen(apiService: api)));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('हिन्दी'), 200);
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(find.text('सेटिंग्स'), findsOneWidget);
    expect(ThemeController.locale.value?.languageCode, 'hi');
  });

  for (final (locale, name) in supportedLanguages) {
    testWidgets('the app shell renders in $name', (tester) async {
      ThemeController.locale.value = locale;
      final api = ApiService(
        baseUrl: 'http://test',
        client: MockClient((req) async => req.url.path == '/api/v1/auth/device'
            ? _json({'user_id': 'u', 'token': 't'})
            : req.url.path == '/api/v1/scans/history'
                ? _json(<Object>[])
                : _json({'user_id': 'u', 'health_conditions': [], 'allergies': [],
                         'dietary_preferences': [], 'health_goals': []})),
        tokenStore: MemoryAuthTokenStore(),
      );
      await tester.pumpWidget(_app(BottomNavigation(apiService: api, userId: 'u')));
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(locale);
      expect(find.text(l.navHome), findsOneWidget);
      expect(find.text(l.navProfile), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('delete my data asks first; cancelling sends nothing', (tester) async {
    final deletes = <http.Request>[];
    final store = MemoryAuthTokenStore();
    await store.write('t'); // an install that has used the app
    final client = MockClient((req) async {
      if (req.url.path == '/api/v1/auth/device') return _json({'user_id': 'u', 'token': 't'});
      if (req.method == 'DELETE') {
        deletes.add(req);
        return _json({'scans_deleted': 3, 'photos_deleted': 3});
      }
      return _json({});
    });
    final api = ApiService(baseUrl: 'http://test', client: client, tokenStore: store);
    await tester.pumpWidget(_app(Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => SettingsScreen(apiService: api))),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Delete my data'), 200);
    await tester.tap(find.text('Delete my data'));
    await tester.pumpAndSettle();
    expect(find.text('Delete all your data?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deletes, isEmpty);

    await tester.tap(find.text('Delete my data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();

    expect(deletes, hasLength(1));
    expect(await store.read(), isNull); // next request starts a fresh identity
    expect(find.text('Your data has been deleted.'), findsOneWidget);
  });

  testWidgets('body details reject impossible values and save good ones', (tester) async {
    UserProfile? saved;
    final profile = UserProfile(userId: 'u', name: 'Suhail');
    await tester.pumpWidget(_app(Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => saved = await showBodyDetailsSheet(context, profile),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Height'), '400');
    await tester.enterText(find.widgetWithText(TextFormField, 'Weight'), '72.5');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number between 50 and 250'), findsOneWidget);
    expect(saved, isNull);

    await tester.enterText(find.widgetWithText(TextFormField, 'Height'), '172');
    await tester.ensureVisible(find.text('Male'));
    await tester.tap(find.text('Male'));
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved?.heightCm, 172);
    expect(saved?.weightKg, 72.5);
    expect(saved?.sex, 'male');
    expect(saved?.name, 'Suhail'); // other fields untouched
  });
}
