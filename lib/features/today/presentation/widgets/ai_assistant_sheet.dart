import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../core/widgets/bouncy_pressable.dart';
import '../../../../domain/models/ai_chat_message.dart';
import '../../../../domain/models/ai_config_model.dart';
import '../../../../domain/models/chibi_avatar_model.dart';
import '../../../../domain/services/ai_assistant_service.dart';
import '../../../../domain/services/ai_chat_notifier.dart';
import '../../../../domain/services/weight_step_learner.dart';
import '../../../../data/providers.dart';
import 'ai/mermaid_flowchart_view.dart';
import 'ai/ai_pr_history_card.dart';
import 'ai/ai_thinking_views.dart';
import 'ai/ai_preset_preview_card.dart';
import 'ai/ai_agent_question_card.dart';
import 'ai/ai_inline_chat_image.dart';
import 'ai/ai_memories_sheet.dart';
import 'ai/ai_progression_chart_card.dart';

export 'ai/mermaid_flowchart_parser.dart';
export 'ai/mermaid_flowchart_view.dart';
export 'ai/ai_pr_history_card.dart';
export 'ai/ai_thinking_views.dart';
export 'ai/ai_preset_preview_card.dart';
export 'ai/ai_agent_question_card.dart';
export 'ai/ai_inline_chat_image.dart';
export 'ai/ai_memories_sheet.dart';
export 'ai/ai_progression_chart_card.dart';

enum ChatTextSize {
  small(name: 'Small', baseSize: 12.0, scale: 0.88),
  normal(name: 'Normal', baseSize: 13.5, scale: 1.0),
  big(name: 'Big', baseSize: 16.0, scale: 1.18);

  final String name;
  final double baseSize;
  final double scale;
  const ChatTextSize({required this.name, required this.baseSize, required this.scale});
}

enum ChatSheetHeight {
  small(name: 'Small (55%)', factor: 0.55),
  medium(name: 'Medium (86%)', factor: 0.86),
  expanded(name: 'Expanded (96%)', factor: 0.96);

  final String name;
  final double factor;
  const ChatSheetHeight({required this.name, required this.factor});
}

class AiAssistantSheet extends ConsumerStatefulWidget {
  final bool isFullScreen;
  final String? initialPrompt;
  final String? initialImagePath;

  const AiAssistantSheet({
    super.key,
    this.isFullScreen = false,
    this.initialPrompt,
    this.initialImagePath,
  });

  static Future<void> show(BuildContext context, {String? initialPrompt, String? initialImagePath}) {
    AppHaptics.tap();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiAssistantSheet(
        initialPrompt: initialPrompt,
        initialImagePath: initialImagePath,
      ),
    );
  }

  @override
  ConsumerState<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends ConsumerState<AiAssistantSheet> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final FocusNode _focusNode;
  late final AnimationController _pulseController;

  // Speech to text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;

  AiConfigModel _config = const AiConfigModel();
  ChibiAvatar _companion = ChibiAvatar.aiko;
  String? _selectedImagePath;
  bool _showHistorySidebar = false;
  bool _userScrolledUp = false;
  String? _dismissedPresetTitle;
  ChatTextSize _textSize = ChatTextSize.small;
  ChatSheetHeight _sheetHeight = ChatSheetHeight.medium;

  final List<String> _quickPrompts = [
    'What should I eat after today\'s workout?',
    'Log 80kg x 8 on Bench Press',
    'Log 25 Push-Ups',
    'Log 45 min Football game',
    'Calculate warmup for 100kg Squat',
    'Analyze muscle balance',
    'Rest 90 seconds',
    'Recommend weight for Bench Press',
    'Create a 4-day hypertrophy split',
    'Show my PRs and history',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() {})); // trigger border animation on focus change
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _speech = stt.SpeechToText();
    _initSpeech();
    _loadConfig();
    _loadCompanion();
    _loadSavedSizes();
    if (widget.initialImagePath != null) {
      _selectedImagePath = widget.initialImagePath;
    }
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _textController.text = widget.initialPrompt!;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiChatNotifierProvider.notifier).onOpenChat();
      _scrollToBottom();
      if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _loadCompanion() async {
    final companion = await ChibiAvatar.loadCurrent();
    if (mounted) {
      setState(() => _companion = companion);
    }
  }

  void _showCompanionSelector() {
    AppHaptics.heavy();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: BoxDecoration(
            color: context.sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: context.sheetBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 14),
              Text(
                'Select AI Companion',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose your coach mascot & personality',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: ChibiAvatar.values.map((avatar) {
                    final isSelected = avatar == _companion;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () async {
                          AppHaptics.tap();
                          Navigator.pop(ctx);
                          await ChibiAvatar.saveCurrent(avatar);
                          if (mounted) {
                            setState(() => _companion = avatar);
                          }
                        },
                        child: Container(
                          width: 104,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.accent.withValues(alpha: 0.18)
                                : (context.isDark ? const Color(0xFF1E212D) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? context.accent : context.cardBorder,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                avatar.assetPath,
                                width: 54,
                                height: 60,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                avatar.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? context.accent : context.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                avatar.tag,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.textTertiary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
        );
      },
    );
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
      );
      if (mounted) setState(() => _speechAvailable = available);
    } catch (_) {}
  }

  Future<void> _loadConfig() async {
    final aiService = ref.read(aiAssistantServiceProvider);
    final cfg = await aiService.getConfig();
    if (mounted) setState(() => _config = cfg);
  }

  void _showAttachmentMenu() {
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = context.isDark;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: BoxDecoration(
            color: context.sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: context.sheetBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 16),
              Text(
                'Add to Chat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Capture equipment, food, or form for AI analysis',
                style: TextStyle(fontSize: 12.5, color: context.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ScaleTap(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _pickImageFromCamera();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E212D) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.cardBorder),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.accent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.camera_alt_rounded, color: context.accent, size: 24),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Take Photo',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ScaleTap(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _pickImageFromGallery();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E212D) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.cardBorder),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.photo_library_rounded, color: Color(0xFF38BDF8), size: 24),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Photo Library',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromCamera() async {
    AppHaptics.tap();
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (photo != null && mounted) {
        setState(() => _selectedImagePath = photo.path);
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    AppHaptics.tap();
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (photo != null && mounted) {
        setState(() => _selectedImagePath = photo.path);
      }
    } catch (e) {
      debugPrint('Error selecting image: $e');
    }
  }

  Future<void> _clearChat() async {
    AppHaptics.warning();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: context.cardBorder),
        ),
        title: Text('Start New Chat?', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'This will save the current chat to history and open a fresh session.',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: context.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accent,
              foregroundColor: context.isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('New Chat'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(aiChatNotifierProvider.notifier).clearHistory();
      if (mounted) {
        setState(() => _selectedImagePath = null);
        _scrollToBottom();
      }
    }
  }

  Future<void> _deleteCurrentChat() async {
    final chatState = ref.read(aiChatNotifierProvider);
    final sessionId = chatState.currentSessionId;
    if (sessionId == null) return;

    AppHaptics.warning();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: context.cardBorder),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Text('Delete Conversation?',
                style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
        content: Text(
          'This conversation will be permanently deleted and cannot be recovered.',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: context.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(aiChatNotifierProvider.notifier).deleteSession(sessionId);
      if (mounted) {
        setState(() => _selectedImagePath = null);
        _scrollToBottom();
      }
    }
  }

  Future<void> _loadSavedSizes() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTextSize = prefs.getString('ai_chat_text_size');
    final savedHeight = prefs.getString('ai_chat_sheet_height');
    if (mounted) {
      setState(() {
        if (savedTextSize != null) {
          _textSize = ChatTextSize.values.firstWhere(
            (e) => e.name.toLowerCase() == savedTextSize.toLowerCase(),
            orElse: () => ChatTextSize.small,
          );
        }
        if (savedHeight != null) {
          _sheetHeight = ChatSheetHeight.values.firstWhere(
            (e) => e.name.toLowerCase() == savedHeight.toLowerCase(),
            orElse: () => ChatSheetHeight.medium,
          );
        }
      });
    }
  }

  Future<void> _saveTextSize(ChatTextSize size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_chat_text_size', size.name);
  }

  Future<void> _saveSheetHeight(ChatSheetHeight height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_chat_sheet_height', height.name);
  }

  void _cycleSheetHeight() {
    AppHaptics.selection();
    setState(() {
      if (_sheetHeight == ChatSheetHeight.small) {
        _sheetHeight = ChatSheetHeight.medium;
      } else if (_sheetHeight == ChatSheetHeight.medium) {
        _sheetHeight = ChatSheetHeight.expanded;
      } else {
        _sheetHeight = ChatSheetHeight.small;
      }
    });
    _saveSheetHeight(_sheetHeight);
  }

  void _showSizeAdjustmentDialog() {
    AppHaptics.selection();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              decoration: BoxDecoration(
                color: context.sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: context.sheetBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.handleBar,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: context.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.format_size_rounded, size: 18, color: context.accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chat & Display Size',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              'Adjust sheet height and text legibility',
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
                  const SizedBox(height: 18),

                  // 1. Text & Bubble Scale
                  Text(
                    'TEXT & BUBBLE SCALE',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: context.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final s in ChatTextSize.values) ...[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: ScaleTap(
                              onPressed: () {
                                AppHaptics.selection();
                                setState(() => _textSize = s);
                                setModalState(() {});
                                _saveTextSize(s);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: _textSize == s
                                      ? context.accent
                                      : (isDark ? const Color(0xFF1E212D) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _textSize == s
                                        ? context.accent
                                        : (isDark ? const Color(0x22FFFFFF) : const Color(0xFFCBD5E1)),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      s == ChatTextSize.small
                                          ? 'A⁻'
                                          : (s == ChatTextSize.normal ? 'A' : 'A⁺'),
                                      style: TextStyle(
                                        fontSize: s == ChatTextSize.small ? 13 : (s == ChatTextSize.normal ? 15 : 18),
                                        fontWeight: FontWeight.w800,
                                        color: _textSize == s ? Colors.white : context.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      s.name,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: _textSize == s ? Colors.white70 : context.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (!widget.isFullScreen) ...[
                    const SizedBox(height: 18),
                    // 2. Chat Sheet Height
                    Text(
                      'WINDOW HEIGHT',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: context.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final h in ChatSheetHeight.values) ...[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: ScaleTap(
                                onPressed: () {
                                  AppHaptics.selection();
                                  setState(() => _sheetHeight = h);
                                  setModalState(() {});
                                  _saveSheetHeight(h);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _sheetHeight == h
                                        ? context.accent
                                        : (isDark ? const Color(0xFF1E212D) : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _sheetHeight == h
                                          ? context.accent
                                          : (isDark ? const Color(0x22FFFFFF) : const Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        h == ChatSheetHeight.small
                                            ? Icons.horizontal_split_rounded
                                            : (h == ChatSheetHeight.medium
                                                ? Icons.aspect_ratio_rounded
                                                : Icons.fullscreen_rounded),
                                        size: 18,
                                        color: _sheetHeight == h ? Colors.white : context.textPrimary,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        h.name,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _sheetHeight == h ? Colors.white : context.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  // Live Preview Box
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12 * _textSize.scale,
                      vertical: 8 * _textSize.scale,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161922) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PREVIEW',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: context.accent,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Keep up the great form! Rest 90 seconds, then hit your next working set.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: _textSize.baseSize,
                            height: 1.4,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleSend([String? presetText]) {
    final text = (presetText ?? _textController.text).trim();
    final attachedImagePath = _selectedImagePath;
    final chatState = ref.read(aiChatNotifierProvider);
    if ((text.isEmpty && attachedImagePath == null) || chatState.isLoading) return;

    AppHaptics.tap();
    _textController.clear();
    setState(() {
      _selectedImagePath = null;
      _userScrolledUp = false;
    });

    ref.read(aiChatNotifierProvider.notifier).sendMessage(
      text,
      imagePath: attachedImagePath,
    );
    _scrollToBottom();
  }

  void _toggleListening() async {
    if (!_speechAvailable) {
      await _initSpeech();
    }

    if (!_speechAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition not available. Please allow microphone permission.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    } else {
      AppHaptics.tap();
      if (mounted) setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _textController.text = result.recognizedWords;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
          });
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            _speech.stop();
            setState(() => _isListening = false);
            _handleSend();
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
        ),
      );
    }
  }

  void _scrollToBottom({bool smooth = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (smooth) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  void _showMemoriesSheet() {
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ManageMemoriesSheet(companionName: _companion.name),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pulseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final chatState = ref.watch(aiChatNotifierProvider);
    final messages = chatState.messages;
    final isLoading = chatState.isLoading;

    Map<String, dynamic>? latestPresetData;
    for (final msg in messages.reversed) {
      if (msg.role != 'user' && msg.toolResults != null) {
        for (final tr in msg.toolResults!) {
          if (tr.toolName == 'preview_preset' && tr.data != null && tr.data is Map) {
            latestPresetData = Map<String, dynamic>.from(tr.data as Map);
            break;
          }
        }
      }
      if (latestPresetData != null) break;
    }

    ref.listen<AiChatState>(aiChatNotifierProvider, (prev, next) {
      final prevLen = prev?.messages.length ?? 0;
      final nextLen = next.messages.length;
      final isStreaming = next.isLoading || (next.messages.isNotEmpty && next.messages.last.isStreaming);
      final contentChanged = prev?.messages.isNotEmpty == true &&
          next.messages.isNotEmpty &&
          prev!.messages.last.content.length != next.messages.last.content.length;

      if (prevLen != nextLen) {
        _userScrolledUp = false;
        _scrollToBottom();
      } else if (isStreaming && contentChanged) {
        // ONLY autoscroll if user has NOT scrolled up to read higher content
        if (!_userScrolledUp && _scrollController.hasClients) {
          final distance = _scrollController.position.maxScrollExtent - _scrollController.position.pixels;
          if (distance <= 90) {
            _scrollToBottom(smooth: false);
          }
        }
      }
    });

    final sheetBody = Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(16, widget.isFullScreen ? 8 : 12, 16, 8),
          child: Column(
            children: [
              if (!widget.isFullScreen) ...[
                Center(
                  child: GestureDetector(
                    onTap: _cycleSheetHeight,
                    behavior: HitTestBehavior.translucent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                      child: Tooltip(
                        message: 'Tap to resize sheet (${_sheetHeight.name})',
                        child: Container(
                          width: 44,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: context.handleBar,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.isFullScreen) ...[
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20),
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                  ],
                  // Left side: Title, Subtitle, and Toolbar Action Buttons
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981), // Emerald online pulse
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_companion.name} AI Coach',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamilyDisplay,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_config.name} • Live Assistant',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Quick Action Buttons (Compact Clean Header)
                        Row(
                          children: [
                            _buildHeaderIconButton(
                              icon: Icons.refresh_rounded,
                              tooltip: 'New Conversation',
                              onPressed: _clearChat,
                            ),
                            const SizedBox(width: 4),
                            _buildHeaderOverflowMenu(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Top-Right Chibi Character Mascot (replacing any generic logo)
                  BouncyPressable(
                    onTap: _showCompanionSelector,
                    scaleDown: 0.94,
                    child: Tooltip(
                      message: 'AI Companion: ${_companion.name} (Tap to change)',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 46,
                            height: 48,
                            alignment: Alignment.center,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                // Silhouette Drop Shadow
                                Positioned(
                                  bottom: 0,
                                  child: Image.asset(
                                    _companion.assetPath,
                                    width: 44,
                                    height: 48,
                                    fit: BoxFit.contain,
                                    color: Colors.black.withValues(alpha: 0.35),
                                  ),
                                ),
                                // Mascot
                                Positioned(
                                  bottom: 2,
                                  child: Image.asset(
                                    _companion.assetPath,
                                    width: 44,
                                    height: 48,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: context.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: context.accent.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _companion.name,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.accent,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.swap_horiz_rounded, size: 10, color: context.accent),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!widget.isFullScreen) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: context.textSecondary, size: 22),
                      tooltip: 'Close Sheet',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

          // Messages Timeline
          Expanded(
            child: Stack(
              children: [
                messages.isEmpty
                    ? _buildEmptyState()
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (_scrollController.hasClients) {
                            final max = _scrollController.position.maxScrollExtent;
                            final current = _scrollController.position.pixels;
                            final distanceFromBottom = max - current;

                            if (distanceFromBottom > 110 && !_userScrolledUp) {
                              setState(() => _userScrolledUp = true);
                            } else if (distanceFromBottom <= 30 && _userScrolledUp) {
                              setState(() => _userScrolledUp = false);
                            }
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            return _buildMessageBubble(msg);
                          },
                        ),
                      ),
                if (_userScrolledUp)
                  Positioned(
                    bottom: 12,
                    right: 16,
                    child: ScaleTap(
                      onPressed: () {
                        AppHaptics.selection();
                        setState(() => _userScrolledUp = false);
                        _scrollToBottom();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.accent.withValues(alpha: 0.6), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_downward_rounded, size: 14, color: context.accent),
                            const SizedBox(width: 5),
                            Text(
                              'Scroll to bottom',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Sticky Quick-Action Floating Pill Bar for Proposed Routines/Presets
          if (latestPresetData != null && _dismissedPresetTitle != latestPresetData['title']?.toString())
            _buildStickyPresetBar(latestPresetData),

          // Quick Prompt Pills
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _quickPrompts.length,
              separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final q = _quickPrompts[i];
                return ScaleTap(
                  onPressed: () {
                    AppHaptics.step();
                    _textController.text = q;
                    _textController.selection = TextSelection.fromPosition(
                      TextPosition(offset: q.length),
                    );
                    _focusNode.requestFocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.chipBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.chipBorder),
                    ),
                    child: Text(
                      q,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Image Attachment Preview Chip (if selected)
          if (_selectedImagePath != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.chipBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.accent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(_selectedImagePath!),
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedImagePath!.split('/').last,
                                style: TextStyle(fontSize: 12, color: context.textPrimary, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Image attached • Ready to analyze',
                                style: TextStyle(fontSize: 10, color: context.accent, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ScaleTap(
                          onPressed: () {
                            AppHaptics.tap();
                            setState(() => _selectedImagePath = null);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: context.cardBorder,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, size: 14, color: context.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Input Bar: round(+) // space // round(input box + audio) // space // round(send button)
          Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset > 0 ? bottomInset + 6 : 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Center(
                      child: BouncyPressable(
                        onTap: () {
                          AppHaptics.warning();
                          ref.read(aiChatNotifierProvider.notifier).stopGeneration();
                        },
                        scaleDown: 0.93,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.isDark ? const Color(0xF2181C28) : Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.stop_rounded, size: 10, color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Stop Generating',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 1. round(+) button: Camera / Photo options
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: BouncyPressable(
                        onTap: _showAttachmentMenu,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _selectedImagePath != null
                                ? context.accent.withValues(alpha: 0.18)
                                : context.cardBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedImagePath != null
                                  ? context.accent
                                  : context.cardBorder,
                              width: _selectedImagePath != null ? 1.5 : 1.0,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.add_rounded,
                            color: _selectedImagePath != null
                                ? context.accent
                                : context.textPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. round(input box + audio)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _focusNode.hasFocus
                                ? context.accent.withValues(alpha: 0.55)
                                : context.cardBorder,
                            width: _focusNode.hasFocus ? 1.5 : 1.0,
                          ),
                          boxShadow: _focusNode.hasFocus
                              ? [
                                  BoxShadow(
                                    color: context.accent.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                focusNode: _focusNode,
                                minLines: 1,
                                maxLines: 5,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: _textSize.baseSize + 0.5,
                                  height: 1.4,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: _isListening
                                      ? '🎙 Listening...'
                                      : 'Message AI coach…',
                                  hintStyle: TextStyle(
                                    color: context.textTertiary,
                                    fontSize: _textSize.baseSize,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.fromLTRB(16, 11, 8, 11),
                                ),
                              ),
                            ),
                            // Mic button inside input pill
                            Padding(
                              padding: const EdgeInsets.only(right: 6, bottom: 6),
                              child: BouncyPressable(
                                onTap: _toggleListening,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: _isListening
                                        ? AppColors.error.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                    color: _isListening ? AppColors.error : context.textTertiary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 3. round(send button / stop button)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Builder(
                        builder: (context) {
                          final hasContent = _textController.text.trim().isNotEmpty || _selectedImagePath != null;
                          return BouncyPressable(
                            onTap: () {
                              if (isLoading) {
                                AppHaptics.warning();
                                ref.read(aiChatNotifierProvider.notifier).stopGeneration();
                                return;
                              }
                              if (!hasContent) return;
                              _handleSend();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isLoading
                                    ? const Color(0xFFEF4444)
                                    : (hasContent
                                        ? context.accent
                                        : (context.isDark ? const Color(0xFF1E212D) : const Color(0xFFE2E8F0))),
                                shape: BoxShape.circle,
                                boxShadow: (hasContent || isLoading)
                                    ? [
                                        BoxShadow(
                                          color: (isLoading ? const Color(0xFFEF4444) : context.accent).withValues(alpha: 0.28),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              alignment: Alignment.center,
                              child: isLoading
                                  ? const Icon(
                                      Icons.stop_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    )
                                  : Icon(
                                      Icons.arrow_upward_rounded,
                                      color: hasContent ? Colors.black : context.textTertiary,
                                      size: 20,
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

    final containerDecoration = BoxDecoration(
      color: context.sheetBg,
      borderRadius: widget.isFullScreen ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(24)),
      border: widget.isFullScreen ? null : Border(top: BorderSide(color: context.sheetBorder, width: 1.5)),
      boxShadow: widget.isFullScreen
          ? null
          : const [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
    );

    final mainContainer = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: widget.isFullScreen ? double.infinity : MediaQuery.of(context).size.height * _sheetHeight.factor,
      decoration: containerDecoration,
      child: SafeArea(
        top: widget.isFullScreen,
        bottom: true,
        child: sheetBody,
      ),
    );

    return Stack(
      children: [
        mainContainer,
        // History sidebar overlay
        if (_showHistorySidebar)
          GestureDetector(
            onTap: () => setState(() => _showHistorySidebar = false),
            child: Container(color: Colors.black45),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          right: _showHistorySidebar ? 0 : -320,
          top: 0,
          bottom: 0,
          width: 300,
          child: _buildHistorySidebar(),
        ),
      ],
    );
  }

  Widget _buildHistorySidebar() {
    final chatState = ref.watch(aiChatNotifierProvider);
    final sessions = chatState.sessions;
    final currentId = chatState.currentSessionId;
    final isLoadingSessions = chatState.isLoadingSessions;

    return Container(
      decoration: BoxDecoration(
        color: context.sheetBg,
        border: Border(left: BorderSide(color: context.sheetBorder, width: 1)),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(-4, 0)),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sidebar header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Conversations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: context.textSecondary, size: 20),
                    onPressed: () => setState(() => _showHistorySidebar = false),
                  ),
                ],
              ),
            ),
            // New Chat button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Chat'),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.accent,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () async {
                    setState(() => _showHistorySidebar = false);
                    await ref.read(aiChatNotifierProvider.notifier).startNewSession();
                    _scrollToBottom();
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            // Sessions list
            Expanded(
              child: isLoadingSessions
                  ? const Center(child: CircularProgressIndicator())
                  : sessions.isEmpty
                      ? Center(
                          child: Text(
                            'No past conversations',
                            style: TextStyle(color: context.textTertiary, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: sessions.length,
                          itemBuilder: (ctx, i) {
                            final session = sessions[i];
                            final isActive = session.id == currentId;
                            return Dismissible(
                              key: ValueKey(session.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: AppColors.error.withValues(alpha: 0.15),
                                child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                              ),
                              onDismissed: (_) {
                                ref.read(aiChatNotifierProvider.notifier).deleteSession(session.id);
                              },
                              child: InkWell(
                                onTap: () async {
                                  setState(() => _showHistorySidebar = false);
                                  await ref.read(aiChatNotifierProvider.notifier).switchToSession(session.id);
                                  _scrollToBottom();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isActive ? context.accent.withValues(alpha: 0.1) : Colors.transparent,
                                    border: isActive
                                        ? Border(left: BorderSide(color: context.accent, width: 3))
                                        : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                          color: isActive ? context.accent : context.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        session.previewText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11.5, color: context.textTertiary),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _formatSessionDate(session.lastMessageAt),
                                        style: TextStyle(fontSize: 10.5, color: context.textTertiary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSessionDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            AppHaptics.tap();
            onPressed();
          },
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, color: color ?? context.textSecondary, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderOverflowMenu() {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: context.isDark ? const Color(0xFF1E2638) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: context.isDark ? const Color(0x3364B5F6) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          elevation: 8,
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'More Options',
        padding: EdgeInsets.zero,
        icon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: context.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.accent.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.more_horiz_rounded, size: 16, color: context.accent),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down_rounded, size: 14, color: context.accent),
            ],
          ),
        ),
        onSelected: (value) {
          AppHaptics.selection();
          switch (value) {
            case 'size':
              _showSizeAdjustmentDialog();
              break;
            case 'history':
              ref.read(aiChatNotifierProvider.notifier).loadAllSessions();
              setState(() => _showHistorySidebar = true);
              break;
            case 'memories':
              _showMemoriesSheet();
              break;
            case 'settings':
              if (!widget.isFullScreen) Navigator.of(context).pop();
              context.go('/settings');
              break;
            case 'fullscreen':
              if (!widget.isFullScreen) {
                final nav = Navigator.of(context, rootNavigator: true);
                nav.pop();
                nav.push(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      backgroundColor: Colors.transparent,
                      body: AiAssistantSheet(isFullScreen: true),
                    ),
                  ),
                );
              } else {
                Navigator.of(context).pop();
              }
              break;
            case 'delete':
              _deleteCurrentChat();
              break;
          }
        },
        itemBuilder: (context) => [
          _buildPopupMenuItem(
            value: 'size',
            icon: Icons.format_size_rounded,
            label: 'Chat & Text Size',
            iconColor: context.accent,
          ),
          _buildPopupMenuItem(
            value: 'history',
            icon: Icons.history_rounded,
            label: 'Conversation History',
          ),
          _buildPopupMenuItem(
            value: 'memories',
            icon: Icons.psychology_rounded,
            label: 'Agent Memories',
            iconColor: context.accent,
          ),
          _buildPopupMenuItem(
            value: 'settings',
            icon: Icons.tune_rounded,
            label: 'AI Provider Settings',
          ),
          _buildPopupMenuItem(
            value: 'fullscreen',
            icon: widget.isFullScreen ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
            label: widget.isFullScreen ? 'Exit Full Screen' : 'Open Full Screen',
          ),
          const PopupMenuDivider(height: 8),
          _buildPopupMenuItem(
            value: 'delete',
            icon: Icons.delete_outline_rounded,
            label: 'Delete Conversation',
            iconColor: AppColors.error,
            textColor: AppColors.error,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required String label,
    Color? iconColor,
    Color? textColor,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: iconColor ?? context.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: textColor ?? context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF1E212D) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, I\'m ${_companion.name}!',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamilyDisplay,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your personal AI fitness coach & companion. Ask me to log push-ups, sports/games, barbell lifts, calculate warmups, or balance your muscle groups!',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _showCompanionSelector,
                child: Tooltip(
                  message: 'Tap to switch companion',
                  child: Image.asset(
                    _companion.assetPath,
                    width: 58,
                    height: 66,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Quick Prompts:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.textTertiary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickPrompts.take(6).map((q) {
            return ScaleTap(
              onPressed: () {
                AppHaptics.step();
                _textController.text = q;
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: q.length),
                );
                _focusNode.requestFocus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.chipBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.chipBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      q.contains('Push')
                          ? Icons.fitness_center_rounded
                          : (q.contains('Football')
                              ? Icons.sports_soccer_rounded
                              : (q.contains('warmup')
                                  ? Icons.whatshot_rounded
                                  : (q.contains('balance')
                                      ? Icons.balance_rounded
                                      : Icons.bolt_rounded))),
                      size: 14,
                      color: context.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      q,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(AiChatMessage msg) {
    final isUser = msg.role == 'user';
    final hasContent = msg.content.trim().isNotEmpty;
    final isStreaming = msg.isStreaming;

    final thoughtSteps = msg.thoughtSteps ?? [];
    final activeThought = msg.liveToolStatus ?? msg.liveThinking;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Assistant Companion Header Avatar
          if (!isUser) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 5, left: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    _companion.assetPath,
                    width: 18,
                    height: 20,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _companion.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // ── Agent Thoughts (Tool Calls Lively Animated in Text) ───────
          if (!isUser && (thoughtSteps.isNotEmpty || (isStreaming && activeThought != null)))
            _AgentThoughtsWidget(
              thoughts: thoughtSteps,
              isStreaming: isStreaming,
              activeThought: activeThought,
              hasContent: hasContent,
            ),

          // Attached Image in Chat Timeline (if any)
          if (msg.imageAttachmentPath != null && msg.imageAttachmentPath!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
                maxHeight: 220,
              ),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.cardBorder, width: 1.2),
              ),
              child: Image.file(
                File(msg.imageAttachmentPath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ],

          // Content (only shown when text has actually arrived)
          if (hasContent) ...[
            GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                AppHaptics.success();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isUser ? 'Prompt copied to clipboard' : 'Response copied to clipboard',
                      style: const TextStyle(fontSize: 12),
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    width: 220,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              },
              child: _buildBubbleContent(
                msg: msg,
                isUser: isUser,
              ),
            ),

            // Copy Action under User Bubbles
            if (isUser)
              Padding(
                padding: const EdgeInsets.only(right: 4, top: 3),
                child: BouncyPressable(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg.content));
                    AppHaptics.tap();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Prompt copied to clipboard', style: TextStyle(fontSize: 12)),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        width: 220,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 11, color: context.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          'Copy prompt',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Copy Action under Assistant Bubbles (only when completed)
            if (!isUser && hasContent && !isStreaming)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 3),
                child: BouncyPressable(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg.content));
                    AppHaptics.tap();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Response copied to clipboard', style: TextStyle(fontSize: 12)),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        width: 220,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 11, color: context.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],

          // ── Workout Deletion Confirmation Card (Interactive In-Chat) ─────────
          if (!isUser && msg.toolResults != null)
            for (final tr in msg.toolResults!)
              if (tr.toolName == 'delete_workout')
                _WorkoutDeletionCard(
                  result: tr,
                  onAllow: () => _handleConfirmDeleteWorkout(msg, tr),
                  onReject: () => _handleCancelDeleteWorkout(msg, tr),
                ),

          // ── Agent Question Card (Interactive In-Chat) ───────────────────────
          if (!isUser && msg.toolResults != null)
            for (final tr in msg.toolResults!)
              if (tr.toolName == 'ask_user_question')
                _AgentQuestionCard(
                  result: tr,
                  onAnswer: (opt) => _handleAnswerQuestion(msg, tr, opt),
                ),

          // ── Memory Saved Badge (Interactive In-Chat) ───────────────────────
          if (!isUser && msg.toolResults != null)
            for (final tr in msg.toolResults!)
              if (tr.toolName == 'save_user_memory' && tr.success)
                _MemorySavedBadge(
                  fact: tr.data['fact']?.toString() ?? tr.summary,
                  category: tr.data['category']?.toString(),
                ),

          // ── Preset Preview Card (Interactive In-Chat) ───────────────────────
          if (!isUser && msg.toolResults != null)
            for (final tr in msg.toolResults!)
              if (tr.toolName == 'preview_preset' && tr.data != null && tr.data is Map)
                _PresetPreviewCard(
                  data: Map<String, dynamic>.from(tr.data as Map),
                  onImport: (title, category, exercises) => _handleImportPreset(title, category, exercises),
                  onStartNow: (title, exercises) => _handleStartPresetWorkout(title, exercises),
                  onAskChanges: (prompt) => _handleAskPresetChanges(prompt),
                ),

          // ── Multi-Exercise Visuals Gallery (Interactive In-Chat) ─────────────
          if (!isUser && msg.toolResults != null)
            for (final tr in msg.toolResults!)
              if (tr.toolName == 'get_multiple_exercise_images' && tr.data != null && tr.data is Map)
                _MultiExerciseVisualsCard(
                  data: Map<String, dynamic>.from(tr.data as Map),
                  onAskExercise: (exName) => _handleAskAboutExercise(exName),
                ),

          // ── Visual Diagram & Flowchart Card (Interactive In-Chat) ───────────
          if (!isUser && msg.toolResults != null)
            for (final tr in msg.toolResults!)
              if (tr.toolName == 'render_visual_diagram' && tr.data != null && tr.data is Map)
                _VisualDiagramCard(
                  data: Map<String, dynamic>.from(tr.data as Map),
                ),

          // ── Progression Chart Card (Interactive In-Chat) ────────────────────
          if (!isUser && msg.toolResults != null)
            for (final tr in msg.toolResults!)
              if (tr.toolName == 'render_progression_chart' && tr.data != null && tr.data is Map)
                _ProgressionChartCard(
                  data: Map<String, dynamic>.from(tr.data as Map),
                ),

          // ── PR History & Milestone Showcase Card (Interactive In-Chat) ───────
          if (!isUser && msg.toolResults != null)
            for (final tr in msg.toolResults!)
              if (tr.toolName == 'visualize_pr_history' && tr.data != null && tr.data is Map)
                _PrHistoryMilestoneCard(
                  data: Map<String, dynamic>.from(tr.data as Map),
                  companion: _companion,
                  onAskBreakPr: (prompt) => _handleSend(prompt),
                ),
        ],
      ),
    );
  }

  Widget _buildBubbleContent({
    required AiChatMessage msg,
    required bool isUser,
  }) {
    // 1. User Message (Pill bubble on the right)
    if (isUser) {
      return Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.84),
        padding: EdgeInsets.symmetric(horizontal: 14 * _textSize.scale, vertical: 10 * _textSize.scale),
        decoration: BoxDecoration(
          color: context.accent,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: _buildFormattedMarkdown(
          msg.content,
          isUser: true,
          isStreaming: false,
        ),
      );
    }

    // 2. Error Message
    if (msg.isError) {
      return Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFormattedMarkdown(
              msg.content,
              isUser: false,
              isStreaming: false,
            ),
            const SizedBox(height: 10),
            ScaleTap(
              onPressed: () {
                ref.read(aiChatNotifierProvider.notifier).retryLastMessage();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 15,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Retry Response',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 3. AI Assistant Response (Clean unboxed layout without gray container/border, like ChatGPT mobile)
    final content = _buildFormattedMarkdown(
      msg.content,
      isUser: false,
      isStreaming: false,
    );

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.94),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topLeft,
        child: msg.isStreaming
            ? _ChatGptStreamingSentenceFade(child: content)
            : content,
      ),
    );
  }

  Widget _buildFormattedMarkdown(
    String text, {
    required bool isUser,
    bool isStreaming = false,
  }) {
    // If the message contains a ```mermaid block, parse and render as interactive visual flowchart
    final mermaidRegex = RegExp(r'```(?:mermaid)?\s*([\s\S]*?(?:graph|flowchart)\s+(?:TD|LR|TB|BT|RL)[\s\S]*?)```', caseSensitive: false);
    if (!isUser && mermaidRegex.hasMatch(text)) {
      final matches = mermaidRegex.allMatches(text).toList();
      final List<Widget> children = [];
      int lastIndex = 0;

      for (final match in matches) {
        if (match.start > lastIndex) {
          final chunk = text.substring(lastIndex, match.start).trim();
          if (chunk.isNotEmpty) {
            children.add(_buildMarkdownBodyOnly(chunk, isUser: isUser));
          }
        }

        final mermaidContent = match.group(1)?.trim() ?? '';
        if (mermaidContent.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _MermaidDiagramNativeCard(mermaidCode: mermaidContent),
            ),
          );
        }

        lastIndex = match.end;
      }

      if (lastIndex < text.length) {
        final remaining = text.substring(lastIndex).trim();
        if (remaining.isNotEmpty) {
          children.add(_buildMarkdownBodyOnly(remaining, isUser: isUser));
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }

    return _buildMarkdownBodyOnly(text, isUser: isUser);
  }

  Widget _buildMarkdownBodyOnly(String text, {required bool isUser}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MarkdownBody(
          data: text,
          selectable: false,
          sizedImageBuilder: (config) {
            return _InlineChatExerciseImage(
              imageUrl: config.uri.toString(),
              title: config.title,
              altText: config.alt,
            );
          },
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              fontFamily: 'Inter',
              fontSize: _textSize.baseSize,
              height: 1.45,
              color: isUser ? Colors.black : context.textPrimary,
              fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
            ),
            strong: TextStyle(
              fontFamily: 'Inter',
              fontSize: _textSize.baseSize,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: isUser ? Colors.black : context.textPrimary,
            ),
            em: TextStyle(
              fontFamily: 'Inter',
              fontSize: _textSize.baseSize,
              fontStyle: FontStyle.italic,
              color: isUser ? Colors.black87 : context.textSecondary,
            ),
            h1: TextStyle(
              fontFamily: 'Inter',
              fontSize: _textSize.baseSize + 3.0,
              fontWeight: FontWeight.w800,
              color: isUser ? Colors.black : context.textPrimary,
            ),
            h2: TextStyle(
              fontFamily: 'Inter',
              fontSize: _textSize.baseSize + 2.0,
              fontWeight: FontWeight.w700,
              color: isUser ? Colors.black : context.textPrimary,
            ),
            h3: TextStyle(
              fontFamily: 'Inter',
              fontSize: _textSize.baseSize + 1.0,
              fontWeight: FontWeight.w700,
              color: isUser ? Colors.black : context.textPrimary,
            ),
            listBullet: TextStyle(
              fontSize: _textSize.baseSize,
              fontWeight: FontWeight.w700,
              color: isUser ? Colors.black : context.accent,
            ),
            tableHead: TextStyle(
              fontFamily: 'Inter',
              fontSize: (_textSize.baseSize - 1.5).clamp(10.0, 20.0),
              fontWeight: FontWeight.w700,
              color: isUser ? Colors.black : context.accent,
            ),
            tableBody: TextStyle(
              fontFamily: 'Inter',
              fontSize: (_textSize.baseSize - 1.5).clamp(10.0, 20.0),
              color: isUser ? Colors.black : context.textPrimary,
            ),
            tableBorder: TableBorder.all(
              color: context.isDark ? const Color(0x3364B5F6) : const Color(0x331976D2),
              width: 1,
            ),
            tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            code: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: isUser ? Colors.black87 : context.accent,
              backgroundColor: context.isDark ? const Color(0x33000000) : const Color(0x1A000000),
            ),
            codeblockPadding: const EdgeInsets.all(8),
            codeblockDecoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF11141D) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8),
            ),
            blockquote: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: context.textSecondary,
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(left: BorderSide(color: context.accent, width: 3)),
            ),
            blockquotePadding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
          ),
        ),
      ],
    );
  }

  Future<void> _handleConfirmDeleteWorkout(AiChatMessage msg, AiToolExecutionResult tr) async {
    AppHaptics.warning();
    await ref.read(aiChatNotifierProvider.notifier).handleConfirmDeleteWorkout(msg, tr);
  }

  void _handleCancelDeleteWorkout(AiChatMessage msg, AiToolExecutionResult tr) {
    AppHaptics.tap();
    ref.read(aiChatNotifierProvider.notifier).handleCancelDeleteWorkout(msg, tr);
  }

  void _handleAnswerQuestion(AiChatMessage msg, AiToolExecutionResult tr, String chosenOption) {
    AppHaptics.tap();
    ref.read(aiChatNotifierProvider.notifier).handleAnswerQuestion(msg, tr, chosenOption);
    _scrollToBottom();
  }

  Future<void> _handleImportPreset(String title, String category, List<String> exerciseNames) async {
    AppHaptics.success();
    final exRepo = ref.read(exerciseRepositoryProvider);
    final routineRepo = ref.read(routineRepositoryProvider);
    final allEx = await exRepo.getExercises();

    final matchedIds = <String>[];
    for (final rawName in exerciseNames) {
      final clean = rawName.trim();
      if (clean.isEmpty) continue;
      final found = allEx.where((e) => e.name.toLowerCase() == clean.toLowerCase()).firstOrNull;
      if (found != null) {
        matchedIds.add(found.id);
      } else {
        final created = await exRepo.createCustomExercise(
          name: clean,
          muscleGroupId: 'chest',
          equipment: EquipmentType.barbell,
        );
        matchedIds.add(created.id);
      }
    }

    await routineRepo.createRoutine(
      name: title,
      description: category,
      exerciseIds: matchedIds,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Preset "$title" saved to your Routine Library!')),
            ],
          ),
          backgroundColor: AppColors.workingSet,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleStartPresetWorkout(String title, List<String> exerciseNames) async {
    AppHaptics.save();
    final exRepo = ref.read(exerciseRepositoryProvider);
    final workoutRepo = ref.read(workoutRepositoryProvider);
    final allEx = await exRepo.getExercises();

    final todayWorkout = await workoutRepo.getOrCreateTodayWorkout();
    await workoutRepo.startWorkout(todayWorkout.id);

    for (final rawName in exerciseNames) {
      final clean = rawName.trim();
      if (clean.isEmpty) continue;
      var found = allEx.where((e) => e.name.toLowerCase() == clean.toLowerCase()).firstOrNull;
      found ??= await exRepo.createCustomExercise(
        name: clean,
        muscleGroupId: 'chest',
        equipment: EquipmentType.barbell,
      );
      await workoutRepo.addExerciseToWorkout(workoutId: todayWorkout.id, exerciseId: found.id);
    }

    if (mounted) {
      Navigator.pop(context);
      context.go('/today');
    }
  }

  void _handleAskPresetChanges(String prompt) {
    _handleSend(prompt);
  }

  void _handleAskAboutExercise(String exerciseName) {
    _handleSend('Can you explain proper form cues, muscle targets, and tips for $exerciseName?');
  }

  Widget _buildStickyPresetBar(Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? 'Workout Routine';
    final rawExercises = data['exercises'] as List? ?? [];
    final exerciseNames = rawExercises
        .whereType<Map>()
        .map((e) => e['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    final category = data['category']?.toString() ?? 'Hypertrophy';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xF2161A26) : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.accent.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.accent.withValues(alpha: context.isDark ? 0.22 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bolt_rounded, size: 16, color: context.accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: context.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${exerciseNames.length} moves',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: context.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'AI coach routine ready • Launch or save',
                  style: TextStyle(
                    fontSize: 10,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Start Button
          ScaleTap(
            onPressed: () => _handleStartPresetWorkout(title, exerciseNames),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.accent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: context.accent.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 2),
                  Text(
                    'Start',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Save Button
          ScaleTap(
            onPressed: () => _handleImportPreset(title, category, exerciseNames),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: context.chipBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.chipBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_add_outlined, size: 13, color: context.textPrimary),
                  const SizedBox(width: 2),
                  Text(
                    'Save',
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
          const SizedBox(width: 2),
          // Dismiss
          ScaleTap(
            onPressed: () {
              AppHaptics.tap();
              setState(() => _dismissedPresetTitle = title);
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 16, color: context.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Preset Preview & Workout Deletion Cards (Extracted to ai/ai_preset_preview_card.dart) ──
typedef _PresetPreviewCard = PresetPreviewCard;
typedef _WorkoutDeletionCard = WorkoutDeletionCard;

// ── Agent Question Card (Extracted to ai/ai_agent_question_card.dart) ──
typedef _AgentQuestionCard = AgentQuestionCard;

// ── Agent Thinking & Animation Views (Extracted to ai/ai_thinking_views.dart) ──
typedef _AgentThoughtsWidget = AgentThoughtsWidget;
typedef _ChatGptStreamingSentenceFade = ChatGptStreamingSentenceFade;

// ── Inline Chat Exercise Image (Extracted to ai/ai_inline_chat_image.dart) ───
typedef _InlineChatExerciseImage = InlineChatExerciseImage;

// ── Agent Memories Sheet & Badge (Extracted to ai/ai_memories_sheet.dart) ──
typedef _MemorySavedBadge = MemorySavedBadge;
typedef _ManageMemoriesSheet = ManageMemoriesSheet;

// ── Multi-Exercise Visuals Gallery (Extracted to ai/ai_progression_chart_card.dart) ──
typedef _MultiExerciseVisualsCard = MultiExerciseVisualsCard;

// ── Flowchart & Visual Diagram Engine (Extracted to ai/mermaid_flowchart_*.dart) ──
typedef _VisualDiagramCard = VisualDiagramCard;

// ── Progression Chart Card (Extracted to ai/ai_progression_chart_card.dart) ──
typedef _ProgressionChartCard = ProgressionChartCard;
typedef _MermaidDiagramNativeCard = MermaidDiagramNativeCard;

// ── Personal Record Milestone Showcase (Extracted to ai/ai_pr_history_card.dart) ──
typedef _PrHistoryMilestoneCard = PrHistoryMilestoneCard;
