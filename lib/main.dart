import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'data/providers.dart';
import 'domain/services/rest_timer_service.dart';
import 'domain/services/app_notification_service.dart';
import 'domain/services/home_widget_service.dart';
import 'routes/app_router.dart';

import 'features/intro/presentation/intro_3d_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge display with transparent system bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Initialize notifications & Android home screen widgets gracefully
  try {
    await RestTimerService.instance.initialize();
    await AppNotificationService.instance.initialize();
    await AppNotificationService.instance.requestPermissions();
    await HomeWidgetService.init();
  } catch (e) {
    debugPrint('Service init warning: $e');
  }

  runApp(
    const ProviderScope(
      child: IronLogApp(),
    ),
  );
}

class IronLogApp extends ConsumerWidget {
  const IronLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Watch accent preset so MaterialApp updates when accent changes
    ref.watch(accentPresetProvider);

    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    C.isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && platformBrightness == Brightness.dark);

    return MaterialApp.router(
      title: 'IronLog',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return Intro3DOverlay(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
