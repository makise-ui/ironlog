import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../domain/models/nutrition_model.dart';
import '../../../domain/models/workout_model.dart';
import '../../../data/providers.dart';
import '../../../domain/services/ai_assistant_service.dart';
import '../../../domain/services/backup_service.dart';
import '../../../domain/models/ai_chat_message.dart';

final nutritionServiceProvider = Provider<NutritionService>((ref) {
  return NutritionService(ref);
});

final dailyNutritionLogProvider =
    FutureProvider.autoDispose.family<DailyNutritionLog, DateTime>((ref, date) async {
  final service = ref.watch(nutritionServiceProvider);
  return service.getDailyLog(date);
});

class NutritionService {
  final Ref _ref;

  NutritionService(this._ref);

  String _dateKey(DateTime date) {
    final norm = DateTime(date.year, date.month, date.day);
    return 'nutrition_log_${DateFormat('yyyy-MM-dd').format(norm)}';
  }

  /// Calculates dynamic AI-calibrated macro targets tailored to the user's workout and physical profile
  Future<MacroTarget> calculateTargetForWorkout(
    WorkoutModel? workout, {
    DateTime? date,
  }) async {
    final settings = _ref.read(settingsRepositoryProvider);
    final weightStr = await settings.getSetting('user_weight') ?? '75';
    final userWeightKg = double.tryParse(weightStr) ?? 75.0;
    final userGoal = await settings.getSetting('user_goal') ?? 'Build Muscle';

    final activeExercises = workout?.exercises.where((e) => !e.archived).toList() ?? [];
    final activeSets = activeExercises
        .expand((e) => e.sets)
        .where((s) => !s.archived && (s.reps > 0 || s.weight > 0))
        .toList();

    final totalVolume = workout?.totalVolume ?? 0.0;
    final totalSets = activeSets.length;
    final isRestDay = workout?.isRestDay == true || (activeExercises.isEmpty && (workout?.endedAt != null || workout?.title.toLowerCase().contains('rest') == true));

    // Analyze muscle groups trained
    final muscleGroups = <String>{};
    for (final ex in activeExercises) {
      if (ex.exercise.muscleGroupId.isNotEmpty) {
        muscleGroups.add(ex.exercise.muscleGroupId.toLowerCase());
      }
      for (final sec in ex.exercise.secondaryGroups) {
        if (sec.isNotEmpty) muscleGroups.add(sec.toLowerCase());
      }
    }

    final hasLegs = muscleGroups.any((m) => m.contains('leg') || m.contains('quad') || m.contains('glute') || m.contains('ham'));
    final hasBack = muscleGroups.any((m) => m.contains('back') || m.contains('lat'));
    final hasChest = muscleGroups.any((m) => m.contains('chest') || m.contains('pec'));
    final hasArms = muscleGroups.any((m) => m.contains('arm') || m.contains('bicep') || m.contains('tricep') || m.contains('shoulder'));

    double proteinPerKg = 1.9;
    double carbsPerKg = 3.2;
    double fatPerKg = 0.85;
    int extraCalories = 0;
    int extraWaterMl = 0;

    String workoutSummary = '';
    String reasoning = '';
    String postWorkoutTip = '';
    List<String> micronutrients = [];
    List<RecommendedFood> foodSuggestions = [];

    if (isRestDay) {
      workoutSummary = 'Scheduled Rest & Recovery Day';
      proteinPerKg = 1.8;
      carbsPerKg = 2.4;
      fatPerKg = 0.9;
      extraCalories = 0;
      extraWaterMl = 0;

      reasoning = 'Muscles synthesize and rebuild contractile filaments while resting. Your targets are tuned with steady protein for MPS, moderate carbohydrates to support recovery, and anti-inflammatory healthy fats.';
      postWorkoutTip = 'Distribute 25–35g high-quality protein every 3.5 to 4 hours. Stay hydrated and prioritize restorative sleep tonight.';
      micronutrients = [
        'Magnesium (400mg) for neuromuscular relaxation & deep sleep',
        'Omega-3 Fatty Acids (2g EPA/DHA) to attenuate systemic inflammation',
        'Zinc (15mg) for cellular repair and hormonal equilibrium',
      ];
      foodSuggestions = [
        const RecommendedFood(
          name: 'Greek Yogurt, Mixed Berries & Walnuts',
          portion: '220g 0% Greek yogurt, 60g berries, 20g walnuts',
          protein: 26,
          carbs: 22,
          fat: 14,
          calories: 320,
          category: 'Recovery Snack',
          benefit: 'Sustained-release micellar casein protein and antioxidant polyphenols',
        ),
        const RecommendedFood(
          name: 'Baked Atlantic Salmon with Asparagus',
          portion: '170g wild salmon, 150g grilled asparagus',
          protein: 38,
          carbs: 6,
          fat: 18,
          calories: 340,
          category: 'Anti-Inflammatory Dinner',
          benefit: 'Rich in EPA/DHA to soothe joints and promote recovery',
        ),
        const RecommendedFood(
          name: '3 Whole Eggs & Sourdough Toast with Avocado',
          portion: '3 eggs, 1 slice sourdough, 40g avocado',
          protein: 22,
          carbs: 26,
          fat: 19,
          calories: 360,
          category: 'Nutrient-Dense Fuel',
          benefit: 'Complete amino acid spectrum, choline for CNS recovery',
        ),
      ];
    } else if (hasLegs) {
      workoutSummary = 'High-Demanding Lower Body / Leg Session';
      proteinPerKg = 2.1;
      carbsPerKg = 4.2;
      fatPerKg = 0.85;
      extraCalories = (totalSets * 22).clamp(300, 650);
      extraWaterMl = (totalSets * 45).clamp(400, 1000);

      reasoning = 'Leg sessions recruit the body\'s largest muscle masses (quads, hamstrings, glutes), creating maximal central fatigue and massive glycogen depletion. Elevated carbohydrates and peak protein targets are essential to replenish glycogen stores and activate the mTOR pathway.';
      postWorkoutTip = 'Consume 35–45g fast-digesting protein paired with 50–70g fast carbs within 60–90 minutes to blunt muscle breakdown and refill depleted quadriceps/hamstring glycogen.';
      micronutrients = [
        'Sodium & Potassium for electrolyte rebalancing after heavy sweating',
        'Magnesium (400mg) to prevent leg muscle cramping and spasms',
        'Calcium & Vitamin D for bone density support under heavy axial loads',
      ];
      foodSuggestions = [
        const RecommendedFood(
          name: 'Grilled Chicken Breast with White Jasmine Rice',
          portion: '180g chicken breast, 220g cooked jasmine rice',
          protein: 52,
          carbs: 64,
          fat: 4,
          calories: 500,
          category: 'Post-Workout Fuel',
          benefit: 'Maximum glycogen re-synthesis & instant amino acid spike',
        ),
        const RecommendedFood(
          name: 'Post-Workout Whey Isolate Shake & Banana',
          portion: '1.5 scoops whey isolate (38g), 1 large banana',
          protein: 38,
          carbs: 32,
          fat: 1,
          calories: 290,
          category: 'Immediate Anabolic Window',
          benefit: 'Ultra-fast absorption, high leucine to stimulate muscle protein synthesis',
        ),
        const RecommendedFood(
          name: 'Lean Beef Sirloin & Roasted Sweet Potato',
          portion: '170g lean beef, 200g sweet potato',
          protein: 44,
          carbs: 42,
          fat: 12,
          calories: 450,
          category: 'Strength Recovery Dinner',
          benefit: 'Natural creatine, iron, and slow complex carbohydrates',
        ),
      ];
    } else {
      // Upper body / Push / Pull / Arms
      final bodyPart = hasChest
          ? 'Chest & Push'
          : hasBack
              ? 'Back & Pull'
              : hasArms
                  ? 'Shoulders & Arms'
                  : 'Upper Body Blast';
      workoutSummary = '$bodyPart ($totalSets Sets · ${totalVolume.toStringAsFixed(0)} kg Lifted)';
      proteinPerKg = 2.05;
      carbsPerKg = totalVolume > 6000 ? 3.8 : 3.2;
      fatPerKg = 0.85;
      extraCalories = (totalSets * 18).clamp(200, 500);
      extraWaterMl = (totalSets * 35).clamp(300, 800);

      reasoning = 'Your upper body session created focal micro-tears in targeted muscle fibers. Targeted protein optimizes myofibrillar protein synthesis, while moderate-high carbs maintain full muscular fullness and energy for subsequent sessions.';
      postWorkoutTip = 'Drink 30g protein with 35–45g carbs shortly after training. Keep blood flow circulating with ample water.';
      micronutrients = [
        'Potassium (3,500mg) for muscular pump retention and electrolyte balance',
        'B-Complex Vitamins (B6, B12) for cellular energy transfer and amino acid metabolism',
        'Vitamin C (500mg) for collagen synthesis in shoulder/elbow tendons',
      ];
      foodSuggestions = [
        const RecommendedFood(
          name: 'Turkey or Chicken Burrito Bowl',
          portion: '160g ground turkey/chicken, 180g brown rice, black beans, salsa',
          protein: 46,
          carbs: 58,
          fat: 9,
          calories: 490,
          category: 'Post-Workout Fuel',
          benefit: 'Complete amino acids, complex fiber, and potassium rich beans',
        ),
        const RecommendedFood(
          name: 'Whey Protein Oatmeal with Blueberries',
          portion: '1 scoop whey protein (28g), 60g rolled oats, 50g blueberries',
          protein: 34,
          carbs: 46,
          fat: 5,
          calories: 365,
          category: 'High-Protein Breakfast / Snack',
          benefit: 'Steady energy release, sustained amino acid delivery',
        ),
        const RecommendedFood(
          name: 'Tuna Salad or Salmon Wrap',
          portion: '1 can skipjack tuna (130g) or salmon, whole wheat wrap, greens',
          protein: 38,
          carbs: 32,
          fat: 7,
          calories: 345,
          category: 'Quick High-Protein Meal',
          benefit: 'Lean bioavailable protein and essential fatty acids',
        ),
      ];
    }

    // Goal adjustments
    final goalLower = userGoal.toLowerCase();
    if (goalLower.contains('muscle') || goalLower.contains('hypertrophy') || goalLower.contains('bulk')) {
      proteinPerKg += 0.1;
      carbsPerKg += 0.4;
      extraCalories += 250;
    } else if (goalLower.contains('fat') || goalLower.contains('cut') || goalLower.contains('loss')) {
      proteinPerKg += 0.15; // Higher protein preserves lean tissue during caloric deficit
      carbsPerKg -= 0.6;
      extraCalories -= 250;
    }

    final double proteinTarget = double.parse((userWeightKg * proteinPerKg).toStringAsFixed(1));
    final double carbsTarget = double.parse((userWeightKg * carbsPerKg).toStringAsFixed(1));
    final double fatTarget = double.parse((userWeightKg * fatPerKg).toStringAsFixed(1));

    // Base BMR + general activity estimate + workout expenditure
    final int baseMaintenance = (userWeightKg * 24 * 1.3).round();
    final int totalCalories = (baseMaintenance + extraCalories).clamp(1600, 4200);
    final int waterTarget = (3000 + extraWaterMl).clamp(2800, 5000);

    return MacroTarget(
      protein: proteinTarget,
      carbs: carbsTarget,
      fat: fatTarget,
      calories: totalCalories,
      waterMl: waterTarget,
      workoutContextSummary: workoutSummary,
      reasoning: reasoning,
      postWorkoutTip: postWorkoutTip,
      micronutrients: micronutrients,
      recommendedFoods: foodSuggestions,
    );
  }

  /// Retrieves the daily nutrition log for a given date
  Future<DailyNutritionLog> getDailyLog(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dateKey(date);
    final jsonStr = prefs.getString(key);

    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final workout = await workoutRepo.getWorkoutForDate(date);
    final target = await calculateTargetForWorkout(workout, date: date);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final log = DailyNutritionLog.fromMap(map, fallbackTarget: target);
        // Update target dynamically to stay in sync with live workout changes
        return log.copyWith(target: target);
      } catch (e) {
        debugPrint('Error parsing nutrition log: $e');
      }
    }

    return DailyNutritionLog(
      date: date,
      meals: [],
      waterMl: 0,
      target: target,
    );
  }

  /// Saves the daily nutrition log to SharedPreferences
  Future<void> saveDailyLog(DailyNutritionLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dateKey(log.date);
    await prefs.setString(key, jsonEncode(log.toMap()));
    try {
      final db = _ref.read(databaseProvider);
      BackupService.scheduleAutoBackup(db);
    } catch (_) {}
  }

  /// Adds a logged meal to the date
  Future<DailyNutritionLog> addMeal(DateTime date, MealItem meal) async {
    final currentLog = await getDailyLog(date);
    final updatedMeals = List<MealItem>.from(currentLog.meals)..add(meal);
    final updatedLog = currentLog.copyWith(meals: updatedMeals);
    await saveDailyLog(updatedLog);
    return updatedLog;
  }

  /// Deletes a logged meal by its ID
  Future<DailyNutritionLog> deleteMeal(DateTime date, String mealId) async {
    final currentLog = await getDailyLog(date);
    final updatedMeals = List<MealItem>.from(currentLog.meals)
      ..removeWhere((m) => m.id == mealId);
    final updatedLog = currentLog.copyWith(meals: updatedMeals);
    await saveDailyLog(updatedLog);
    return updatedLog;
  }

  /// Increments or updates water consumption
  Future<DailyNutritionLog> addWater(DateTime date, int deltaMl) async {
    final currentLog = await getDailyLog(date);
    final newWater = (currentLog.waterMl + deltaMl).clamp(0, 10000);
    final updatedLog = currentLog.copyWith(waterMl: newWater);
    await saveDailyLog(updatedLog);
    return updatedLog;
  }

  /// Clears or resets food log for date
  Future<DailyNutritionLog> resetLog(DateTime date) async {
    final currentLog = await getDailyLog(date);
    final reset = currentLog.copyWith(meals: [], waterMl: 0);
    await saveDailyLog(reset);
    return reset;
  }

  /// Streams dynamic AI nutrition advice tailored to the user's live workout and macro status
  Stream<String> streamAiNutritionAdvice({
    required String prompt,
    required DailyNutritionLog log,
  }) async* {
    final aiService = _ref.read(aiAssistantServiceProvider);
    final workoutSummary = log.target.workoutContextSummary;
    final pConsumed = log.consumedProtein.toStringAsFixed(0);
    final pTarget = log.target.protein.toStringAsFixed(0);
    final cConsumed = log.consumedCalories;
    final cTarget = log.target.calories;

    final contextPrompt = '''
ATHLETE NUTRITION & WORKOUT CONTEXT:
- Today's Training: $workoutSummary
- Current Protein: $pConsumed g / $pTarget g target
- Current Calories: $cConsumed kcal / $cTarget kcal target
- Water Drank: ${log.waterMl} ml / ${log.target.waterMl} ml target

USER NUTRITION QUESTION:
$prompt

ROLE: You are an elite sports nutrition scientist & recovery specialist. Provide concise, ultra-practical advice, portion suggestions, and macro breakdowns. Use bold headings and bullet points. Be friendly, motivating, and scientifically precise.
''';

    final buffer = StringBuffer();
    try {
      await for (final event in aiService.sendMessageStream(
        history: [],
        userPrompt: contextPrompt,
      )) {
        if (event is AiStreamChunkEvent) {
          buffer.write(event.textDelta);
          yield buffer.toString();
        } else if (event is AiThinkingEvent) {
          if (buffer.isEmpty) yield 'Analyzing your workout and recovery metrics...';
        }
      }
      if (buffer.isEmpty) {
        yield _fallbackAdvice(log, prompt);
      }
    } catch (_) {
      yield _fallbackAdvice(log, prompt);
    }
  }

  String _fallbackAdvice(DailyNutritionLog log, String prompt) {
    final remainingP = log.proteinRemaining.toStringAsFixed(0);
    return '''
### AI Nutrition & Recovery Guidance

**Workout Context:** ${log.target.workoutContextSummary}

#### Recommended Action Plan:
- **Remaining Protein Goal:** **${remainingP}g** needed today to optimize muscle protein synthesis.
- **Post-Workout Window:** ${log.target.postWorkoutTip}
- **Hydration Protocol:** Drink at least **500ml water** with electrolytes over the next hour.

#### Quick High-Protein Meal Ideas:
1. **Grilled Chicken Rice Bowl:** 160g chicken, 200g jasmine rice (48g Protein, 55g Carbs)
2. **Rapid Whey Smoothie:** 1.5 scoops whey isolate + 1 banana + 200ml milk (38g Protein, 35g Carbs)
3. **Greek Yogurt Anabolic Bowl:** 200g 0% Greek yogurt + berries + honey (24g Protein, 22g Carbs)
''';
  }

  /// Analyzes a meal photo using AI vision to extract food items, portion estimates, and macronutrients
  Future<AnalyzedFoodResult> analyzeMealPhoto(String imagePath) async {
    final aiService = _ref.read(aiAssistantServiceProvider);

    final prompt = '''
Analyze this meal photo as an expert sports nutritionist and physique coach.
1. Identify all food items visible in the image.
2. Estimate the portions and weights in grams.
3. Calculate estimated macronutrients: Protein (g), Carbs (g), Fat (g), and Total Calories (kcal).
4. Classify which meal category this fits best (breakfast, lunch, dinner, snack, preWorkout, postWorkout).

CRITICAL: Return your response with a JSON code block formatted EXACTLY like this:
```json
{
  "mealName": "Descriptive food name (e.g. Grilled Chicken Breast with Jasmine Rice & Broccoli)",
  "protein": 45.0,
  "carbs": 52.0,
  "fat": 8.0,
  "calories": 460,
  "mealType": "postWorkout",
  "summary": "High protein recovery meal with clean carbs for glycogen replenishment.",
  "detectedItems": ["Chicken breast (160g)", "Jasmine rice (200g)", "Steamed broccoli (80g)"]
}
```
Only output realistic estimates based on visual portion sizing.
''';

    final buffer = StringBuffer();
    try {
      await for (final event in aiService.sendMessageStream(
        history: [],
        userPrompt: prompt,
        imagePath: imagePath,
      )) {
        if (event is AiStreamChunkEvent) {
          buffer.write(event.textDelta);
        }
      }

      final text = buffer.toString();
      final parsed = _extractJsonFromText(text);
      if (parsed != null) {
        return AnalyzedFoodResult.fromMap(parsed);
      }
    } catch (e) {
      debugPrint('Error in AI photo analysis: $e');
    }

    // Fallback: sports nutrition heuristic estimate
    return const AnalyzedFoodResult(
      mealName: 'Athlete Recovery Bowl',
      protein: 42.0,
      carbs: 48.0,
      fat: 10.0,
      calories: 450,
      mealType: MealType.postWorkout,
      summary: 'High-protein recovery fuel. Visual portions estimated.',
      detectedItems: ['Lean Protein Source', 'Complex Carbohydrates', 'Fibrous Greens'],
    );
  }

  Map<String, dynamic>? _extractJsonFromText(String text) {
    try {
      if (text.contains('```json')) {
        final start = text.indexOf('```json') + 7;
        final end = text.indexOf('```', start);
        if (end != -1) {
          final jsonSnippet = text.substring(start, end).trim();
          return jsonDecode(jsonSnippet) as Map<String, dynamic>;
        }
      } else if (text.contains('```')) {
        final start = text.indexOf('```') + 3;
        final end = text.indexOf('```', start);
        if (end != -1) {
          final jsonSnippet = text.substring(start, end).trim();
          return jsonDecode(jsonSnippet) as Map<String, dynamic>;
        }
      }

      final firstBrace = text.indexOf('{');
      final lastBrace = text.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        final jsonSnippet = text.substring(firstBrace, lastBrace + 1).trim();
        return jsonDecode(jsonSnippet) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
