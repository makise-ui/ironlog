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

  /// Calculates session volume = sum(weight * reps)
  /// If [isPerHand] is true, multiplies load x 2.
  static double calculateSetVolume(double weight, int reps, {bool isPerHand = false}) {
    if (weight <= 0 || reps <= 0) return 0.0;
    final effectiveWeight = isPerHand ? weight * 2.0 : weight;
    return effectiveWeight * reps;
  }
}
