import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/url_launcher_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_tile.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/bouncy_pressable.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../domain/models/ai_config_model.dart';
import '../../../domain/models/chibi_avatar_model.dart';
import '../../../domain/services/ai_assistant_service.dart';
import '../../today/presentation/widgets/ai_assistant_sheet.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  List<AiConfigModel> _profiles = [];
  String _activeProfileId = 'kilo_free';
  ChibiAvatar _activeAvatar = ChibiAvatar.aiko;
  bool _isLoading = true;
  bool _isTestingActive = false;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final aiService = ref.read(aiAssistantServiceProvider);
    final profiles = await aiService.getProfiles();
    final activeId = await aiService.getActiveProfileId();
    final avatar = await ChibiAvatar.loadCurrent();
    if (mounted) {
      setState(() {
        _profiles = profiles;
        _activeProfileId = activeId;
        _activeAvatar = avatar;
        _isLoading = false;
      });
    }
  }

  Future<void> _switchActiveProfile(String profileId) async {
    AppHaptics.mediumImpact();
    setState(() => _activeProfileId = profileId);
    final aiService = ref.read(aiAssistantServiceProvider);
    await aiService.setActiveProfile(profileId);
    if (mounted) {
      final active = _profiles.firstWhere((p) => p.id == profileId, orElse: () => _profiles.first);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to "${active.name}"'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: 260,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _testConnection(AiConfigModel profile) async {
    AppHaptics.tap();
    setState(() => _isTestingActive = true);
    final res = await ref.read(aiAssistantServiceProvider).testConnection(profile);
    if (mounted) {
      setState(() => _isTestingActive = false);
      final isSuccess = res['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  res['message']?.toString() ?? 'Done',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
          backgroundColor: isSuccess ? AppColors.workingSet : AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _deleteProfile(AiConfigModel profile) async {
    if (_profiles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the only AI profile.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: const Text('Delete Profile?'),
        content: Text('Are you sure you want to delete "${profile.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      AppHaptics.warning();
      final aiService = ref.read(aiAssistantServiceProvider);
      await aiService.deleteProfile(profile.id);
      await _loadProfiles();
    }
  }

  Future<void> _duplicateProfile(AiConfigModel profile) async {
    AppHaptics.tap();
    final newProfile = profile.copyWith(
      id: 'profile_${DateTime.now().millisecondsSinceEpoch}',
      name: '${profile.name} (Copy)',
    );
    final updated = List<AiConfigModel>.from(_profiles)..add(newProfile);
    await ref.read(aiAssistantServiceProvider).saveProfiles(updated);
    await _loadProfiles();
  }

  void _openProfileEditor({AiConfigModel? profile}) {
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProfileEditorSheet(
        profile: profile,
        onSave: (savedProfile) async {
          final aiService = ref.read(aiAssistantServiceProvider);
          final list = List<AiConfigModel>.from(_profiles);
          final idx = list.indexWhere((p) => p.id == savedProfile.id);
          if (idx != -1) {
            list[idx] = savedProfile;
          } else {
            list.add(savedProfile);
          }
          await aiService.saveProfiles(list, activeProfileId: savedProfile.id);
          await _loadProfiles();
        },
      ),
    );
  }

  void _showAiGuideDialog() {
    AppHaptics.tap();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.auto_awesome_rounded, color: context.accent, size: 20),
            ),
            const SizedBox(width: 8),
            const Text('AI Tools & Capabilities', style: AppTypography.titleMedium),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'IronLog AI Assistant connects to any OpenAI-compatible server or cloud LLM to perform app actions for you:',
                style: TextStyle(fontSize: 12.5, color: context.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              _buildGuideItem(Icons.fitness_center_rounded, 'Log Workout Sets', 'E.g., "Log bench press 80kg x 8 reps"'),
              _buildGuideItem(Icons.emoji_events_rounded, 'Query PRs & Records', 'E.g., "What is my deadlift 1RM PR?"'),
              _buildGuideItem(Icons.trending_up_rounded, 'Progressive Overload', 'E.g., "Recommend squat weight for today"'),
              _buildGuideItem(Icons.timer_outlined, 'Rest Timers', 'E.g., "Start a 90 second rest timer"'),
              _buildGuideItem(Icons.format_list_bulleted_rounded, 'Build & Delete Routines', 'E.g., "Make me an Upper/Lower routine"'),
              _buildGuideItem(Icons.travel_explore_rounded, 'Web Search & Science', 'Search hypertrophy studies & form cues'),
              _buildGuideItem(Icons.lan_rounded, 'Local Offline AI', 'Use Ollama or LM Studio without any API key!'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Got it', style: TextStyle(color: context.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: context.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
                Text(desc, style: TextStyle(fontSize: 11, color: context.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeProfile = _profiles.firstWhere(
      (p) => p.id == _activeProfileId,
      orElse: () => _profiles.isNotEmpty ? _profiles.first : const AiConfigModel(),
    );

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Configuration',
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyDisplay,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            Text(
              'Multiple profiles • Endpoints & Models',
              style: TextStyle(fontSize: 11, color: context.textTertiary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: context.textSecondary, size: 21),
            tooltip: 'AI Capabilities Guide',
            onPressed: _showAiGuideDialog,
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: context.accent, size: 24),
            tooltip: 'Add Profile',
            onPressed: () => _openProfileEditor(),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ── AI Companion Mascot ──────────────────────────────────────────
                const Text('AI COMPANION MASCOT', style: AppTypography.labelSmall),
                const SizedBox(height: AppSpacing.xs),
                GlassTile(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: context.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.pets_rounded, color: context.accent, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _activeAvatar.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: context.accent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: context.accent.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        _activeAvatar.tag,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: context.accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap any mascot below to switch your AI coach',
                                  style: TextStyle(fontSize: 11, color: context.textTertiary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _activeAvatar.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: ChibiAvatar.values.map((avatar) {
                            final isSelected = avatar == _activeAvatar;
                            return SizedBox(
                              width: 96,
                              child: GestureDetector(
                                onTap: () async {
                                  AppHaptics.selection();
                                  final messenger = ScaffoldMessenger.of(context);
                                  await ChibiAvatar.saveCurrent(avatar);
                                  if (mounted) {
                                    setState(() => _activeAvatar = avatar);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Switched AI companion to ${avatar.name}!'),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        width: 280,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? context.accent.withValues(alpha: 0.18)
                                        : (context.isDark ? const Color(0xFF161922) : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? context.accent : context.cardBorder,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: context.accent.withValues(alpha: 0.25),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        avatar.assetPath,
                                        height: 54,
                                        fit: BoxFit.contain,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        avatar.name,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? context.accent : context.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isSelected ? context.accent : (context.isDark ? const Color(0xFF262A36) : const Color(0xFFE2E8F0)),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          isSelected ? 'ACTIVE' : avatar.badge,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected ? (context.isDark ? Colors.black : Colors.white) : context.textTertiary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Active Profile Hero Card ──────────────────────────────────────
                const Text('ACTIVE PROFILE', style: AppTypography.labelSmall),
                const SizedBox(height: AppSpacing.xs),
                GlassTile(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: context.accent.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.auto_awesome_rounded, color: context.accent, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activeProfile.name,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Model: ${activeProfile.modelName}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.workingSet.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.workingSet.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 12, color: AppColors.workingSet),
                                SizedBox(width: 4),
                                Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: AppColors.workingSet,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.isDark ? const Color(0x18FFFFFF) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.link_rounded, size: 14, color: context.textTertiary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    activeProfile.baseUrl,
                                    style: TextStyle(fontSize: 11.5, color: context.textSecondary, fontFamily: 'monospace'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  !activeProfile.requireApiKey ? Icons.key_off_rounded : Icons.vpn_key_rounded,
                                  size: 14,
                                  color: context.textTertiary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  !activeProfile.requireApiKey
                                      ? 'Free / Local Mode (No API Key Required)'
                                      : (activeProfile.apiKey.isNotEmpty ? 'API Key Configured' : 'API Key Required'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: !activeProfile.requireApiKey
                                        ? AppColors.workingSet
                                        : (activeProfile.apiKey.isNotEmpty ? context.textSecondary : AppColors.error),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GlassButton(
                              text: 'Test Connection',
                              icon: Icons.network_check_rounded,
                              style: GlassButtonStyle.primary,
                              isLoading: _isTestingActive,
                              onPressed: () => _testConnection(activeProfile),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GlassButton(
                              text: 'Edit Profile',
                              icon: Icons.tune_rounded,
                              style: GlassButtonStyle.secondary,
                              onPressed: () => _openProfileEditor(profile: activeProfile),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GlassButton(
                        text: 'Open AI Coach Chat',
                        icon: Icons.chat_bubble_outline_rounded,
                        style: GlassButtonStyle.secondary,
                        onPressed: () => AiAssistantSheet.show(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Multiple AI Profiles List ─────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('AVAILABLE PROFILES (${_profiles.length})', style: AppTypography.labelSmall),
                    ScaleTap(
                      onPressed: () => _openProfileEditor(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.add_rounded, size: 14, color: context.accent),
                            const SizedBox(width: 3),
                            Text(
                              'Add Profile',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Tap any profile card to switch your active AI model instantly.',
                  style: TextStyle(fontSize: 11.5, color: context.textTertiary),
                ),
                const SizedBox(height: AppSpacing.sm),

                for (final profile in _profiles)
                  _buildProfileCard(profile, isActive: profile.id == _activeProfileId),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildProfileCard(AiConfigModel profile, {required bool isActive}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassTile(
        padding: const EdgeInsets.all(12),
        onTap: () => _switchActiveProfile(profile.id),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Radio / Active Indicator
            Icon(
              isActive ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isActive ? context.accent : context.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 12),

            // Profile Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.5,
                            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: context.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: context.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${profile.provider.displayName} • ${profile.modelName}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: context.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Actions: Edit, Duplicate, Delete
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 18, color: context.textSecondary),
                  tooltip: 'Edit Profile',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: () => _openProfileEditor(profile: profile),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.copy_rounded, size: 17, color: context.textTertiary),
                  tooltip: 'Duplicate Profile',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: () => _duplicateProfile(profile),
                ),
                if (_profiles.length > 1) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                    tooltip: 'Delete Profile',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: () => _deleteProfile(profile),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile Editor Bottom Sheet ─────────────────────────────────────────────
class _ProfileEditorSheet extends ConsumerStatefulWidget {
  final AiConfigModel? profile;
  final ValueChanged<AiConfigModel> onSave;

  const _ProfileEditorSheet({
    this.profile,
    required this.onSave,
  });

  @override
  ConsumerState<_ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends ConsumerState<_ProfileEditorSheet> {
  late TextEditingController _nameController;
  late TextEditingController _baseUrlController;
  late TextEditingController _modelController;
  late TextEditingController _apiKeyController;
  late AiProvider _provider;
  late double _temperature;
  late bool _enableWebSearch;
  late bool _requireApiKey;
  bool _obscureApiKey = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile ?? const AiConfigModel();
    final isNew = widget.profile == null;
    _nameController = TextEditingController(text: isNew ? 'Custom AI Profile' : p.name);
    _baseUrlController = TextEditingController(text: p.baseUrl);
    _modelController = TextEditingController(text: p.modelName);
    _apiKeyController = TextEditingController(text: p.apiKey);
    _provider = p.provider;
    _temperature = p.temperature;
    _enableWebSearch = p.enableWebSearch;
    _requireApiKey = p.requireApiKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _applyPreset({
    required String name,
    required AiProvider provider,
    required String baseUrl,
    required String model,
    required bool requireKey,
  }) {
    AppHaptics.tap();
    setState(() {
      _nameController.text = name;
      _provider = provider;
      _baseUrlController.text = baseUrl;
      _modelController.text = model;
      _requireApiKey = requireKey;
    });
  }

  AiConfigModel _buildCurrentModel() {
    return AiConfigModel(
      id: widget.profile?.id ?? 'profile_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim().isEmpty ? 'AI Profile' : _nameController.text.trim(),
      provider: _provider,
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim().isEmpty ? _provider.defaultBaseUrl : _baseUrlController.text.trim(),
      modelName: _modelController.text.trim().isEmpty ? _provider.defaultModel : _modelController.text.trim(),
      temperature: _temperature,
      enableWebSearch: _enableWebSearch,
      requireApiKey: _requireApiKey,
    );
  }

  Future<void> _testConnection() async {
    AppHaptics.tap();
    setState(() => _isTesting = true);
    final model = _buildCurrentModel();
    final res = await ref.read(aiAssistantServiceProvider).testConnection(model);
    if (mounted) {
      setState(() => _isTesting = false);
      final isSuccess = res['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Done'),
          backgroundColor: isSuccess ? AppColors.workingSet : AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final navBarPadding = MediaQuery.of(context).padding.bottom;
    final safeBottom = math.max(navBarPadding, 16.0);
    final isNew = widget.profile == null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.textTertiary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isNew ? 'Create AI Profile' : 'Edit AI Profile',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Scrollable fields
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Preset Fill Chips
                  const Text('QUICK PRESET TEMPLATES', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip(
                          'Agnes AI (Fast & Smart)',
                          () => _applyPreset(
                            name: 'Agnes AI (Fast & Smart)',
                            provider: AiProvider.agnes,
                            baseUrl: 'https://apihub.agnes-ai.com/v1',
                            model: 'agnes-3.0-flash',
                            requireKey: true,
                          ),
                          isRecommended: true,
                          icon: Icons.flash_on_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildPresetChip(
                          'Claude 3.7 Sonnet',
                          () => _applyPreset(
                            name: 'Anthropic Claude 3.7 Sonnet',
                            provider: AiProvider.anthropic,
                            baseUrl: 'https://api.anthropic.com/v1',
                            model: 'claude-3-7-sonnet-20250219',
                            requireKey: true,
                          ),
                          icon: Icons.psychology_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildPresetChip(
                          'Gemini 2.0 Flash',
                          () => _applyPreset(
                            name: 'Google Gemini 2.0 Flash',
                            provider: AiProvider.gemini,
                            baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
                            model: 'gemini-2.0-flash',
                            requireKey: true,
                          ),
                          icon: Icons.diamond_outlined,
                        ),
                        const SizedBox(width: 6),
                        _buildPresetChip(
                          'GPT-4o Mini',
                          () => _applyPreset(
                            name: 'OpenAI GPT-4o Mini',
                            provider: AiProvider.openai,
                            baseUrl: 'https://api.openai.com/v1',
                            model: 'gpt-4o-mini',
                            requireKey: true,
                          ),
                          icon: Icons.auto_awesome_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildPresetChip(
                          'Groq Llama 3.3',
                          () => _applyPreset(
                            name: 'Groq Llama 3.3 70B',
                            provider: AiProvider.groq,
                            baseUrl: 'https://api.groq.com/openai/v1',
                            model: 'llama-3.3-70b-versatile',
                            requireKey: true,
                          ),
                          icon: Icons.speed_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildPresetChip(
                          'DeepSeek V3',
                          () => _applyPreset(
                            name: 'DeepSeek V3 Chat',
                            provider: AiProvider.deepseek,
                            baseUrl: 'https://api.deepseek.com/v1',
                            model: 'deepseek-chat',
                            requireKey: true,
                          ),
                          icon: Icons.hub_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildPresetChip(
                          'Kilo Free',
                          () => _applyPreset(
                            name: 'Default AI Coach',
                            provider: AiProvider.universal,
                            baseUrl: 'https://api.kilo.ai/api/gateway',
                            model: 'kilo-auto/free',
                            requireKey: false,
                          ),
                          icon: Icons.bolt_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildPresetChip(
                          'Ollama Local',
                          () => _applyPreset(
                            name: 'Ollama (Local)',
                            provider: AiProvider.universal,
                            baseUrl: 'http://localhost:11434/v1',
                            model: 'llama3.2',
                            requireKey: false,
                          ),
                          icon: Icons.terminal_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildPresetChip(
                          'LM Studio',
                          () => _applyPreset(
                            name: 'LM Studio',
                            provider: AiProvider.universal,
                            baseUrl: 'http://localhost:1234/v1',
                            model: 'local-model',
                            requireKey: false,
                          ),
                          icon: Icons.computer_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Profile Name
                  _buildInputLabel('PROFILE NAME'),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(fontSize: 13.5, color: context.textPrimary),
                    decoration: _inputDecoration('e.g. Kilo Free, Work LM Studio, OpenAI'),
                  ),
                  const SizedBox(height: 12),

                  // Provider
                  _buildInputLabel('PROVIDER PROTOCOL'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0x18FFFFFF) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AiProvider>(
                        value: _provider,
                        isExpanded: true,
                        dropdownColor: context.cardBg,
                        icon: Icon(Icons.arrow_drop_down_rounded, color: context.accent),
                        items: AiProvider.values.map((p) {
                          return DropdownMenuItem<AiProvider>(
                            value: p,
                            child: Text(
                              p.displayName,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: (newP) {
                          if (newP == null) return;
                          setState(() {
                            _provider = newP;
                            _baseUrlController.text = newP.defaultBaseUrl;
                            _modelController.text = newP.defaultModel;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Model Name
                  _buildInputLabel('MODEL NAME'),
                  TextField(
                    controller: _modelController,
                    style: TextStyle(fontSize: 13.5, color: context.textPrimary),
                    decoration: _inputDecoration('e.g. kilo-auto/free, gpt-4o-mini, llama3.2'),
                  ),
                  const SizedBox(height: 12),

                  // Base URL
                  _buildInputLabel('API BASE URL'),
                  TextField(
                    controller: _baseUrlController,
                    style: TextStyle(fontSize: 13, color: context.textPrimary, fontFamily: 'monospace'),
                    decoration: _inputDecoration('e.g. https://api.kilo.ai/api/gateway'),
                  ),
                  const SizedBox(height: 12),

                  // API Key
                  _buildInputLabel('API KEY'),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureApiKey,
                    style: TextStyle(fontSize: 13, color: context.textPrimary),
                    decoration: _inputDecoration('Paste API key here (leave empty for free / local)').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureApiKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: context.textTertiary,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                      ),
                    ),
                  ),
                  if (_provider.apiKeyUrl.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BouncyPressable(
                        onTap: () async {
                          AppHaptics.tap();
                          await UrlLauncherUtils.openUrl(_provider.apiKeyUrl);
                        },
                        scaleDown: 0.95,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: context.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.accent.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.vpn_key_rounded, size: 13, color: context.accent),
                              const SizedBox(width: 5),
                              Text(
                                'Get ${_provider.displayName} API Key',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: context.accent,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.open_in_new_rounded, size: 11, color: context.accent),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Work without API Key Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0x18FFFFFF) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.key_off_rounded,
                          size: 18,
                          color: !_requireApiKey ? context.accent : context.textTertiary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Work without API Key',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary),
                              ),
                              Text(
                                'Enable for free endpoints (Kilo Auto Free, Ollama, LM Studio)',
                                style: TextStyle(fontSize: 10.5, color: context.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: !_requireApiKey,
                          activeThumbColor: context.accent,
                          activeTrackColor: context.accent.withValues(alpha: 0.4),
                          onChanged: (val) {
                            AppHaptics.tap();
                            setState(() => _requireApiKey = !val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Temperature Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInputLabel('TEMPERATURE'),
                      Text(_temperature.toStringAsFixed(1), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.accent)),
                    ],
                  ),
                  Slider(
                    value: _temperature,
                    min: 0.0,
                    max: 1.5,
                    divisions: 15,
                    activeColor: context.accent,
                    onChanged: (val) => setState(() => _temperature = val),
                  ),
                ],
              ),
            ),
          ),
          // Sticky Bottom Actions pinned above system bars/keyboard
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset > 0 ? bottomInset + 12 : safeBottom + 12),
            decoration: BoxDecoration(
              color: context.cardBg,
              border: Border(top: BorderSide(color: context.cardBorder, width: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: GlassButton(
                    text: 'Validate & Ping',
                    icon: Icons.network_check_rounded,
                    style: GlassButtonStyle.secondary,
                    isLoading: _isTesting,
                    onPressed: _testConnection,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GlassButton(
                    text: 'Save Profile',
                    icon: Icons.check_rounded,
                    style: GlassButtonStyle.primary,
                    onPressed: () {
                      AppHaptics.success();
                      final model = _buildCurrentModel();
                      widget.onSave(model);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap, {bool isRecommended = false, IconData? icon}) {
    return BouncyPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isRecommended ? context.accent.withValues(alpha: 0.18) : context.chipBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRecommended ? context.accent.withValues(alpha: 0.5) : context.chipBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isRecommended ? context.accent : context.textSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isRecommended ? context.accent : context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: context.textTertiary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: context.textTertiary),
      filled: true,
      fillColor: context.isDark ? const Color(0x18FFFFFF) : const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.cardBorder),
      ),
    );
  }
}
