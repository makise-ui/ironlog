import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../../domain/models/exercise_model.dart';
import 'exercise_3d_viewer.dart';
import 'exercise_web_search_sheet.dart';

class ExerciseGuideSheet extends StatelessWidget {
  final ExerciseModel exercise;
  final VoidCallback onConfirm;

  const ExerciseGuideSheet({
    super.key,
    required this.exercise,
    required this.onConfirm,
  });

  static void show(BuildContext context, ExerciseModel exercise, VoidCallback onConfirm) {
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExerciseGuideSheet(
        exercise: exercise,
        onConfirm: onConfirm,
      ),
    );
  }

  Map<String, String> _getDetailedEquipmentInfo(ExerciseModel ex) {
    final name = ex.name.toLowerCase();
    final eq = ex.equipment.name.toLowerCase();

    if (eq == 'barbell') {
      if (name.contains('bench')) {
        return {
          'equipment': 'Olympic Barbell & Flat Weight Bench',
          'setup': 'Standard bar weighs 20 kg (45 lbs). Ensure collar clips are locked on both ends.',
          'grip': 'Overhand (Pronated) grip, thumbs wrapped, hands spaced just outside shoulder width.',
        };
      } else if (name.contains('squat')) {
        return {
          'equipment': 'Power Rack & Olympic Barbell (20kg)',
          'setup': 'Set J-hooks at mid-chest height. Set safety spotter bars just below your deepest squat depth.',
          'grip': 'Firm overhand grip pulling bar down onto upper traps with elbows angled slightly back.',
        };
      } else if (name.contains('deadlift')) {
        return {
          'equipment': 'Olympic Barbell & Rubber Bumper Plates',
          'setup': 'Placed on flat lifting platform. Use 450mm diameter Olympic plates for proper floor height.',
          'grip': 'Double overhand or mixed grip, arms hanging vertically just outside your knees.',
        };
      } else if (name.contains('overhead') || name.contains('military')) {
        return {
          'equipment': 'Olympic Barbell & Squat / Press Rack',
          'setup': 'Rack bar at collarbone height. Step under bar, brace core, and un-rack smoothly.',
          'grip': 'Grip just outside shoulders with wrists stacked directly over forearms.',
        };
      } else {
        return {
          'equipment': 'Olympic Barbell (20kg) / EZ-Curl Bar',
          'setup': 'Load matching plates on both sleeves and clamp spring collars firmly.',
          'grip': 'Overhand or underhand grip with straight, neutral wrists to avoid joint strain.',
        };
      }
    } else if (eq == 'dumbbell') {
      return {
        'equipment': 'Matching Pair of Hex/Rubber Dumbbells',
        'setup': 'Use flat or adjustable incline bench. If incline, lock the backrest angle pin securely.',
        'grip': 'Center your palms directly over the knurled metal handle for balanced wrist stability.',
      };
    } else if (eq == 'cable') {
      return {
        'equipment': 'Dual Adjustable Cable Pulley Station',
        'setup': 'Slide the pulley carriage to the marked notch and ensure the pin clicks into the rail.',
        'grip': 'Attach handles (Rope, D-Handles, Straight Bar) securely using the steel carabiner.',
      };
    } else if (eq == 'machine') {
      return {
        'equipment': 'Plate-Loaded / Pin-Selectorized Machine',
        'setup': 'Adjust the seat or chest pad so the machine pivot aligns with your anatomical joints.',
        'grip': 'Full grip on ergonomic padded handles with shoulders firmly anchored into the backrest.',
      };
    } else {
      return {
        'equipment': 'Calisthenics Bar / Floor Mat / Dip Bars',
        'setup': 'Inspect bar or apparatus stability. Ensure clear floor space underneath for safety.',
        'grip': 'Full overhand or neutral grip with knuckles wrapped tightly around the bar.',
      };
    }
  }

  Map<String, String> _getBeginnerCues(ExerciseModel ex) {
    final name = ex.name.toLowerCase();
    final mg = ex.muscleGroupId.toLowerCase();

    String setup = 'Adjust your bench or seat so you are comfortable. Grip securely with wrists straight.';
    String execution = 'Move through a controlled, full range of motion. Inhale down, exhale as you push/pull.';
    String mistake = 'Avoid using momentum or swinging your body. Focus on feeling the muscle contract.';

    if (name.contains('bench press') || name.contains('chest press')) {
      setup = 'Lie flat with feet planted firmly on the floor. Grip the bar/handles just outside shoulder-width.';
      execution = 'Lower the weight under control until it reaches mid-chest level, then press smoothly up.';
      mistake = 'Do not flare elbows out at 90 degrees or bounce the weight off your chest.';
    } else if (name.contains('fly')) {
      setup = 'Hold dumbbells or handles above chest with a slight bend in your elbows that stays locked.';
      execution = 'Open your arms wide in a hugging arc until you feel a gentle stretch, then squeeze back up.';
      mistake = 'Avoid bending your elbows into a press; maintain the arc throughout the movement.';
    } else if (name.contains('squat') || name.contains('leg press')) {
      setup = 'Stand with feet shoulder-width apart, toes pointed slightly outward. Keep chest tall.';
      execution = 'Bend at knees and hips as if sitting into a chair until thighs are parallel to the ground.';
      mistake = 'Do not let your knees cave inwards or your heels lift off the floor.';
    } else if (name.contains('deadlift')) {
      setup = 'Stand with bar over mid-foot. Hinge hips back, keep back flat, and grip the bar firmly.';
      execution = 'Push the floor away through your heels, extending hips and knees simultaneously.';
      mistake = 'Never round your lower back under load. Keep the bar close to your shins.';
    } else if (name.contains('curl')) {
      setup = 'Stand or sit tall with shoulders back and elbows pinned close to your torso.';
      execution = 'Curl the weight up by flexing biceps. Squeeze at the top, then lower slowly for 2 seconds.';
      mistake = 'Do not swing your back or use hip momentum to hoist the weight up.';
    } else if (name.contains('pulldown') || name.contains('pull-up')) {
      setup = 'Grip the bar slightly wider than shoulder-width. Sit with thighs secured under pads.';
      execution = 'Pull down by driving elbows toward your ribs until the bar reaches upper chest level.';
      mistake = 'Avoid leaning excessively backward. Keep torso stable and upright.';
    } else if (name.contains('row')) {
      setup = 'Hinge at the hips with flat spine or sit tall at the cable machine with chest lifted.';
      execution = 'Pull handles toward your waist, pulling with your elbows and pinching shoulder blades.';
      mistake = 'Do not yank with your arms or round your upper back at the bottom of the stretch.';
    } else if (name.contains('overhead') || name.contains('shoulder press')) {
      setup = 'Hold weights at shoulder height with elbows tucked slightly forward under your wrists.';
      execution = 'Press straight upward until arms are extended overhead without arching your back.';
      mistake = 'Avoid hyperextending your lower back. Brace your core and glutes tightly.';
    } else if (name.contains('lateral raise')) {
      setup = 'Hold dumbbells at sides with a slight forward lean and soft bend in elbows.';
      execution = 'Raise arms out to sides until parallel to the floor, leading with elbows.';
      mistake = 'Do not shrug your traps up toward your ears or swing the weights with body momentum.';
    } else if (mg == 'legs') {
      setup = 'Align knee joints with machine pivot point or stance shoulder-width apart.';
      execution = 'Perform controlled descent, feeling tension in quads and hamstrings, then drive up.';
      mistake = 'Do not lock out knees aggressively at the top of the extension or press.';
    }

    return {
      'setup': setup,
      'execution': execution,
      'mistake': mistake,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cues = _getBeginnerCues(exercise);
    final eqInfo = _getDetailedEquipmentInfo(exercise);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: context.sheetBorder, width: 1.5)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.handleBar,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Top Title Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EXERCISE PREVIEW & EQUIPMENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF71717A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Beginner Form Guide',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamilyDisplay,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        AppHaptics.tap();
                        ExerciseWebSearchSheet.show(context, exerciseName: exercise.name);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFEAEAEE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'G',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Search Form',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: context.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. LIVE ANIMATED REP CANVAS WITH EQUIPMENT & LIFTER
                  Exercise3DViewer(
                    exerciseName: exercise.name,
                    muscleGroupId: exercise.muscleGroupId,
                    equipment: exercise.equipment.name,
                    height: 280,
                  ),

                  const SizedBox(height: 16),

                  // 2. Exercise Title & Rep Parameters
                  Text(
                    exercise.name,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamilyDisplay,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Quick specs row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildSpecPill(
                        context,
                        icon: Icons.repeat_rounded,
                        label: '${exercise.repMin}-${exercise.repMax} Reps',
                      ),
                      _buildSpecPill(
                        context,
                        icon: Icons.timer_outlined,
                        label: '${exercise.restSeconds}s Rest',
                      ),
                      _buildSpecPill(
                        context,
                        icon: Icons.tune_rounded,
                        label: '${exercise.weightStep} kg step',
                      ),
                      if (exercise.secondaryGroups.isNotEmpty)
                        _buildSpecPill(
                          context,
                          icon: Icons.hub_outlined,
                          label: 'Also: ${exercise.secondaryGroups.join(", ")}',
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // 3. DETAILED EQUIPMENT & SETUP SECTION
                  Row(
                    children: [
                      Icon(Icons.precision_manufacturing_rounded, size: 16, color: context.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'EQUIPMENT & SETUP DETAILS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF71717A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242424) : const Color(0xFFF7F7F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E5EB),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF343434) : const Color(0xFFE8E8ED),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.fitness_center_rounded, size: 15, color: context.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                eqInfo['equipment']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildEqSubRow(context, label: 'Safety Setup', desc: eqInfo['setup']!),
                        const SizedBox(height: 8),
                        _buildEqSubRow(context, label: 'Hand Grip', desc: eqInfo['grip']!),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // 4. Step-by-Step Form Instructions for Beginners
                  Row(
                    children: [
                      Icon(Icons.directions_run_rounded, size: 16, color: context.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'HOW TO PERFORM (FORM CHECKLIST)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF71717A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildCueItem(
                    context,
                    step: '1',
                    title: 'Setup & Stance',
                    desc: cues['setup']!,
                    icon: Icons.accessibility_rounded,
                  ),
                  const SizedBox(height: 10),

                  _buildCueItem(
                    context,
                    step: '2',
                    title: 'Movement & Breathing',
                    desc: cues['execution']!,
                    icon: Icons.play_arrow_rounded,
                  ),
                  const SizedBox(height: 10),

                  _buildCueItem(
                    context,
                    step: '3',
                    title: 'Form Tip (Avoid Mistake)',
                    desc: cues['mistake']!,
                    icon: Icons.shield_outlined,
                    isWarning: true,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Action Bar: Confirm & Add Exercise
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: context.sheetBg,
              border: Border(top: BorderSide(color: context.sheetBorder, width: 1.0)),
            ),
            child: GlassButton(
              text: 'Confirm & Add Exercise',
              icon: Icons.check_circle_outline_rounded,
              style: GlassButtonStyle.primary,
              height: 52,
              onPressed: () {
                AppHaptics.save();
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEqSubRow(BuildContext context, {required String label, required String desc}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: context.textTertiary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSpecPill(BuildContext context, {required IconData icon, required String label}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282828) : const Color(0xFFEEEEF1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF383838) : const Color(0xFFE2E2E8),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCueItem(
    BuildContext context, {
    required String step,
    required String title,
    required String desc,
    required IconData icon,
    bool isWarning = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242424) : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E5EB),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isWarning
                  ? (isDark ? const Color(0xFF3E2424) : const Color(0xFFFEE2E2))
                  : (isDark ? const Color(0xFF343434) : const Color(0xFFEAEAEA)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 16,
                color: isWarning
                    ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                    : context.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isWarning
                        ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C))
                        : context.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
