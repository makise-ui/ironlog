enum ProgressionPolicyType {
  doubleProgression,
  linear,
  greyskullLp,
  off;

  String get displayName {
    switch (this) {
      case ProgressionPolicyType.doubleProgression:
        return 'Double Progression';
      case ProgressionPolicyType.linear:
        return 'Linear Progression (LP)';
      case ProgressionPolicyType.greyskullLp:
        return 'Greyskull LP (AMRAP)';
      case ProgressionPolicyType.off:
        return 'Fixed (Manual)';
    }
  }

  String get description {
    switch (this) {
      case ProgressionPolicyType.doubleProgression:
        return 'Work inside rep range (e.g. 8-12). When all sets hit max reps, step up weight and reset to min reps.';
      case ProgressionPolicyType.linear:
        return 'Hit all prescribed reps across every set to increase weight. 3 consecutive misses trigger a 10% deload.';
      case ProgressionPolicyType.greyskullLp:
        return 'Straight sets plus a final AMRAP set. Exceeding target advances weight; doubling reps doubles the increment.';
      case ProgressionPolicyType.off:
        return 'Keep weight and rep targets unchanged unless edited manually.';
    }
  }
}
