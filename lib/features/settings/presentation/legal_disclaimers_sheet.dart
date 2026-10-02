import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_tile.dart';
import '../../../data/providers.dart';

class LegalDisclaimersSheet extends ConsumerStatefulWidget {
  final bool requireAgreement;

  const LegalDisclaimersSheet({
    super.key,
    this.requireAgreement = false,
  });

  static Future<void> show(BuildContext context, {bool requireAgreement = false}) {
    AppHaptics.tap();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LegalDisclaimersSheet(requireAgreement: requireAgreement),
    );
  }

  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final hasAgreed = await settingsRepo.getHasAgreedToDisclaimers();
    if (!hasAgreed && context.mounted) {
      await show(context, requireAgreement: true);
    }
  }

  @override
  ConsumerState<LegalDisclaimersSheet> createState() => _LegalDisclaimersSheetState();
}

class _LegalDisclaimersSheetState extends ConsumerState<LegalDisclaimersSheet> {
  bool _agreedToTerms = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2E3342) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.accent.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: context.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Legal & Safety Notices',
                        style: AppTypography.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Important terms, exercise waivers, and media policy',
                        style: AppTypography.labelSmall.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    AppHaptics.tap();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.8),

          // Scrollable Sections
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              children: [
                _buildDisclaimerCard(
                  context,
                  badge: 'SAFETY & HEALTH',
                  badgeColor: AppColors.error,
                  icon: Icons.health_and_safety_outlined,
                  title: 'Physical Exercise & Medical Liability Waiver',
                  body:
                      'IronLog is strictly a training logging tool and progression calculator. It does not provide medical, orthopedic, or clinical healthcare advice.\n\nResistance training and intense physical exercise carry inherent risks of musculoskeletal injury or cardiovascular strain. Always consult a certified physician or healthcare professional prior to beginning any rigorous lifting program. By using IronLog, you voluntarily assume all liability and personal risk for your training.',
                ),
                const SizedBox(height: 12),
                _buildDisclaimerCard(
                  context,
                  badge: 'AI GUIDANCE',
                  badgeColor: context.accent,
                  icon: Icons.psychology_outlined,
                  title: 'AI Workout Coach & Nutrition Advice',
                  body:
                      'Workouts, program suggestions, and nutritional estimations generated by the AI assistant are produced by automated third-party language models (Gemini, OpenAI, Groq, Anthropic, or custom endpoints) for informational and fitness motivation purposes only.\n\nThey do not replace certified personal training, strength coaching, or registered dietary consultation. Always inspect generated workouts and exercise within your personal capabilities.',
                ),
                const SizedBox(height: 12),
                _buildDisclaimerCard(
                  context,
                  badge: 'FAIR USE',
                  badgeColor: const Color(0xFFF59E0B),
                  icon: Icons.image_search_outlined,
                  title: 'Web Image Search & Open Media Attribution',
                  body:
                      'Exercise thumbnails, visual movement diagrams, and anatomical guides are retrieved from public open-web sources and open catalogs strictly for personal reference and visual identification.\n\nAll trademarks, copyrights, and intellectual property remain the property of their respective creators. Fetched media is cached locally on your device to minimize data usage.',
                ),
                const SizedBox(height: 12),
                _buildDisclaimerCard(
                  context,
                  badge: 'PRIVACY',
                  badgeColor: AppColors.success,
                  icon: Icons.lock_outline_rounded,
                  title: 'Offline-First & Local Data Privacy',
                  body:
                      'IronLog is built with an offline-first philosophy. Your training logs, personal records (PRs), custom routines, and measurements are stored 100% locally in SQLite on your device.\n\nWe do not sell, track, monetize, or harvest your personal fitness logs.',
                ),
              ],
            ),
          ),

          // Bottom Action
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13151B) : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF2E3342) : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
            ),
            child: widget.requireAgreement
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          AppHaptics.selection();
                          setState(() => _agreedToTerms = !_agreedToTerms);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _agreedToTerms,
                                activeColor: context.accent,
                                onChanged: (val) {
                                  AppHaptics.selection();
                                  setState(() => _agreedToTerms = val ?? false);
                                },
                              ),
                              Expanded(
                                child: Text(
                                  'I have read and agree to the exercise waiver and legal disclaimers.',
                                  style: AppTypography.labelSmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GlassButton(
                        text: 'Accept & Continue',
                        icon: Icons.check_circle_outline_rounded,
                        style: GlassButtonStyle.primary,
                        onPressed: _agreedToTerms
                            ? () async {
                                AppHaptics.success();
                                await ref
                                    .read(settingsRepositoryProvider)
                                    .setHasAgreedToDisclaimers(true);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              }
                            : null,
                      ),
                    ],
                  )
                : GlassButton(
                    text: 'I Understand',
                    icon: Icons.check_rounded,
                    style: GlassButtonStyle.primary,
                    onPressed: () {
                      AppHaptics.tap();
                      Navigator.of(context).pop();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard(
    BuildContext context, {
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required String title,
    required String body,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: badgeColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: AppTypography.bodyMedium.copyWith(
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
