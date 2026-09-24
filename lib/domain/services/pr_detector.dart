import 'package:flutter/material.dart';
import '../models/set_model.dart';
import '../services/e1rm_calculator.dart';

enum PrType {
  maxWeight,
  bestE1rm,
  repsAtWeight,
  sessionVolume,
}

extension PrTypeExtension on PrType {
  String get label {
    switch (this) {
      case PrType.maxWeight:
        return 'Max Weight PR';
      case PrType.bestE1rm:
        return 'Est. 1RM PR';
      case PrType.repsAtWeight:
        return 'Rep Record';
      case PrType.sessionVolume:
        return 'Volume Record';
    }
  }

  /// Material icon for this PR type (used in confetti celebration)
  IconData get iconData {
    switch (this) {
      case PrType.maxWeight:
        return Icons.fitness_center_rounded;
      case PrType.bestE1rm:
        return Icons.bolt_rounded;
      case PrType.repsAtWeight:
        return Icons.local_fire_department_rounded;
      case PrType.sessionVolume:
        return Icons.bar_chart_rounded;
    }
  }
}

class PrResult {
  final bool isPr;
  final PrType? prType;
  final String title;
  final String description;
  final double currentValue;
  final double previousRecord;
  final String unit;

  const PrResult({
    required this.isPr,
    this.prType,
    required this.title,
    required this.description,
    this.currentValue = 0,
    this.previousRecord = 0,
    this.unit = 'kg',
  });

  static const notPr = PrResult(
    isPr: false,
    title: '',
    description: '',
  );
}

class PrDetector {
  /// Evaluates whether a newly logged working set sets a new PR
  /// compared to historical sets for this exercise (excluding warmups).
  static PrResult checkSetPr({
    required SetModel newSet,
    required List<SetModel> historicalSets,
    String weightUnit = 'kg',
  }) {
    // Only working, drop, or failure sets qualify for PRs (warmups excluded per spec)
    if (newSet.setType == SetType.warmup) {
      return PrResult.notPr;
    }

    final validHistory = historicalSets
        .where((s) => s.id != newSet.id && !s.archived && s.setType != SetType.warmup)
        .toList();

    if (validHistory.isEmpty) {
      // First time logging this exercise!
      return PrResult(
        isPr: true,
        prType: PrType.maxWeight,
        title: 'First Baseline Record!',
        description: '${newSet.weight} $weightUnit × ${newSet.reps} reps sets your starting baseline.',
        currentValue: newSet.weight,
        previousRecord: 0,
        unit: weightUnit,
      );
    }

    // 1. Check Max Weight PR
    double prevMaxWeight = 0;
    for (final s in validHistory) {
      if (s.weight > prevMaxWeight) {
        prevMaxWeight = s.weight;
      }
    }

    if (newSet.weight > prevMaxWeight) {
      final diff = newSet.weight - prevMaxWeight;
      return PrResult(
        isPr: true,
        prType: PrType.maxWeight,
        title: 'New Heaviest Weight PR!',
        description: '${newSet.weight} $weightUnit beats your previous best of $prevMaxWeight $weightUnit (+${diff.toStringAsFixed(1)} $weightUnit)!',
        currentValue: newSet.weight,
        previousRecord: prevMaxWeight,
        unit: weightUnit,
      );
    }

    // 2. Check Best Estimated 1RM PR
    final newE1rm = E1rmCalculator.calculate(newSet.weight, newSet.reps);
    double prevBestE1rm = 0;
    for (final s in validHistory) {
      final e1 = E1rmCalculator.calculate(s.weight, s.reps);
      if (e1 > prevBestE1rm) {
        prevBestE1rm = e1;
      }
    }

    if (newE1rm > prevBestE1rm && (newE1rm - prevBestE1rm) >= 0.5) {
      return PrResult(
        isPr: true,
        prType: PrType.bestE1rm,
        title: 'New Est. 1RM PR!',
        description: '${newE1rm.toStringAsFixed(1)} $weightUnit e1RM beats your previous ${prevBestE1rm.toStringAsFixed(1)} $weightUnit.',
        currentValue: newE1rm,
        previousRecord: prevBestE1rm,
        unit: weightUnit,
      );
    }

    // 3. Check Reps Record at this weight
    final setsAtThisWeight = validHistory.where((s) => (s.weight - newSet.weight).abs() < 0.01).toList();
    if (setsAtThisWeight.isNotEmpty) {
      int prevMaxRepsAtWeight = 0;
      for (final s in setsAtThisWeight) {
        if (s.reps > prevMaxRepsAtWeight) {
          prevMaxRepsAtWeight = s.reps;
        }
      }

      if (newSet.reps > prevMaxRepsAtWeight) {
        return PrResult(
          isPr: true,
          prType: PrType.repsAtWeight,
          title: 'New Rep Record at ${newSet.weight} $weightUnit!',
          description: '${newSet.reps} reps beats your previous record of $prevMaxRepsAtWeight reps.',
          currentValue: newSet.reps.toDouble(),
          previousRecord: prevMaxRepsAtWeight.toDouble(),
          unit: 'reps',
        );
      }
    }

    return PrResult.notPr;
  }
}
