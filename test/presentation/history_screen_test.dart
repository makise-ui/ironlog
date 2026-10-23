import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:ironlog/features/history/presentation/history_screen.dart';
import 'package:ironlog/data/providers.dart';
import 'package:ironlog/data/database/database.dart';
import 'package:ironlog/domain/services/backup_service.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    BackupService.cancelPendingAutoBackup();
  });

  testWidgets('HistoryScreen renders Horizon Dock, filters, calendar and toggles search', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: HistoryScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Header Elements
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Telemetry archives & training logs'), findsOneWidget);
    expect(find.text('+ Rest'), findsOneWidget);

    // 2. Verify Horizon Dock Telemetry Headers
    expect(find.text('MONTH LOAD'), findsOneWidget);
    expect(find.text('SETS COMPLETED'), findsOneWidget);
    expect(find.text('SPLIT ADHERENCE'), findsOneWidget);

    // 3. Verify Preset Filters
    expect(find.text('All Sessions'), findsOneWidget);
    expect(find.text('🏆 Heavy Volume'), findsOneWidget);
    expect(find.text('🧘 Active Rest'), findsOneWidget);

    // 4. Verify Calendar Weekdays in Calendar View Mode
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('WED'), findsOneWidget);
    expect(find.text('FRI'), findsOneWidget);
    expect(find.text('SUN'), findsOneWidget);

    // 5. Test Search Bar Toggle
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Search workouts, movements (e.g. Bench, Push)...'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Close search
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // 6. Test View Mode Toggle (Switch from Calendar to List view)
    await tester.tap(find.byIcon(Icons.view_agenda_outlined));
    await tester.pumpAndSettle();

    // In List view, weekday headers should not be shown
    expect(find.text('MON'), findsNothing);

    // Unmount and flush any pending Drift stream cancel timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
    BackupService.cancelPendingAutoBackup();
  });
}
