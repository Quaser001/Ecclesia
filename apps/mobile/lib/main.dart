import 'package:flutter/material.dart';

import 'app/app_theme.dart';
import 'app/theme_controller.dart';
import 'navigation/bottom_navigation.dart';
import 'services/api_service.dart';
import 'services/device_id_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.init();
  final deviceId = await DeviceIdService.load();
  runApp(CalFitApp(deviceId: deviceId));
}

class CalFitApp extends StatelessWidget {
  final DeviceIdService deviceId;
  const CalFitApp({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'CalFit - AI Nutrition & Health Scanner',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: BottomNavigation(
            apiService: apiService,
            userId: deviceId.deviceId,
          ),
        );
      },
    );
  }
}
