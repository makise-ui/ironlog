import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/glass_scaffold.dart';
import '../core/widgets/glass_nav_bar.dart';
import '../features/today/presentation/today_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/analytics/presentation/analytics_screen.dart';
import '../features/analytics/presentation/growth_timeline_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/ai_settings_screen.dart';
import '../features/today/presentation/exercise_picker_sheet.dart';
import '../features/today/presentation/widgets/ai_floating_capsule.dart';
import '../features/ai/presentation/ai_assistant_screen.dart';
import '../features/nutrition/presentation/nutrition_screen.dart';
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

          final isWorkoutActive = ref.watch(isWorkoutActiveProvider);

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              if (location != '/today') {
                context.go('/today');
                return;
              }
              // If in an active workout session, back should collapse/pause it to Today home view
              if (isWorkoutActive) {
                ref.read(requestCollapseWorkoutProvider.notifier).state++;
                return;
              }
              final shouldExit = await _showExitConfirmationDialog(context);
              if (shouldExit == true) {
                SystemNavigator.pop();
              }
            },
            child: GlassScaffold(
            body: Stack(
              children: [
                child,
                const AiFloatingCapsule(),
              ],
            ),
            bottomNavigationBar: isWorkoutActive
                ? null
                : GlassNavBar(
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
                          enableDrag: false,
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
            ),
          );
        },
        routes: [
          GoRoute(
            path: '/today',
            pageBuilder: (context, state) {
              final dateStr = state.uri.queryParameters['date'];
              final initialDate = dateStr != null ? DateTime.tryParse(dateStr) : null;
              return CustomTransitionPage(
                child: TodayScreen(initialDate: initialDate),
                transitionDuration: const Duration(milliseconds: 220),
                reverseTransitionDuration: const Duration(milliseconds: 180),
                transitionsBuilder: _fadeSlideTransition,
              );
            },
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) => const CustomTransitionPage(
              child: HistoryScreen(),
              transitionDuration: Duration(milliseconds: 220),
              reverseTransitionDuration: Duration(milliseconds: 180),
              transitionsBuilder: _fadeSlideTransition,
            ),
          ),
          GoRoute(
            path: '/analytics',
            pageBuilder: (context, state) => const CustomTransitionPage(
              child: AnalyticsScreen(),
              transitionDuration: Duration(milliseconds: 220),
              reverseTransitionDuration: Duration(milliseconds: 180),
              transitionsBuilder: _fadeSlideTransition,
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const CustomTransitionPage(
              child: SettingsScreen(),
              transitionDuration: Duration(milliseconds: 220),
              reverseTransitionDuration: Duration(milliseconds: 180),
              transitionsBuilder: _fadeSlideTransition,
            ),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/ai',
        pageBuilder: (context, state) => const CustomTransitionPage(
          child: AiSettingsScreen(),
          transitionDuration: Duration(milliseconds: 250),
          reverseTransitionDuration: Duration(milliseconds: 200),
          transitionsBuilder: _fadeSlideTransition,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/ai',
        pageBuilder: (context, state) => const CustomTransitionPage(
          child: AiAssistantScreen(),
          transitionDuration: Duration(milliseconds: 250),
          reverseTransitionDuration: Duration(milliseconds: 200),
          transitionsBuilder: _fadeSlideTransition,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/analytics/timeline',
        pageBuilder: (context, state) => const CustomTransitionPage(
          child: GrowthTimelineScreen(),
          transitionDuration: Duration(milliseconds: 250),
          reverseTransitionDuration: Duration(milliseconds: 200),
          transitionsBuilder: _fadeSlideTransition,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/nutrition',
        pageBuilder: (context, state) => const CustomTransitionPage(
          child: NutritionScreen(),
          transitionDuration: Duration(milliseconds: 250),
          reverseTransitionDuration: Duration(milliseconds: 200),
          transitionsBuilder: _fadeSlideTransition,
        ),
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

  final curvedAnimation = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  return FadeTransition(
    opacity: curvedAnimation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 0.02),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: child,
    ),
  );
}

Future<bool> _showExitConfirmationDialog(BuildContext context) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1118) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.09) : Colors.black.withValues(alpha: 0.07),
            width: 1.2,
          ),
        ),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.exit_to_app_rounded,
                    color: AppColors.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exit IronLog?',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Leave active application session',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to leave the app? Any active workout in progress will stay saved.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                height: 1.45,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.of(ctx).pop(false),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF181B24) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Stay',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.of(ctx).pop(true),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Exit',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result ?? false;
}
