import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ironlog/features/settings/presentation/settings_screen.dart';
import 'package:ironlog/features/settings/presentation/ai_settings_screen.dart';
import 'package:ironlog/data/providers.dart';
import 'package:ironlog/data/database/database.dart';
import 'package:drift/native.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('pump SettingsScreen and verify sections', (tester) async {
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
            body: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify top AI section
    expect(find.text('AI COACH & INTELLIGENCE'), findsOneWidget);
    expect(find.text('AI Assistant & Profiles'), findsOneWidget);
    expect(find.text('WORKOUT & TRAINING'), findsOneWidget);
    expect(find.text('APPEARANCE & THEME'), findsOneWidget);
    expect(find.text('DATABASE & PERFORMANCE'), findsOneWidget);
    expect(find.text('ABOUT IRONLOG'), findsOneWidget);
  });

  testWidgets('pump AiSettingsScreen and verify profiles list', (tester) async {
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
            body: AiSettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify header and profile elements
    expect(find.text('AI Configuration'), findsOneWidget);
    expect(find.text('ACTIVE PROFILE'), findsOneWidget);
    expect(find.text('Add Profile'), findsWidgets);
    expect(find.textContaining('AVAILABLE PROFILES'), findsOneWidget);
    expect(find.text('Default AI Coach'), findsWidgets);
  });
}

