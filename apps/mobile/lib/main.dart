import 'package:flutter/material.dart';

import 'app/app_theme.dart';
import 'app/theme_controller.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'l10n/l10n.dart';
import 'navigation/bottom_navigation.dart';
import 'services/api_service.dart';
import 'services/device_id_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.init();
  final deviceId = await DeviceIdService.load();
  final onboard = await Onboarding.shouldShow();
  runApp(CalFitApp(deviceId: deviceId, showOnboarding: onboard));
}

class CalFitApp extends StatefulWidget {
  final DeviceIdService deviceId;
  final bool showOnboarding;
  const CalFitApp({super.key, required this.deviceId, this.showOnboarding = false});

  @override
  State<CalFitApp> createState() => _CalFitAppState();
}

class _CalFitAppState extends State<CalFitApp> {
  final apiService = ApiService();
  late bool _onboarding = widget.showOnboarding;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.themeMode,
        ThemeController.textScale,
        ThemeController.locale,
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
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _onboarding
                ? OnboardingScreen(
                    apiService: apiService,
                    onDone: () => setState(() => _onboarding = false),
                  )
                : BottomNavigation(apiService: apiService, userId: widget.deviceId.deviceId),
          ),
        );
      },
    );
  }
}
