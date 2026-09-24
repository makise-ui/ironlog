import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/core/widgets/scale_tap.dart';
import 'package:ironlog/features/today/presentation/widgets/today_hero_session_card.dart';
import 'package:ironlog/features/today/presentation/widgets/this_week_progress_bar.dart';
import 'package:ironlog/features/today/presentation/widgets/routine_card.dart';
import 'package:ironlog/features/today/presentation/widgets/section_header.dart';

void main() {
  Widget buildTestable(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: child),
    );
  }

  group('TodayHeroSessionCard Widget Tests', () {
    testWidgets('renders planned workout with title, exercise count, and CTA', (tester) async {
      bool started = false;

      await tester.pumpWidget(
        buildTestable(
          TodayHeroSessionCard(
            title: 'Push Day (A)',
            subtitle: 'Recommended based on fatigue & split history',
            exerciseCount: 5,
            estimatedMinutes: 45,
            onStartWorkout: () => started = true,
          ),
        ),
      );

      expect(find.text("TODAY'S SESSION"), findsOneWidget);
      expect(find.text('Push Day (A)'), findsOneWidget);
      expect(find.text('Recommended based on fatigue & split history'), findsOneWidget);
      expect(find.text('5 exercises'), findsOneWidget);
      expect(find.text('~45 min'), findsOneWidget);
      expect(find.text('Start Workout'), findsOneWidget);

      await tester.tap(find.text('Start Workout'));
      await tester.pumpAndSettle();
      expect(started, isTrue);
    });

    testWidgets('renders active/paused workout with resume and discard buttons', (tester) async {
      bool resumed = false;
      bool discarded = false;

      await tester.pumpWidget(
        buildTestable(
          TodayHeroSessionCard(
            title: 'In-Progress Workout',
            subtitle: 'Active session',
            exerciseCount: 3,
            isActive: true,
            isPaused: true,
            elapsedText: '14:22',
            onStartWorkout: () => resumed = true,
            onDiscardWorkout: () => discarded = true,
          ),
        ),
      );

      expect(find.text('WORKOUT PAUSED'), findsOneWidget);
      expect(find.text('14:22'), findsOneWidget);
      expect(find.text('Resume Workout'), findsOneWidget);
      expect(find.text('Discard Active Session'), findsOneWidget);

      await tester.tap(find.text('Resume Workout'));
      await tester.pumpAndSettle();
      expect(resumed, isTrue);

      await tester.tap(find.text('Discard Active Session'));
      await tester.pumpAndSettle();
      expect(discarded, isTrue);
    });

    testWidgets('renders rest day state', (tester) async {
      bool unmarkRest = false;

      await tester.pumpWidget(
        buildTestable(
          TodayHeroSessionCard(
            title: 'Rest & Recovery Day',
            subtitle: 'Muscle tissue repairs and streak is preserved.',
            isRestDay: true,
            onStartWorkout: () => unmarkRest = true,
          ),
        ),
      );

      expect(find.text('REST & RECOVERY'), findsOneWidget);
      expect(find.text('Rest & Recovery Day'), findsOneWidget);
      expect(find.text('Log Workout Anyway'), findsOneWidget);

      await tester.tap(find.text('Log Workout Anyway'));
      await tester.pumpAndSettle();
      expect(unmarkRest, isTrue);
    });
  });

  group('ThisWeekProgressBar Widget Tests', () {
    testWidgets('renders 7 days and current workout count', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const ThisWeekProgressBar(
            completedWeekdays: {1, 3}, // Mon, Wed
            todayWeekday: 3, // Wed
            workoutsCount: 2,
          ),
        ),
      );

      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('2 / 5 days trained'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('T'), findsNWidgets(2)); // Tue, Thu
      expect(find.text('W'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
      expect(find.text('S'), findsNWidgets(2)); // Sat, Sun
    });
  });

  group('RoutineCard and SectionHeader Tests', () {
    testWidgets('renders RoutineCard and responds to tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestable(
          RoutineCard(
            'Upper Body Heavy',
            '5 ex · ~45m',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Upper Body Heavy'), findsOneWidget);
      expect(find.text('5 ex · ~45m'), findsOneWidget);

      await tester.tap(find.text('Upper Body Heavy'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('renders SectionHeader with optional action', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        buildTestable(
          SectionHeader(
            'YOUR ROUTINES',
            action: 'See all',
            onAction: () => actionTapped = true,
          ),
        ),
      );

      expect(find.text('YOUR ROUTINES'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);

      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();
      expect(actionTapped, isTrue);
    });
  });

  group('ScaleTap Micro-interaction Tests', () {
    testWidgets('triggers onTap callback', (tester) async {
      int count = 0;

      await tester.pumpWidget(
        buildTestable(
          ScaleTap(
            onPressed: () => count++,
            child: const Text('Tap target'),
          ),
        ),
      );

      expect(find.text('Tap target'), findsOneWidget);
      await tester.tap(find.text('Tap target'));
      await tester.pumpAndSettle();
      expect(count, equals(1));
    });
  });
}
