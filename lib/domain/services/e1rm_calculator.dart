class E1rmCalculator {
  E1rmCalculator._();

  /// Calculates estimated 1 Rep Max using the Epley formula: weight * (1 + reps / 30)
  /// If reps == 1, e1RM is exactly weight.
  /// If reps <= 0 or weight <= 0, returns 0.
  static double calculateEpley(double weight, int reps) {
    if (weight <= 0 || reps <= 0) return 0.0;
    if (reps == 1) return weight;
    return weight * (1.0 + (reps / 30.0));
  }

  static double calculate(double weight, int reps) => calculateEpley(weight, reps);

  /// Calculates session volume = sum(effectiveWeight * reps)
  /// If [isPerHand] is true, multiplies load x 2.
  /// If [isAssisted] or weight < 0, calculates net moved load if [userBodyweight] is provided,
  /// or preserves the absolute assistance counterweight instead of discarding it to 0.
  static double calculateSetVolume(
    double weight,
    int reps, {
    bool isPerHand = false,
    bool isAssisted = false,
    double? userBodyweight,
  }) {
    if (reps <= 0) return 0.0;
    double effectiveLoad;
    if (isAssisted || weight < 0) {
      final assist = weight.abs();
      if (userBodyweight != null && userBodyweight > assist) {
        effectiveLoad = userBodyweight - assist;
      } else {
        effectiveLoad = assist;
      }
    } else {
      if (weight <= 0) return 0.0;
      effectiveLoad = weight;
    }
    final finalWeight = isPerHand ? effectiveLoad * 2.0 : effectiveLoad;
    return finalWeight * reps;
  }
}
