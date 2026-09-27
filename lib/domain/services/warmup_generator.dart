class WarmupSetProposal {
  final int setIndex;
  final double weight;
  final int reps;
  final double percentage;
  final String label;

  const WarmupSetProposal({
    required this.setIndex,
    required this.weight,
    required this.reps,
    required this.percentage,
    required this.label,
  });
}

class WarmupGenerator {
  /// Generates a scientifically ramped warm-up set sequence for any target working weight
  static List<WarmupSetProposal> generate({
    required double targetWeight,
    double barWeight = 20.0,
    double weightStep = 2.5,
    bool isBarbell = true,
    bool isBodyweight = false,
  }) {
    if (isBodyweight || targetWeight <= 0) {
      return const [
        WarmupSetProposal(
          setIndex: 1,
          weight: 0.0,
          reps: 10,
          percentage: 0.0,
          label: 'Light Joint Activation',
        ),
      ];
    }

    final proposals = <WarmupSetProposal>[];

    if (isBarbell && targetWeight >= (barWeight + 20.0)) {
      // 4-stage Olympic Barbell ramp
      // 1. Empty Bar
      proposals.add(WarmupSetProposal(
        setIndex: 1,
        weight: barWeight,
        reps: 10,
        percentage: (barWeight / targetWeight) * 100,
        label: 'Empty Bar Mobilization',
      ));

      // 2. 50% Target
      final w50 = _roundToStep(targetWeight * 0.50, weightStep);
      if (w50 > barWeight) {
        proposals.add(WarmupSetProposal(
          setIndex: proposals.length + 1,
          weight: w50,
          reps: 5,
          percentage: 50.0,
          label: 'Pattern Priming',
        ));
      }

      // 3. 70% Target
      final w70 = _roundToStep(targetWeight * 0.70, weightStep);
      if (w70 > (proposals.lastOrNull?.weight ?? 0)) {
        proposals.add(WarmupSetProposal(
          setIndex: proposals.length + 1,
          weight: w70,
          reps: 3,
          percentage: 70.0,
          label: 'CNS Preparation',
        ));
      }

      // 4. 85% Target
      final w85 = _roundToStep(targetWeight * 0.85, weightStep);
      if (w85 > (proposals.lastOrNull?.weight ?? 0) && w85 < targetWeight) {
        proposals.add(WarmupSetProposal(
          setIndex: proposals.length + 1,
          weight: w85,
          reps: 1,
          percentage: 85.0,
          label: 'Neural Potentiation',
        ));
      }
    } else {
      // Dumbbells / Cables / Machines / Lighter compound ramp
      // Stage 1: ~50%
      final w50 = _roundToStep(targetWeight * 0.50, weightStep);
      if (w50 > 0) {
        proposals.add(WarmupSetProposal(
          setIndex: 1,
          weight: w50,
          reps: 8,
          percentage: 50.0,
          label: 'Light Activation',
        ));
      }

      // Stage 2: ~75%
      final w75 = _roundToStep(targetWeight * 0.75, weightStep);
      if (w75 > (proposals.lastOrNull?.weight ?? 0) && w75 < targetWeight) {
        proposals.add(WarmupSetProposal(
          setIndex: proposals.length + 1,
          weight: w75,
          reps: 4,
          percentage: 75.0,
          label: 'Potentiation',
        ));
      }
    }

    return proposals;
  }

  static double _roundToStep(double val, double step) {
    if (step <= 0) return val;
    final quotient = (val / step).round();
    final rounded = quotient * step;
    return double.parse(rounded.toStringAsFixed(2));
  }
}
