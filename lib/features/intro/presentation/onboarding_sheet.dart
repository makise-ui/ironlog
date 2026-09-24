import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../data/providers.dart';

class OnboardingSheet extends ConsumerStatefulWidget {
  const OnboardingSheet({super.key});

  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final userName = await settingsRepo.getSetting('user_name');
    final onboarded = await settingsRepo.getSetting('user_onboarded');
    if ((onboarded != 'true' || userName == null || userName.trim().isEmpty) && context.mounted) {
      await showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const OnboardingSheet(),
      );
    }
  }

  @override
  ConsumerState<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends ConsumerState<OnboardingSheet> {
  final TextEditingController _nameCtrl = TextEditingController(text: '');
  final TextEditingController _ageCtrl = TextEditingController(text: '25');
  final TextEditingController _weightCtrl = TextEditingController(text: '75');
  final TextEditingController _heightCtrl = TextEditingController(text: '178');

  WeightUnit _unit = WeightUnit.kg;
  String _gender = 'Male';
  String _goal = 'Build Muscle';
  String _level = 'Intermediate';

  final List<String> _genders = const ['Male', 'Female', 'Other'];
  final List<String> _goals = const [
    'Build Muscle',
    'Increase Strength',
    'Fat Loss & Tone',
    'General Fitness',
  ];
  final List<String> _levels = const [
    'Beginner (< 1 yr)',
    'Intermediate (1-3 yrs)',
    'Advanced (3+ yrs)',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final settings = ref.read(settingsRepositoryProvider);
    final name = await settings.getSetting('user_name');
    final age = await settings.getSetting('user_age');
    final weight = await settings.getSetting('user_weight');
    final height = await settings.getSetting('user_height');
    final gender = await settings.getSetting('user_gender');
    final goal = await settings.getSetting('user_goal');
    final level = await settings.getSetting('user_level');
    final unit = await settings.getWeightUnit();

    if (mounted) {
      setState(() {
        if (name != null && name.isNotEmpty) _nameCtrl.text = name;
        if (age != null && age.isNotEmpty) _ageCtrl.text = age;
        if (weight != null && weight.isNotEmpty) _weightCtrl.text = weight;
        if (height != null && height.isNotEmpty) _heightCtrl.text = height;
        if (gender != null && _genders.contains(gender)) _gender = gender;
        if (goal != null && _goals.contains(goal)) _goal = goal;
        if (level != null && _levels.contains(level)) _level = level;
        _unit = unit;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    AppHaptics.save();
    final settingsRepo = ref.read(settingsRepositoryProvider);

    final name = _nameCtrl.text.trim().isEmpty ? 'Athlete' : _nameCtrl.text.trim();
    await settingsRepo.setSetting('user_name', name);
    await settingsRepo.setSetting('user_onboarded', 'true');
    await settingsRepo.setSetting('user_age', _ageCtrl.text.trim().isEmpty ? '25' : _ageCtrl.text.trim());
    await settingsRepo.setSetting('user_weight', _weightCtrl.text.trim().isEmpty ? '75' : _weightCtrl.text.trim());
    await settingsRepo.setSetting('user_height', _heightCtrl.text.trim().isEmpty ? '178' : _heightCtrl.text.trim());
    await settingsRepo.setSetting('user_gender', _gender);
    await settingsRepo.setSetting('user_goal', _goal);
    await settingsRepo.setSetting('user_level', _level);
    await settingsRepo.setWeightUnit(_unit);

    final currentUnit = ref.read(weightUnitNotifierProvider);
    if (currentUnit != _unit) {
      ref.read(weightUnitNotifierProvider.notifier).toggle();
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: context.sheetBorder, width: 1.0)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.handleBar,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Text(
              'Welcome to IronLog',
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyDisplay,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Set up your personal training profile to customize weight recommendations & target volume.',
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Name Input
            _buildSectionLabel('YOUR NAME / ATHLETE NAME'),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _nameCtrl,
              suffixText: '',
              keyboardType: TextInputType.name,
              hintText: 'e.g. Alex, Kurisu, Jordan...',
              isNumeric: false,
            ),
            const SizedBox(height: 20),

            // Gender Selector
            _buildSectionLabel('GENDER'),
            const SizedBox(height: 8),
            Row(
              children: _genders.map((g) {
                final isSelected = _gender == g;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        AppHaptics.step();
                        setState(() => _gender = g);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? context.accent : (isDark ? const Color(0xFF2F2F2F) : const Color(0xFFF0F0F1)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? context.accent : (isDark ? const Color(0xFF424242) : const Color(0xFFE5E5E5)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            g,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? (isDark ? const Color(0xFF171717) : Colors.white)
                                  : context.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Age & Body Weight Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Age Input
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('AGE'),
                      const SizedBox(height: 8),
                      _buildInputField(
                        controller: _ageCtrl,
                        suffixText: 'yrs',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Weight Input
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionLabel('WEIGHT'),
                          GestureDetector(
                            onTap: () {
                              AppHaptics.step();
                              setState(() {
                                if (_unit == WeightUnit.kg) {
                                  _unit = WeightUnit.lb;
                                  final kg = double.tryParse(_weightCtrl.text) ?? 75.0;
                                  _weightCtrl.text = (kg * 2.20462).round().toString();
                                } else {
                                  _unit = WeightUnit.kg;
                                  final lb = double.tryParse(_weightCtrl.text) ?? 165.0;
                                  _weightCtrl.text = (lb / 2.20462).round().toString();
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E5E5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _unit.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInputField(
                        controller: _weightCtrl,
                        suffixText: _unit.name,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Height Input
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('HEIGHT'),
                      const SizedBox(height: 8),
                      _buildInputField(
                        controller: _heightCtrl,
                        suffixText: 'cm',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Primary Goal Selector
            _buildSectionLabel('PRIMARY FITNESS GOAL'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _goals.map((goal) {
                final isSelected = _goal == goal;
                return GestureDetector(
                  onTap: () {
                    AppHaptics.step();
                    setState(() => _goal = goal);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? context.accent : (isDark ? const Color(0xFF2F2F2F) : const Color(0xFFF0F0F1)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? context.accent : (isDark ? const Color(0xFF424242) : const Color(0xFFE5E5E5)),
                      ),
                    ),
                    child: Text(
                      goal,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? (isDark ? const Color(0xFF171717) : Colors.white)
                            : context.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Experience Level
            _buildSectionLabel('TRAINING EXPERIENCE'),
            const SizedBox(height: 8),
            Column(
              children: _levels.map((lvl) {
                final isSelected = _level == lvl;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: () {
                      AppHaptics.step();
                      setState(() => _level = lvl);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? context.accent : (isDark ? const Color(0xFF2F2F2F) : const Color(0xFFF0F0F1)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? context.accent : (isDark ? const Color(0xFF424242) : const Color(0xFFE5E5E5)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              lvl,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? (isDark ? const Color(0xFF171717) : Colors.white)
                                    : context.textPrimary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: isDark ? const Color(0xFF171717) : Colors.white,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Get Started Button
            GlassButton(
              text: 'Save Profile & Get Started',
              icon: Icons.arrow_forward_rounded,
              height: 52,
              onPressed: _completeOnboarding,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: context.textTertiary,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String suffixText,
    required TextInputType keyboardType,
    String? hintText,
    bool isNumeric = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262626) : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF424242) : const Color(0xFFE5E5E5),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: isNumeric ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))] : null,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: context.textPrimary,
          fontFeatures: isNumeric ? const [FontFeature.tabularFigures()] : null,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 13, color: context.textTertiary, fontWeight: FontWeight.normal),
          suffixText: suffixText,
          suffixStyle: TextStyle(
            fontSize: 12,
            color: context.textSecondary,
          ),
        ),
      ),
    );
  }
}
