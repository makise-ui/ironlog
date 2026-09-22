import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/glass_scaffold.dart';
import '../core/widgets/glass_nav_bar.dart';
import '../features/today/presentation/today_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/analytics/presentation/analytics_placeholder_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/today/presentation/exercise_picker_sheet.dart';
import '../data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/today',
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          final location = state.uri.path;
          int index = 0;
          if (location.startsWith('/history')) {
            index = 1;
          } else if (location.startsWith('/analytics')) {
            index = 2;
          } else if (location.startsWith('/settings')) {
            index = 3;
          }

          return GlassScaffold(
            body: child,
            bottomNavigationBar: GlassNavBar(
              currentIndex: index,
              onTabSelected: (newIndex) {
                switch (newIndex) {
                  case 0:
                    context.go('/today');
                    break;
                  case 1:
                    context.go('/history');
                    break;
                  case 2:
                    context.go('/analytics');
                    break;
                  case 3:
                    context.go('/settings');
                    break;
                }
              },
              onQuickLogPressed: () async {
                final repo = ref.read(workoutRepositoryProvider);
                final todayWorkout = await repo.getOrCreateTodayWorkout();

                if (context.mounted) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => ExercisePickerSheet(
                      workoutId: todayWorkout.id,
                      onExerciseSelected: (ex) async {
                        await repo.addExerciseToWorkout(
                          workoutId: todayWorkout.id,
                          exerciseId: ex.id,
                        );
                        if (context.mounted) {
                          context.go('/today');
                        }
                      },
                    ),
                  );
                }
              },
            ),
          );
        },
        routes: [
          GoRoute(
            path: '/today',
            pageBuilder: (context, state) => const CustomTransitionPage(
              child: TodayScreen(),
              transitionsBuilder: _fadeSlideTransition,
            ),
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) => const CustomTransitionPage(
              child: HistoryScreen(),
              transitionsBuilder: _fadeSlideTransition,
            ),
          ),
          GoRoute(
            path: '/analytics',
            pageBuilder: (context, state) => const CustomTransitionPage(
              child: AnalyticsPlaceholderScreen(),
              transitionsBuilder: _fadeSlideTransition,
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const CustomTransitionPage(
              child: SettingsScreen(),
              transitionsBuilder: _fadeSlideTransition,
            ),
          ),
        ],
      ),
    ],
  );
});

Widget _fadeSlideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  if (reduceMotion) {
    return child;
  }

  return FadeTransition(
    opacity: CurveTween(curve: Curves.easeOutCubic).animate(animation),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 0.03),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: child,
    ),
  );
}
