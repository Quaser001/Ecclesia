import 'package:flutter/material.dart';

import 'app/app_theme.dart';
import 'app/theme_controller.dart';
import 'features/consent/consent_notice.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'l10n/l10n.dart';
import 'navigation/bottom_navigation.dart';
import 'services/api_service.dart';
import 'services/auth_token_store.dart';
import 'services/error_reporter.dart';
import 'services/profile_registry.dart';
import 'services/secret_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorReporter().install();
  await ThemeController.init();
  final onboard = await Onboarding.shouldShow();
  final profiles = await ProfileRegistry.load(KeystoreSecretStore());
  runApp(CalFitApp(showOnboarding: onboard, profiles: profiles));
}

class CalFitApp extends StatefulWidget {
  final bool showOnboarding;

  /// The people on this phone. Null in tests that don't need family profiles.
  final ProfileRegistry? profiles;

  const CalFitApp({
    super.key,
    this.showOnboarding = false,
    this.profiles,
  });

  @override
  State<CalFitApp> createState() => _CalFitAppState();
}

class _CalFitAppState extends State<CalFitApp> {
  late bool _onboarding = widget.showOnboarding;

  // One client per profile, each signed in as that person only.
  final _apis = <String, ApiService>{};
  // Tests without profiles only; the app always loads them.
  late final _single = ApiService(tokenStore: MemoryAuthTokenStore());

  ApiService get apiService {
    final profiles = widget.profiles;
    if (profiles == null) return _single;
    return _apis.putIfAbsent(
        profiles.activeId, () => ApiService(tokenStore: ProfileTokenStore(profiles, profiles.activeId)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.themeMode,
        ThemeController.textScale,
        ThemeController.locale,
        ?widget.profiles,
      ]),
      builder: (context, _) {
        return MaterialApp(
          onGenerateTitle: (context) => context.l10n.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.themeMode.value,
          locale: ThemeController.locale.value,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: localizationsDelegates,
          // The in-app text size multiplies the phone's own setting.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final scale = mq.textScaler.scale(1) * ThemeController.textScale.value;
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(scale.clamp(0.8, 2.0))),
              child: child!,
            );
          },
          // Each person agrees to the privacy notice before anything about
          // their health is saved or scored; a new family member too.
          home: ConsentGate(
            key: ValueKey(('consent', widget.profiles?.activeId)),
            apiService: apiService,
            profileId: widget.profiles?.activeId,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _onboarding
                  ? OnboardingScreen(
                      apiService: apiService,
                      onDone: () => setState(() => _onboarding = false),
                    )
                  // Keyed by profile: switching rebuilds every tab from scratch,
                  // so no screen keeps the previous person's data.
                  : BottomNavigation(
                      key: ValueKey(widget.profiles?.activeId),
                      apiService: apiService,
                    ),
            ),
          ),
        );
      },
    );
  }
}
