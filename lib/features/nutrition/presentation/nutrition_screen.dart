import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../today/presentation/widgets/ai_assistant_sheet.dart';
import '../domain/models/nutrition_model.dart';
import '../data/nutrition_service.dart';

IconData getMealTypeIcon(MealType type) {
  switch (type) {
    case MealType.breakfast:
      return Icons.wb_sunny_outlined;
    case MealType.lunch:
      return Icons.restaurant_outlined;
    case MealType.dinner:
      return Icons.dinner_dining_outlined;
    case MealType.snack:
      return Icons.apple_outlined;
    case MealType.preWorkout:
      return Icons.bolt_rounded;
    case MealType.postWorkout:
      return Icons.fitness_center_rounded;
  }
}

class NutritionScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const NutritionScreen({super.key, this.initialDate});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  late DateTime _selectedDate;
  DailyNutritionLog? _log;
  bool _isLoading = true;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _selectedDate = AppDateUtils.normalizeDate(widget.initialDate ?? DateTime.now());
    _loadLog();
  }

  Future<void> _loadLog() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(nutritionServiceProvider);
      final log = await service.getDailyLog(_selectedDate);
      if (mounted) {
        setState(() {
          _log = log;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _changeDate(DateTime newDate) {
    AppHaptics.tap();
    setState(() {
      _selectedDate = AppDateUtils.normalizeDate(newDate);
    });
    _loadLog();
  }

  Future<void> _pickDate() async {
    AppHaptics.tap();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: C.accent,
              surface: C.surfaceModal,
              onSurface: C.text1,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _changeDate(picked);
    }
  }

  Future<void> _addWater(int deltaMl) async {
    AppHaptics.heavy();
    final service = ref.read(nutritionServiceProvider);
    final updated = await service.addWater(_selectedDate, deltaMl);
    if (mounted) {
      setState(() => _log = updated);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.water_drop_rounded, size: 16, color: Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('+${deltaMl}ml water logged (${updated.waterMl} / ${updated.target.waterMl} ml)'),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF0284C7),
        ),
      );
    }
  }

  Future<void> _quickLogFood(RecommendedFood food) async {
    AppHaptics.save();
    final service = ref.read(nutritionServiceProvider);
    final meal = MealItem(
      id: _uuid.v4(),
      name: food.name,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
      calories: food.calories,
      mealType: MealType.postWorkout,
      loggedAt: DateTime.now(),
    );
    final updated = await service.addMeal(_selectedDate, meal);
    if (mounted) {
      setState(() => _log = updated);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: C.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Logged "${food.name}" (+${food.protein.toStringAsFixed(0)}g protein)'),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 1800),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: C.surfaceModal,
        ),
      );
    }
  }

  Future<void> _quickLogPreset(String name, double p, double c, double f, int kcal, MealType type) async {
    AppHaptics.tap();
    final service = ref.read(nutritionServiceProvider);
    final meal = MealItem(
      id: _uuid.v4(),
      name: name,
      protein: p,
      carbs: c,
      fat: f,
      calories: kcal,
      mealType: type,
      loggedAt: DateTime.now(),
    );
    final updated = await service.addMeal(_selectedDate, meal);
    if (mounted) {
      setState(() => _log = updated);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: C.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Added $name (+${p.toStringAsFixed(0)}g P)'),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: C.surfaceModal,
        ),
      );
    }
  }

  Future<void> _deleteMeal(MealItem meal) async {
    AppHaptics.selection();
    final service = ref.read(nutritionServiceProvider);
    final updated = await service.deleteMeal(_selectedDate, meal.id);
    if (mounted) {
      setState(() => _log = updated);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed ${meal.name}'),
          duration: const Duration(milliseconds: 2000),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            textColor: C.accent,
            onPressed: () async {
              final restored = await service.addMeal(_selectedDate, meal);
              if (mounted) setState(() => _log = restored);
            },
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: C.surfaceModal,
        ),
      );
    }
  }

  void _showAddCustomMealSheet() {
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LogMealSheet(
        onAdd: (meal) async {
          final service = ref.read(nutritionServiceProvider);
          final updated = await service.addMeal(_selectedDate, meal);
          if (mounted) setState(() => _log = updated);
        },
        onOpenAiCoach: (prompt, imagePath) {
          _openAiCoach(prompt: prompt, imagePath: imagePath);
        },
      ),
    );
  }

  void _openAiCoach({String? prompt, String? imagePath}) {
    AppHaptics.tap();
    final target = _log?.target;
    final p = target?.protein.toStringAsFixed(0) ?? '160';
    final c = target?.calories ?? 2400;
    final workout = target?.workoutContextSummary ?? 'today\'s training';
    final defaultPrompt = prompt ??
        "What should I eat right now based on $workout? My daily target is ${p}g protein and $c kcal.";
    AiAssistantSheet.show(
      context,
      initialPrompt: defaultPrompt,
      initialImagePath: imagePath,
    );
  }

  @override
  Widget build(BuildContext context) {
    C.isDark = Theme.of(context).brightness == Brightness.dark;
    final isToday = AppDateUtils.isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: C.bg,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top App Bar
              _buildTopBar(isToday),

              // Main Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _loadLog,
                        color: C.accent,
                        backgroundColor: C.surface,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(S.lg, S.sm, S.lg, 88),
                          children: [
                            // 1. Workout Recovery Stimulus Card
                            _buildWorkoutContextCard(),
                            const SizedBox(height: S.md),

                            // 2. Macro Progress Overview
                            _buildMacroDashboard(),
                            const SizedBox(height: S.md),

                            // 3. Hydration Tracker
                            _buildHydrationCard(),
                            const SizedBox(height: S.lg),

                            // 4. AI Sports Nutrition & Post-Workout Fuel Plan
                            _buildAiNutritionPlanCard(),
                            const SizedBox(height: S.lg),

                            // 5. Quick Add Common Foods
                            _buildQuickAddPills(),
                            const SizedBox(height: S.lg),

                            // 6. Logged Meals Section
                            _buildLoggedMealsList(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustomMealSheet,
        backgroundColor: C.accent,
        foregroundColor: C.onAccent,
        icon: const Icon(Icons.add_a_photo_rounded, size: 20),
        label: const Text(
          'Log Food / Photo',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isToday) {
    final dateStr = isToday
        ? 'Today • ${DateFormat('MMM d').format(_selectedDate)}'
        : DateFormat('EEE, MMM d').format(_selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
      decoration: BoxDecoration(
        color: C.surface.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: C.hairline)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.text1),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Fuel & Nutrition',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: C.text1,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Date Selector
          ScaleTap(
            onPressed: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: C.surfaceHi,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isToday ? C.accent : C.text2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.calendar_month_rounded, size: 14, color: isToday ? C.accent : C.text2),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // AI Coach Button -> opens real AI Coach!
          ScaleTap(
            onPressed: () => _openAiCoach(),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [C.accent, C.accent.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutContextCard() {
    final target = _log?.target;
    if (target == null) return const SizedBox.shrink();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      radius: 20,
      borderColor: C.accent.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: C.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: C.accent),
                    const SizedBox(width: 4),
                    Text(
                      'AI Workout Calibration',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: C.accent,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${target.calories} kcal Target',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: C.text1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            target.workoutContextSummary,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: C.text1,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            target.reasoning,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: C.text2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroDashboard() {
    final log = _log;
    if (log == null) return const SizedBox.shrink();

    final cConsumed = log.consumedCalories;
    final cTarget = log.target.calories;
    final cRemaining = log.caloriesRemaining;
    final cProgress = log.caloriesRatio.clamp(0.0, 1.0);

    return Column(
      children: [
        // Calories Hero Card
        GlassContainer(
          padding: const EdgeInsets.all(16),
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 18, color: Color(0xFFF97316)),
                      const SizedBox(width: 6),
                      Text(
                        'Calories',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: C.text1,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$cRemaining kcal left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: C.text2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$cConsumed',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: C.text1,
                    ),
                  ),
                  Text(
                    ' / $cTarget kcal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: C.text3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: cProgress,
                  minHeight: 8,
                  backgroundColor: C.surfaceHi,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    cProgress >= 1.0 ? const Color(0xFF10B981) : C.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3 Macro Columns (Protein, Carbs, Fat)
        Row(
          children: [
            // Protein (Key emphasis)
            Expanded(
              child: _buildMacroPill(
                title: 'Protein',
                consumed: log.consumedProtein,
                target: log.target.protein,
                unit: 'g',
                color: const Color(0xFF06B6D4), // Cyan
                icon: Icons.fitness_center_rounded,
              ),
            ),
            const SizedBox(width: 8),
            // Carbs
            Expanded(
              child: _buildMacroPill(
                title: 'Carbs',
                consumed: log.consumedCarbs,
                target: log.target.carbs,
                unit: 'g',
                color: const Color(0xFFF59E0B), // Amber
                icon: Icons.grain_rounded,
              ),
            ),
            const SizedBox(width: 8),
            // Fat
            Expanded(
              child: _buildMacroPill(
                title: 'Fats',
                consumed: log.consumedFat,
                target: log.target.fat,
                unit: 'g',
                color: const Color(0xFFA855F7), // Purple
                icon: Icons.opacity_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroPill({
    required String title,
    required double consumed,
    required double target,
    required String unit,
    required Color color,
    required IconData icon,
  }) {
    final progress = target <= 0 ? 0.0 : (consumed / target).clamp(0.0, 1.0);
    final remaining = (target - consumed).clamp(0.0, 9999.0);

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: C.text2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: consumed.toStringAsFixed(0),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: C.text1,
                  ),
                ),
                TextSpan(
                  text: '/${target.toStringAsFixed(0)}$unit',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: C.text3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: C.surfaceHi,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            remaining <= 0 ? 'Goal Met!' : '${remaining.toStringAsFixed(0)}$unit left',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: remaining <= 0 ? const Color(0xFF10B981) : C.text3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationCard() {
    final log = _log;
    if (log == null) return const SizedBox.shrink();

    final water = log.waterMl;
    final target = log.target.waterMl;
    final progress = log.waterRatio.clamp(0.0, 1.0);

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_rounded, size: 16, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              Text(
                'Hydration & Fluids',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: C.text1,
                ),
              ),
              const Spacer(),
              Text(
                '$water / $target ml',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: C.surfaceHi,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildWaterButton('+250 ml', 250),
              const SizedBox(width: 8),
              _buildWaterButton('+500 ml', 500),
              const SizedBox(width: 8),
              _buildWaterButton('+1,000 ml', 1000),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaterButton(String label, int ml) {
    return Expanded(
      child: ScaleTap(
        onPressed: () => _addWater(ml),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF38BDF8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiNutritionPlanCard() {
    final target = _log?.target;
    if (target == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: C.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Recovery Recommendations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: C.text1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ScaleTap(
              onPressed: () => _openAiCoach(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ask Coach',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: C.accent,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: C.accent),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Post Workout Window Tip Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: C.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: C.accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.timer_outlined, size: 18, color: C.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post-Workout Anabolic Protocol',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: C.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      target.postWorkoutTip,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: C.text1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Recommended Meals Horizontal List
        SizedBox(
          height: 165,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: target.recommendedFoods.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final food = target.recommendedFoods[index];
              return _buildFoodCard(food);
            },
          ),
        ),

        const SizedBox(height: 12),
        // Micronutrients & Recovery Support (Safe from overflow on all screen sizes)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: target.micronutrients.map((micro) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.hairline),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.shield_outlined, size: 13, color: const Color(0xFF38BDF8)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      micro,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: C.text2,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFoodCard(RecommendedFood food) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: C.surfaceHi,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  food.category,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: C.accent,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${food.calories} kcal',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: C.text3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            food.name,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: C.text1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            food.portion,
            style: TextStyle(
              fontSize: 11,
              color: C.text3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                '${food.protein.toStringAsFixed(0)}g P • ${food.carbs.toStringAsFixed(0)}g C',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF06B6D4),
                ),
              ),
              const Spacer(),
              ScaleTap(
                onPressed: () => _quickLogFood(food),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: C.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+ Log',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: C.onAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddPills() {
    final presets = [
      ('Whey Protein Shake', 30.0, 3.0, 1.0, 140, MealType.postWorkout),
      ('Grilled Chicken & Rice', 48.0, 56.0, 5.0, 460, MealType.postWorkout),
      ('3 Eggs & Toast', 22.0, 24.0, 15.0, 320, MealType.breakfast),
      ('Greek Yogurt & Berries', 24.0, 18.0, 1.0, 180, MealType.snack),
      ('Protein Energy Bar', 20.0, 24.0, 7.0, 220, MealType.snack),
      ('Salmon & Sweet Potato', 36.0, 38.0, 14.0, 420, MealType.dinner),
      ('Tofu & Quinoa Bowl', 26.0, 38.0, 10.0, 340, MealType.lunch),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 16, color: C.accent),
            const SizedBox(width: 4),
            Text(
              'Quick Log Common Foods',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: C.text1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: presets.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final p = presets[index];
              return ScaleTap(
                onPressed: () => _quickLogPreset(p.$1, p.$2, p.$3, p.$4, p.$5, p.$6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: C.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.hairline),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: C.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+${p.$2.toStringAsFixed(0)}g ${p.$1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: C.text1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedMealsList() {
    final meals = _log?.meals ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Logged Today (${meals.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: C.text1,
              ),
            ),
            if (meals.isNotEmpty)
              ScaleTap(
                onPressed: () async {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: isDark ? const Color(0xFF0F1118) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.09) : Colors.black.withValues(alpha: 0.07),
                          width: 1.2,
                        ),
                      ),
                      titlePadding: EdgeInsets.zero,
                      contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                                ),
                                child: Icon(
                                  Icons.restart_alt_rounded,
                                  color: AppColors.error,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Reset Food Log?',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Clear today\'s logged meals',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Are you sure you want to reset all logged meals for this date? This cannot be undone.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.5,
                              height: 1.45,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        Row(
                          children: [
                            Expanded(
                              child: ScaleTap(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF181B24) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ScaleTap(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Reset All',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final service = ref.read(nutritionServiceProvider);
                    final updated = await service.resetLog(_selectedDate);
                    if (mounted) setState(() => _log = updated);
                  }
                },
                child: Text(
                  'Reset',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: C.text3,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (meals.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: C.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.hairline),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: C.surfaceHi,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.restaurant_outlined, size: 28, color: C.text3),
                ),
                const SizedBox(height: 10),
                Text(
                  'No meals logged yet today',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.text1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap "+ Log Food / Photo" below to snap your meal with AI or use quick presets above.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: C.text2,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: meals.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final meal = meals[index];
              return _buildMealTile(meal);
            },
          ),
      ],
    );
  }

  Widget _buildMealTile(MealItem meal) {
    return Dismissible(
      key: Key(meal.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteMeal(meal),
      background: Container(
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.hairline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: C.surfaceHi,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(getMealTypeIcon(meal.mealType), size: 18, color: C.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: C.text1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${meal.protein.toStringAsFixed(0)}g Protein • ${meal.carbs.toStringAsFixed(0)}g Carbs • ${meal.fat.toStringAsFixed(0)}g Fat',
                    style: TextStyle(
                      fontSize: 11,
                      color: C.text2,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${meal.calories} kcal',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: C.text1,
                  ),
                ),
                Text(
                  DateFormat('h:mm a').format(meal.loggedAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: C.text3,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: C.text3),
              onPressed: () => _deleteMeal(meal),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rebranded, theme-matching Food & Meal logger with AI Camera Vision integration
class _LogMealSheet extends ConsumerStatefulWidget {
  final Future<void> Function(MealItem meal) onAdd;
  final void Function(String? prompt, String? imagePath)? onOpenAiCoach;

  const _LogMealSheet({
    required this.onAdd,
    this.onOpenAiCoach,
  });

  @override
  ConsumerState<_LogMealSheet> createState() => _LogMealSheetState();
}

class _LogMealSheetState extends ConsumerState<_LogMealSheet>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _uuid = const Uuid();

  String? _photoPath;
  bool _isAnalyzing = false;
  AnalyzedFoodResult? _aiResult;
  late final AnimationController _scanController;

  double _protein = 35.0;
  double _carbs = 45.0;
  double _fat = 10.0;
  int? _manualCalories;
  MealType _selectedType = MealType.postWorkout;

  int get _calculatedCalories =>
      _manualCalories ?? (_protein * 4 + _carbs * 4 + _fat * 9).round();

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (_photoPath == null && _nameCtrl.text.trim().isEmpty && _aiResult == null) {
      return true;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1118) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.09) : Colors.black.withValues(alpha: 0.07),
            width: 1.2,
          ),
        ),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discard Meal?',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Unsaved progress will be lost',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to leave? Your meal photo and macro calculations will not be saved.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                height: 1.45,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ScaleTap(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF181B24) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Keep Editing',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ScaleTap(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Discard',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _choosePhotoSource() async {
    AppHaptics.tap();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1117) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: C.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: C.accent.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(Icons.add_a_photo_rounded, color: C.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Meal Photo',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'AI Vision automatically breaks down portions & macros',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ScaleTap(
                  onPressed: () => Navigator.of(ctx).pop(ImageSource.camera),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151822) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: C.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: C.accent.withValues(alpha: 0.25)),
                          ),
                          child: Icon(Icons.photo_camera_rounded, color: C.accent, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Take Live Photo',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Snap a live photo of your meal plate',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ScaleTap(
                  onPressed: () => Navigator.of(ctx).pop(ImageSource.gallery),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151822) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.photo_library_rounded, color: Color(0xFF38BDF8), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose from Gallery',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Select an existing food photo from library',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ScaleTap(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1D27) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (source != null) {
      await _pickPhotoWithSource(source);
    }
  }

  Future<void> _pickPhotoWithSource(ImageSource source) async {
    AppHaptics.tap();
    try {
      final picker = ImagePicker();
      final XFile? res = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (res != null) {
        setState(() {
          _photoPath = res.path;
          _isAnalyzing = true;
          _aiResult = null;
        });
        _scanController.repeat();

        final service = ref.read(nutritionServiceProvider);
        final results = await Future.wait([
          service.analyzeMealPhoto(_photoPath!),
          Future.delayed(const Duration(milliseconds: 2100)),
        ]);
        final result = results[0] as AnalyzedFoodResult;

        if (mounted) {
          _scanController.stop();
          _scanController.reset();
          setState(() {
            _isAnalyzing = false;
            _aiResult = result;
            _nameCtrl.text = result.mealName;
            _protein = result.protein;
            _carbs = result.carbs;
            _fat = result.fat;
            _manualCalories = result.calories;
            _selectedType = result.mealType;
          });
          AppHaptics.save();
        }
      }
    } catch (e) {
      if (mounted) {
        _scanController.stop();
        _scanController.reset();
        setState(() => _isAnalyzing = false);
      }
      debugPrint('Error picking or analyzing photo: $e');
    }
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final finalName = name.isNotEmpty
        ? name
        : (_aiResult != null ? _aiResult!.mealName : 'Logged Meal');

    final item = MealItem(
      id: _uuid.v4(),
      name: finalName,
      protein: _protein,
      carbs: _carbs,
      fat: _fat,
      calories: _calculatedCalories,
      mealType: _selectedType,
      loggedAt: DateTime.now(),
    );

    widget.onAdd(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _photoPath == null && _nameCtrl.text.trim().isEmpty && _aiResult == null,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _confirmLeave();
        if (!context.mounted) return;
        if (shouldLeave) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13151D) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: C.hairline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: C.hairline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: C.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.restaurant_rounded, size: 20, color: C.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log Fuel & Meal',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: C.text1,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'AI Vision portion & macronutrient analysis',
                          style: TextStyle(fontSize: 12, color: C.text3),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: C.text2),
                    onPressed: () async {
                      final shouldLeave = await _confirmLeave();
                      if (!context.mounted) return;
                      if (shouldLeave) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          Divider(height: 1, color: C.hairline),

          // Scrollable Body
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // 1. Camera & Photo Capture Button
                _buildPhotoSection(),
                const SizedBox(height: 16),

                // 2. AI Detected Summary (if analyzed)
                if (_aiResult != null) _buildAiAnalysisResultBadge(),

                // 3. Meal Category Chips
                Text(
                  'MEAL CATEGORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: C.text3,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _buildCategorySelector(),
                const SizedBox(height: 18),

                // 4. Food Name Input
                Text(
                  'FOOD / MEAL NAME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: C.text3,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: C.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.hairline),
                  ),
                  child: TextField(
                    controller: _nameCtrl,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: C.text1,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Grilled Chicken, Jasmine Rice & Greens',
                      hintStyle: TextStyle(color: C.text3, fontSize: 13),
                      prefixIcon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                      prefixIconColor: C.accent,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Live Macro Center & Stepper Controls
                _buildMacroControlsCenter(),
                const SizedBox(height: 24),

                // 6. Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.accent,
                      foregroundColor: C.onAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Save ${_protein.toStringAsFixed(0)}g Protein • $_calculatedCalories kcal',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Ask AI Coach about meal button
                ScaleTap(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onOpenAiCoach?.call(
                      "Review this meal: ${_nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'My food photo'} with ${_protein.toStringAsFixed(0)}g protein, ${_carbs.toStringAsFixed(0)}g carbs, ${_fat.toStringAsFixed(0)}g fat. Does this fit my recovery goals?",
                      _photoPath,
                    );
                  },
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: C.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.hairline),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.smart_toy_outlined, size: 16, color: C.accent),
                        const SizedBox(width: 8),
                        Text(
                          'Ask AI Coach about this Meal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: C.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildPhotoSection() {
    if (_photoPath == null) {
      return ScaleTap(
        onPressed: _choosePhotoSource,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: C.accent.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: C.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.photo_camera_rounded, size: 24, color: C.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Take or Upload Meal Photo',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: C.text1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Snap camera photo or pick image to auto-detect macros',
                      style: TextStyle(
                        fontSize: 12,
                        color: C.text3,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: C.accent),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isAnalyzing
              ? C.accent.withValues(alpha: 0.45)
              : (_aiResult != null ? C.accent.withValues(alpha: 0.4) : C.hairline),
          width: _isAnalyzing ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo with AR HUD overlay
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 230,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Food photo — no shader mask, let overlay do the shimmer
                  AnimatedBuilder(
                    animation: _scanController,
                    builder: (context, child) => child!,
                    child: Image.file(
                      File(_photoPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),

                  // Soft neutral shimmer overlay while AI is analyzing
                  if (_isAnalyzing)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _scanController,
                          builder: (context, _) {
                            final v = _scanController.value;
                            // Sweep a soft-white diagonal band across the image
                            final cx = -1.0 + v * 3.0;
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(cx - 0.7, -0.9),
                                  end: Alignment(cx + 0.7, 0.9),
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.08),
                                    Colors.white.withValues(alpha: 0.16),
                                    Colors.white.withValues(alpha: 0.08),
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.25, 0.42, 0.5, 0.58, 0.75, 1.0],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // Contrast Vignette Gradient
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top-Left: Calorie Hero Tag
                  if (!_isAnalyzing)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: C.accent.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department_rounded, size: 14, color: C.accent),
                            const SizedBox(width: 5),
                            Text(
                              '$_calculatedCalories kcal',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: C.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Top-Right: Delete Photo
                  Positioned(
                    top: 10,
                    right: 10,
                    child: ScaleTap(
                      onPressed: () => setState(() {
                        _photoPath = null;
                        _aiResult = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar inside Photo Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                ScaleTap(
                  onPressed: _choosePhotoSource,
                  child: Row(
                    children: [
                      Icon(Icons.cameraswitch_rounded, size: 15, color: C.accent),
                      const SizedBox(width: 6),
                      Text(
                        'Retake / Switch Photo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: C.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_isAnalyzing)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _scanController,
                        builder: (context, _) {
                          // Gentle pulse opacity instead of neon glow
                          final pulse = (0.4 + 0.6 * _scanController.value).clamp(0.4, 1.0);
                          return Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: C.text3.withValues(alpha: pulse),
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Analysing…',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: C.text3,
                        ),
                      ),
                    ],
                  )
                else if (_aiResult != null)
                  Text(
                    'AI Portions Verified',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAiAnalysisResultBadge() {
    final ai = _aiResult!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF06B6D4)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI Vision Food Breakdown',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF06B6D4),
                  ),
                ),
              ),
              Text(
                'Auto-filled below',
                style: TextStyle(fontSize: 11, color: C.text3),
              ),
            ],
          ),
          if (ai.detectedItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ai.detectedItems.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: C.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(fontSize: 11, color: C.text1, fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
          ],
          if (ai.summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              ai.summary,
              style: TextStyle(fontSize: 11.5, color: C.text2, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MealType.values.map((type) {
        final isSelected = type == _selectedType;
        return ScaleTap(
          onPressed: () => setState(() => _selectedType = type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? C.accent.withValues(alpha: 0.18) : C.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? C.accent : C.hairline,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  getMealTypeIcon(type),
                  size: 14,
                  color: isSelected ? C.accent : C.text2,
                ),
                const SizedBox(width: 6),
                Text(
                  type.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? C.accent : C.text2,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMacroControlsCenter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NUTRITIONAL MACROS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: C.text3,
                  letterSpacing: 0.5,
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$_calculatedCalories ',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: C.text1,
                      ),
                    ),
                    TextSpan(
                      text: 'kcal',
                      style: TextStyle(
                        fontSize: 11,
                        color: C.text3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Columns: Protein, Carbs, Fat
          Row(
            children: [
              Expanded(
                child: _buildMacroControlBox(
                  title: 'Protein',
                  value: _protein,
                  color: const Color(0xFF06B6D4),
                  icon: Icons.fitness_center_rounded,
                  onChanged: (v) => setState(() {
                    _protein = v.clamp(0, 500);
                    _manualCalories = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroControlBox(
                  title: 'Carbs',
                  value: _carbs,
                  color: const Color(0xFFF59E0B),
                  icon: Icons.grain_rounded,
                  onChanged: (v) => setState(() {
                    _carbs = v.clamp(0, 700);
                    _manualCalories = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroControlBox(
                  title: 'Fat',
                  value: _fat,
                  color: const Color(0xFFA855F7),
                  icon: Icons.opacity_rounded,
                  onChanged: (v) => setState(() {
                    _fat = v.clamp(0, 300);
                    _manualCalories = null;
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroControlBox({
    required String title,
    required double value,
    required Color color,
    required IconData icon,
    required Function(double) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: C.surfaceHi,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${value.toStringAsFixed(0)}g',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: C.text1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ScaleTap(
                onPressed: () => onChanged(value - 5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: C.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: C.hairline),
                  ),
                  child: Text(
                    '-5',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.text2),
                  ),
                ),
              ),
              ScaleTap(
                onPressed: () => onChanged(value + 5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '+5',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
