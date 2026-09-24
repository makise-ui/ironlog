import 'dart:convert';

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
  preWorkout,
  postWorkout;

  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snack:
        return 'Snack';
      case MealType.preWorkout:
        return 'Pre-Workout';
      case MealType.postWorkout:
        return 'Post-Workout Fuel';
    }
  }

  static MealType fromString(String val) {
    return MealType.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => MealType.snack,
    );
  }
}

class MealItem {
  final String id;
  final String name;
  final double protein; // grams
  final double carbs; // grams
  final double fat; // grams
  final int calories; // kcal
  final MealType mealType;
  final DateTime loggedAt;

  const MealItem({
    required this.id,
    required this.name,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calories,
    required this.mealType,
    required this.loggedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'calories': calories,
      'mealType': mealType.name,
      'loggedAt': loggedAt.toIso8601String(),
    };
  }

  factory MealItem.fromMap(Map<String, dynamic> map) {
    return MealItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Meal',
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      mealType: MealType.fromString(map['mealType'] as String? ?? 'snack'),
      loggedAt: map['loggedAt'] != null
          ? DateTime.tryParse(map['loggedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory MealItem.fromJson(String source) =>
      MealItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class RecommendedFood {
  final String name;
  final String portion;
  final double protein;
  final double carbs;
  final double fat;
  final int calories;
  final String category; // e.g. "Post-Workout", "High-Protein", "Recovery"
  final String benefit;

  const RecommendedFood({
    required this.name,
    required this.portion,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calories,
    required this.category,
    required this.benefit,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'portion': portion,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'calories': calories,
      'category': category,
      'benefit': benefit,
    };
  }

  factory RecommendedFood.fromMap(Map<String, dynamic> map) {
    return RecommendedFood(
      name: map['name'] as String? ?? '',
      portion: map['portion'] as String? ?? '',
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      category: map['category'] as String? ?? 'Fuel',
      benefit: map['benefit'] as String? ?? '',
    );
  }
}

class MacroTarget {
  final double protein; // grams
  final double carbs; // grams
  final double fat; // grams
  final int calories; // kcal
  final int waterMl; // ml
  final String workoutContextSummary;
  final String reasoning;
  final String postWorkoutTip;
  final List<String> micronutrients;
  final List<RecommendedFood> recommendedFoods;

  const MacroTarget({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calories,
    required this.waterMl,
    required this.workoutContextSummary,
    required this.reasoning,
    required this.postWorkoutTip,
    required this.micronutrients,
    required this.recommendedFoods,
  });

  Map<String, dynamic> toMap() {
    return {
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'calories': calories,
      'waterMl': waterMl,
      'workoutContextSummary': workoutContextSummary,
      'reasoning': reasoning,
      'postWorkoutTip': postWorkoutTip,
      'micronutrients': micronutrients,
      'recommendedFoods': recommendedFoods.map((f) => f.toMap()).toList(),
    };
  }

  factory MacroTarget.fromMap(Map<String, dynamic> map) {
    return MacroTarget(
      protein: (map['protein'] as num?)?.toDouble() ?? 150.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 220.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 65.0,
      calories: (map['calories'] as num?)?.toInt() ?? 2200,
      waterMl: (map['waterMl'] as num?)?.toInt() ?? 3000,
      workoutContextSummary: map['workoutContextSummary'] as String? ?? 'General Training',
      reasoning: map['reasoning'] as String? ?? 'Optimal athletic performance and tissue recovery targets.',
      postWorkoutTip: map['postWorkoutTip'] as String? ?? 'Consume 30g protein + 40g carbs within 90 mins.',
      micronutrients: (map['micronutrients'] as List?)?.map((e) => e.toString()).toList() ?? [],
      recommendedFoods: (map['recommendedFoods'] as List?)
              ?.map((e) => RecommendedFood.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }

  static MacroTarget defaultTarget() {
    return const MacroTarget(
      protein: 160.0,
      carbs: 230.0,
      fat: 65.0,
      calories: 2250,
      waterMl: 3200,
      workoutContextSummary: 'Rest / Active Recovery',
      reasoning: 'Baseline maintenance with high protein to foster muscular repair and hormonal equilibrium.',
      postWorkoutTip: 'Ensure a steady intake of 25–35g protein every 3–4 hours.',
      micronutrients: [
        'Magnesium (350mg) for muscle relaxation & sleep',
        'Potassium (3,000mg) for cellular hydration',
        'Omega-3 fatty acids for joint recovery',
      ],
      recommendedFoods: [
        RecommendedFood(
          name: 'Grilled Chicken & Jasmine Rice',
          portion: '160g chicken, 200g rice',
          protein: 48,
          carbs: 56,
          fat: 5,
          calories: 460,
          category: 'Post-Workout Fuel',
          benefit: 'Rapid glycogen restoration & fast-absorbing amino acids',
        ),
        RecommendedFood(
          name: 'Greek Yogurt with Blueberries & Honey',
          portion: '200g 0% Greek yogurt, 50g berries',
          protein: 22,
          carbs: 24,
          fat: 1,
          calories: 190,
          category: 'Muscle Protein Synthesis',
          benefit: 'Slow-digesting casein and antioxidant rich polyphenols',
        ),
        RecommendedFood(
          name: 'Atlantic Salmon & Sweet Potato',
          portion: '150g salmon, 1 medium sweet potato',
          protein: 34,
          carbs: 38,
          fat: 16,
          calories: 430,
          category: 'Anti-Inflammatory Dinner',
          benefit: 'High EPA/DHA omega-3s to reduce muscle soreness and inflammation',
        ),
      ],
    );
  }
}

class DailyNutritionLog {
  final DateTime date;
  final List<MealItem> meals;
  final int waterMl;
  final MacroTarget target;

  const DailyNutritionLog({
    required this.date,
    required this.meals,
    required this.waterMl,
    required this.target,
  });

  double get consumedProtein => meals.fold(0.0, (acc, m) => acc + m.protein);
  double get consumedCarbs => meals.fold(0.0, (acc, m) => acc + m.carbs);
  double get consumedFat => meals.fold(0.0, (acc, m) => acc + m.fat);
  int get consumedCalories => meals.fold(0, (acc, m) => acc + m.calories);

  double get proteinRemaining => (target.protein - consumedProtein).clamp(0.0, 9999.0);
  int get caloriesRemaining => (target.calories - consumedCalories).clamp(0, 99999);
  int get waterRemaining => (target.waterMl - waterMl).clamp(0, 99999);

  double get proteinRatio => target.protein <= 0 ? 0 : (consumedProtein / target.protein).clamp(0.0, 1.5);
  double get caloriesRatio => target.calories <= 0 ? 0 : (consumedCalories / target.calories).clamp(0.0, 1.5);
  double get carbsRatio => target.carbs <= 0 ? 0 : (consumedCarbs / target.carbs).clamp(0.0, 1.5);
  double get fatRatio => target.fat <= 0 ? 0 : (consumedFat / target.fat).clamp(0.0, 1.5);
  double get waterRatio => target.waterMl <= 0 ? 0 : (waterMl / target.waterMl).clamp(0.0, 1.5);

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'meals': meals.map((m) => m.toMap()).toList(),
      'waterMl': waterMl,
      'target': target.toMap(),
    };
  }

  factory DailyNutritionLog.fromMap(Map<String, dynamic> map, {MacroTarget? fallbackTarget}) {
    final date = map['date'] != null
        ? DateTime.tryParse(map['date'] as String) ?? DateTime.now()
        : DateTime.now();

    final meals = (map['meals'] as List?)
            ?.map((m) => MealItem.fromMap(Map<String, dynamic>.from(m as Map)))
            .toList() ??
        [];

    final waterMl = (map['waterMl'] as num?)?.toInt() ?? 0;

    final target = map['target'] != null
        ? MacroTarget.fromMap(Map<String, dynamic>.from(map['target'] as Map))
        : (fallbackTarget ?? MacroTarget.defaultTarget());

    return DailyNutritionLog(
      date: date,
      meals: meals,
      waterMl: waterMl,
      target: target,
    );
  }

  DailyNutritionLog copyWith({
    DateTime? date,
    List<MealItem>? meals,
    int? waterMl,
    MacroTarget? target,
  }) {
    return DailyNutritionLog(
      date: date ?? this.date,
      meals: meals ?? this.meals,
      waterMl: waterMl ?? this.waterMl,
      target: target ?? this.target,
    );
  }
}

class AnalyzedFoodResult {
  final String mealName;
  final double protein;
  final double carbs;
  final double fat;
  final int calories;
  final MealType mealType;
  final String summary;
  final List<String> detectedItems;

  const AnalyzedFoodResult({
    required this.mealName,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calories,
    required this.mealType,
    required this.summary,
    this.detectedItems = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'mealName': mealName,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'calories': calories,
      'mealType': mealType.name,
      'summary': summary,
      'detectedItems': detectedItems,
    };
  }

  factory AnalyzedFoodResult.fromMap(Map<String, dynamic> map) {
    final p = (map['protein'] as num?)?.toDouble() ?? 0.0;
    final c = (map['carbs'] as num?)?.toDouble() ?? 0.0;
    final f = (map['fat'] as num?)?.toDouble() ?? 0.0;
    var kcal = (map['calories'] as num?)?.toInt() ?? 0;
    if (kcal <= 0 && (p > 0 || c > 0 || f > 0)) {
      kcal = (p * 4 + c * 4 + f * 9).round();
    }
    return AnalyzedFoodResult(
      mealName: map['mealName'] as String? ?? 'Analyzed Meal',
      protein: p,
      carbs: c,
      fat: f,
      calories: kcal,
      mealType: MealType.fromString(map['mealType'] as String? ?? 'postWorkout'),
      summary: map['summary'] as String? ?? '',
      detectedItems: (map['detectedItems'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
