enum EquipmentType {
  barbell,
  dumbbell,
  machine,
  cable,
  bodyweight,
  assisted,
  other,
}

class WeightStepLearner {
  WeightStepLearner._();

  static double defaultStepForEquipment(EquipmentType equipment) {
    switch (equipment) {
      case EquipmentType.dumbbell:
        return 2.5;
      case EquipmentType.barbell:
        return 2.5;
      case EquipmentType.machine:
        return 5.0;
      case EquipmentType.cable:
        return 2.5;
      case EquipmentType.bodyweight:
      case EquipmentType.assisted:
        return 2.5;
      case EquipmentType.other:
        return 2.5;
    }
  }

  /// Calculates the learned weight step from historical weights logged for an exercise.
  /// Rule: Smallest positive difference between distinct weights in history.
  /// Falls back to equipment default if fewer than 2 distinct weights exist.
  static double learnStep({
    required List<double> historicalWeights,
    required EquipmentType equipment,
    double? existingStep,
  }) {
    // Extract unique positive weights sorted ascending
    final uniqueWeights = historicalWeights
        .where((w) => w > 0.001)
        .toSet()
        .toList()
      ..sort();

    if (uniqueWeights.length < 2) {
      return existingStep ?? defaultStepForEquipment(equipment);
    }

    double? minDiff;
    for (int i = 1; i < uniqueWeights.length; i++) {
      final diff = double.parse((uniqueWeights[i] - uniqueWeights[i - 1]).toStringAsFixed(2));
      if (diff > 0.05) { // filter out floating point anomalies
        if (minDiff == null || diff < minDiff) {
          minDiff = diff;
        }
      }
    }

    if (minDiff != null && minDiff > 0.05 && minDiff <= 25.0) {
      return minDiff;
    }

    return existingStep ?? defaultStepForEquipment(equipment);
  }
}
