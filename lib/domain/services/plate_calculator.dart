import 'package:flutter/material.dart';

enum BarType {
  olympicMen(name: 'Olympic Bar (20 kg / 45 lb)', weightKg: 20.0, weightLb: 45.0),
  olympicWomen(name: 'Women’s Bar (15 kg / 35 lb)', weightKg: 15.0, weightLb: 35.0),
  ezCurl(name: 'EZ Curl Bar (10 kg / 25 lb)', weightKg: 10.0, weightLb: 25.0),
  smithMachine(name: 'Smith Machine (7 kg / 15 lb)', weightKg: 7.0, weightLb: 15.0),
  emptyCollar(name: 'Pin / No Bar (0 kg)', weightKg: 0.0, weightLb: 0.0);

  final String name;
  final double weightKg;
  final double weightLb;

  const BarType({
    required this.name,
    required this.weightKg,
    required this.weightLb,
  });

  double getWeight(bool isLb) => isLb ? weightLb : weightKg;
}

class PlateSpec {
  final double weight;
  final Color color;
  final Color textColor;
  final double heightRatio; // For visual plate diameter rendering (0.4 to 1.0)
  final double thickness;

  const PlateSpec({
    required this.weight,
    required this.color,
    this.textColor = Colors.white,
    required this.heightRatio,
    this.thickness = 14.0,
  });
}

class PlateCount {
  final PlateSpec spec;
  final int count;

  const PlateCount({required this.spec, required this.count});
}

class PlateCalculationResult {
  final double targetWeight;
  final double barWeight;
  final double weightPerSide;
  final double totalLoadedWeight;
  final double remainder;
  final bool isExact;
  final List<PlateCount> platesPerSide;
  final List<PlateSpec> individualPlatesPerSide;
  final bool isLb;

  const PlateCalculationResult({
    required this.targetWeight,
    required this.barWeight,
    required this.weightPerSide,
    required this.totalLoadedWeight,
    required this.remainder,
    required this.isExact,
    required this.platesPerSide,
    required this.individualPlatesPerSide,
    required this.isLb,
  });
}

class PlateCalculator {
  // Standard Olympic Metric Plates
  static const List<PlateSpec> standardMetricPlates = [
    PlateSpec(weight: 25.0, color: Color(0xFFD32F2F), heightRatio: 1.0, thickness: 18.0),
    PlateSpec(weight: 20.0, color: Color(0xFF1976D2), heightRatio: 1.0, thickness: 16.0),
    PlateSpec(weight: 15.0, color: Color(0xFFFBC02D), textColor: Colors.black87, heightRatio: 0.90, thickness: 14.0),
    PlateSpec(weight: 10.0, color: Color(0xFF388E3C), heightRatio: 0.78, thickness: 12.0),
    PlateSpec(weight: 5.0, color: Color(0xFFE0E0E0), textColor: Colors.black87, heightRatio: 0.65, thickness: 10.0),
    PlateSpec(weight: 2.5, color: Color(0xFF424242), heightRatio: 0.52, thickness: 8.0),
    PlateSpec(weight: 1.25, color: Color(0xFF78909C), heightRatio: 0.42, thickness: 6.0),
    PlateSpec(weight: 0.5, color: Color(0xFFFFB300), textColor: Colors.black87, heightRatio: 0.35, thickness: 5.0),
  ];

  // Standard Imperial Plates
  static const List<PlateSpec> standardImperialPlates = [
    PlateSpec(weight: 45.0, color: Color(0xFF1976D2), heightRatio: 1.0, thickness: 18.0),
    PlateSpec(weight: 35.0, color: Color(0xFFFBC02D), textColor: Colors.black87, heightRatio: 0.90, thickness: 16.0),
    PlateSpec(weight: 25.0, color: Color(0xFF388E3C), heightRatio: 0.78, thickness: 14.0),
    PlateSpec(weight: 10.0, color: Color(0xFFE0E0E0), textColor: Colors.black87, heightRatio: 0.65, thickness: 10.0),
    PlateSpec(weight: 5.0, color: Color(0xFF424242), heightRatio: 0.52, thickness: 8.0),
    PlateSpec(weight: 2.5, color: Color(0xFF78909C), heightRatio: 0.42, thickness: 6.0),
  ];

  /// Computes the exact plates needed per side for target weight
  static PlateCalculationResult calculate({
    required double targetWeight,
    double barWeight = 20.0,
    bool isLb = false,
    List<PlateSpec>? availablePlates,
  }) {
    final plates = availablePlates ?? (isLb ? standardImperialPlates : standardMetricPlates);
    final sortedPlates = List<PlateSpec>.from(plates)..sort((a, b) => b.weight.compareTo(a.weight));

    if (targetWeight <= barWeight) {
      return PlateCalculationResult(
        targetWeight: targetWeight,
        barWeight: barWeight,
        weightPerSide: 0.0,
        totalLoadedWeight: barWeight,
        remainder: 0.0,
        isExact: targetWeight == barWeight,
        platesPerSide: const [],
        individualPlatesPerSide: const [],
        isLb: isLb,
      );
    }

    final double targetPerSide = (targetWeight - barWeight) / 2.0;
    double remaining = targetPerSide;
    final plateCounts = <PlateCount>[];
    final individualPlates = <PlateSpec>[];

    for (final plate in sortedPlates) {
      if (plate.weight <= 0) continue;
      final count = (remaining / plate.weight).floor();
      if (count > 0) {
        plateCounts.add(PlateCount(spec: plate, count: count));
        for (int i = 0; i < count; i++) {
          individualPlates.add(plate);
        }
        remaining -= count * plate.weight;
        // Float precision cleanup
        remaining = double.parse(remaining.toStringAsFixed(4));
      }
    }

    final totalLoaded = barWeight + ((targetPerSide - remaining) * 2.0);
    final roundedLoaded = double.parse(totalLoaded.toStringAsFixed(2));
    final roundedRemainder = double.parse((remaining * 2.0).toStringAsFixed(2));

    return PlateCalculationResult(
      targetWeight: targetWeight,
      barWeight: barWeight,
      weightPerSide: double.parse((targetPerSide - remaining).toStringAsFixed(2)),
      totalLoadedWeight: roundedLoaded,
      remainder: roundedRemainder,
      isExact: roundedRemainder == 0.0,
      platesPerSide: plateCounts,
      individualPlatesPerSide: individualPlates,
      isLb: isLb,
    );
  }
}
