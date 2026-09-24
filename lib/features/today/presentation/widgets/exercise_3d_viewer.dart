import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../domain/services/exercise_media_service.dart';
import 'exercise_web_search_sheet.dart';

/// Exercise Guide Hero Widget
/// - Displays 100% verified 3D animated model if exact match exists.
/// - If not matched, strictly DOES NOT show any wrong animation.
/// - Provides a one-tap in-app Google Search & Images button so beginners
///   can view real gym machines, photos, and form guides directly inside the app.
class Exercise3DViewer extends StatelessWidget {
  final String exerciseName;
  final String muscleGroupId;
  final String equipment;
  final double height;
  final bool isThumbnail;

  const Exercise3DViewer({
    super.key,
    required this.exerciseName,
    required this.muscleGroupId,
    required this.equipment,
    this.height = 240,
    this.isThumbnail = false,
  });

  IconData _getEquipmentIcon(String eq) {
    switch (eq.toLowerCase()) {
      case 'machine':
      case 'leverage machine':
      case 'sled machine':
        return Icons.precision_manufacturing_rounded;
      case 'cable':
        return Icons.cable_rounded;
      case 'dumbbell':
        return Icons.fitness_center_rounded;
      case 'barbell':
        return Icons.fitness_center_rounded;
      case 'bodyweight':
        return Icons.accessibility_new_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  void _openGoogleSearch(BuildContext context, {bool images = true}) {
    AppHaptics.tap();
    ExerciseWebSearchSheet.show(
      context,
      exerciseName: exerciseName,
      startWithImages: images,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final verifiedMedia = ExerciseMediaService.getVerifiedMedia(exerciseName);

    // Thumbnail mode
    if (isThumbnail) {
      if (verifiedMedia != null) {
        return Container(
          width: height,
          height: height,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFEFEFF2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              verifiedMedia.source,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.fitness_center_rounded, size: 22),
            ),
          ),
        );
      }
      return Container(
        width: height,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFEFEFF2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_getEquipmentIcon(equipment), size: 22, color: context.textSecondary),
      );
    }

    // Full Guide Hero Container
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF3F3F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF333338) : const Color(0xFFE2E2E8),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // If verified animation exists, show it with top badges
          if (verifiedMedia != null) ...[
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141416) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Image.asset(
                      verifiedMedia.source,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.fitness_center_rounded, size: 48),
                    ),
                  ),

                  // Top badge: Verified 3D Model
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF222226) : const Color(0xFFF1F1F5)).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'VERIFIED 3D FORM',
                            style: TextStyle(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top badge: Muscle
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        muscleGroupId.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ] else ...[
            // No verified match -> Clean placeholder with icon & machine info (no wrong animation!)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getEquipmentIcon(equipment), size: 26, color: context.textPrimary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              equipment.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                muscleGroupId.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Detailed Visual Guide',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamilyDisplay,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'View real photos, machines & form on Google',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── IN-APP GOOGLE SEARCH BAR / BUTTON ──
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Primary Action: Google Image Search in app
                Expanded(
                  child: InkWell(
                    onTap: () => _openGoogleSearch(context, images: true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'G',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Search Images & Machine on Google',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward_ios_rounded, size: 11, color: context.textSecondary),
                        ],
                      ),
                    ),
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
