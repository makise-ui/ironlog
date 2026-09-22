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
}
