import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/data/database/database.dart';
import 'package:ironlog/data/repositories/settings_repository.dart';
import 'package:ironlog/domain/services/app_update_service.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository settingsRepo;
  late AppUpdateService updateService;

  setUp(() {
    db = AppDatabase.memory();
    settingsRepo = SettingsRepository(db);
    updateService = AppUpdateService(settingsRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('AppUpdateService Tests', () {
    test('Current release has valid highlights and metadata', () {
      expect(AppUpdateService.currentVersion, 'v1.6.0');
      expect(AppUpdateService.currentBuildNumber, 9);

      final release = AppUpdateService.currentRelease;
      expect(release.version, 'v1.6.0');
      expect(release.highlights, isNotEmpty);
      expect(release.highlights.any((h) => h.title.contains('Strain Waveform')), isTrue);
      expect(release.highlights.any((h) => h.title.contains('Luxury History Telemetry')), isTrue);
      expect(release.highlights.any((h) => h.title.contains('Markdown Changelogs')), isTrue);
    });

    test('shouldShowWhatsNew returns true on first run and false after seen', () async {
      // By default auto_check_updates is true and last_seen is null
      final shouldShow1 = await updateService.shouldShowWhatsNew();
      expect(shouldShow1, isTrue);

      // Mark seen
      await updateService.markCurrentVersionSeen();

      final shouldShow2 = await updateService.shouldShowWhatsNew();
      expect(shouldShow2, isFalse);
    });

    test('shouldShowWhatsNew returns false if auto_check_updates is disabled', () async {
      await settingsRepo.setAutoCheckUpdates(false);
      final shouldShow = await updateService.shouldShowWhatsNew();
      expect(shouldShow, isFalse);
    });

    test('checkForUpdates returns valid result offline', () async {
      final result = await updateService.checkForUpdates();
      expect(result.currentVersion, AppUpdateService.currentVersion);
      expect(result.releaseInfo.version, AppUpdateService.currentRelease.version);
      expect(result.isUpdateAvailable, isFalse);
    });
  });
}
