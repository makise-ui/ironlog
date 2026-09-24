import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/features/nutrition/domain/models/nutrition_model.dart';

void main() {
  group('Nutrition Models & Calculations', () {
    test('DailyNutritionLog calculates consumed macros and progress correctly', () {
      const target = MacroTarget(
        protein: 160.0,
        carbs: 240.0,
        fat: 60.0,
        calories: 2200,
        waterMl: 3200,
        workoutContextSummary: 'Chest & Triceps Day',
        reasoning: 'Calibrated for upper body hypertrophy',
        postWorkoutTip: '30g protein + 40g carbs within 90 mins',
        micronutrients: ['Magnesium', 'Potassium'],
        recommendedFoods: [],
      );

      final meal1 = MealItem(
        id: '1',
        name: 'Whey Protein Shake',
        protein: 30.0,
        carbs: 4.0,
        fat: 1.0,
        calories: 145,
        mealType: MealType.postWorkout,
        loggedAt: DateTime.now(),
      );

      final meal2 = MealItem(
        id: '2',
        name: 'Chicken and Rice',
        protein: 50.0,
        carbs: 60.0,
        fat: 6.0,
        calories: 494,
        mealType: MealType.lunch,
        loggedAt: DateTime.now(),
      );

      final log = DailyNutritionLog(
        date: DateTime.now(),
        meals: [meal1, meal2],
        waterMl: 1500,
        target: target,
      );

      expect(log.consumedProtein, 80.0);
      expect(log.consumedCarbs, 64.0);
      expect(log.consumedFat, 7.0);
      expect(log.consumedCalories, 639);

      expect(log.proteinRemaining, 80.0);
      expect(log.caloriesRemaining, 1561);
      expect(log.waterRemaining, 1700);

      expect(log.proteinRatio, closeTo(0.5, 0.01));
      expect(log.waterRatio, closeTo(1500 / 3200, 0.01));
    });

    test('Serialization toMap and fromMap works smoothly', () {
      final meal = MealItem(
        id: 'meal_123',
        name: 'Greek Yogurt Bowl',
        protein: 24.0,
        carbs: 18.0,
        fat: 2.0,
        calories: 190,
        mealType: MealType.snack,
        loggedAt: DateTime(2026, 9, 24, 10, 30),
      );

      final map = meal.toMap();
      final parsed = MealItem.fromMap(map);

      expect(parsed.id, 'meal_123');
      expect(parsed.name, 'Greek Yogurt Bowl');
      expect(parsed.protein, 24.0);
      expect(parsed.calories, 190);
      expect(parsed.mealType, MealType.snack);
    });

    test('RecommendedFood toMap and fromMap round trip', () {
      const food = RecommendedFood(
        name: 'Salmon & Sweet Potato',
        portion: '160g salmon, 200g potato',
        protein: 36,
        carbs: 40,
        fat: 14,
        calories: 430,
        category: 'Post-Workout',
        benefit: 'Omega-3 fatty acids for joint & tissue recovery',
      );

      final map = food.toMap();
      final parsed = RecommendedFood.fromMap(map);

      expect(parsed.name, 'Salmon & Sweet Potato');
      expect(parsed.protein, 36);
      expect(parsed.benefit, contains('Omega-3'));
    });
  });
}
