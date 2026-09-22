enum WeightUnit { kg, lb }

class UnitConverter {
  UnitConverter._();

  static const double kgToLbFactor = 2.20462262185;

  static double toKg(double value, WeightUnit fromUnit) {
    if (fromUnit == WeightUnit.kg) return value;
    return value / kgToLbFactor;
  }

  static double fromKg(double kgValue, WeightUnit toUnit) {
    if (toUnit == WeightUnit.kg) return kgValue;
    return kgValue * kgToLbFactor;
  }

  static String formatWeight(double weight, {WeightUnit unit = WeightUnit.kg, bool includeUnit = true}) {
    final displayWeight = fromKg(weight, unit);
    // If it's a whole number, format without decimal
    final isWhole = (displayWeight % 1).abs() < 0.001;
    final formatted = isWhole
        ? displayWeight.toInt().toString()
        : displayWeight.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');

    return includeUnit ? '$formatted ${unit.name}' : formatted;
  }

  static double roundToStep(double weight, double step) {
    if (step <= 0) return weight;
    return (weight / step).round() * step;
  }
}
