import '../database/database.dart';
import '../../core/utils/unit_converter.dart';

class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository(this._db);

  Future<String?> getSetting(String key) async {
    final query = _db.select(_db.settings)..where((t) => t.k.equals(key));
    final data = await query.getSingleOrNull();
    return data?.v;
  }

  Future<void> setSetting(String key, String value) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
      SettingsCompanion.insert(k: key, v: value),
    );
  }

  Future<WeightUnit> getWeightUnit() async {
    final val = await getSetting('weight_unit');
    if (val == 'lb') return WeightUnit.lb;
    return WeightUnit.kg;
  }

  Future<void> setWeightUnit(WeightUnit unit) async {
    await setSetting('weight_unit', unit.name);
  }

  Future<bool> getIncludeWarmupInVolume() async {
    final val = await getSetting('include_warmup_volume');
    return val == 'true';
  }

  Future<void> setIncludeWarmupInVolume(bool value) async {
    await setSetting('include_warmup_volume', value.toString());
  }

  Future<String> getThemeMode() async {
    return await getSetting('theme_mode') ?? 'dark';
  }

  Future<void> setThemeMode(String mode) async {
    await setSetting('theme_mode', mode);
  }

  Future<String> getAccentPreset() async {
    return await getSetting('accent_preset') ?? 'cobalt';
  }

  Future<void> setAccentPreset(String preset) async {
    await setSetting('accent_preset', preset);
  }

  Future<bool> getAiNotificationsEnabled() async {
    final val = await getSetting('ai_notifications_enabled');
    return val != 'false'; // default true
  }

  Future<void> setAiNotificationsEnabled(bool value) async {
    await setSetting('ai_notifications_enabled', value.toString());
  }

  Future<bool> getAiSuggestionsEnabled() async {
    final val = await getSetting('ai_suggestions_enabled');
    return val != 'false'; // default true
  }

  Future<void> setAiSuggestionsEnabled(bool value) async {
    await setSetting('ai_suggestions_enabled', value.toString());
  }
}
