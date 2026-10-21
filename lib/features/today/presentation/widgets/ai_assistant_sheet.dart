import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../core/widgets/bouncy_pressable.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../domain/models/ai_chat_message.dart';
import '../../../../domain/models/ai_config_model.dart';
import '../../../../domain/models/ai_memory_model.dart';
import '../../../../domain/models/chibi_avatar_model.dart';
import '../../../../domain/services/ai_assistant_service.dart';
import '../../../../domain/services/ai_chat_notifier.dart';
import '../../../../domain/services/ai_memory_service.dart';
import '../../../../domain/services/weight_step_learner.dart';
import '../../../../domain/services/exercise_media_service.dart';
import '../../../../data/providers.dart';

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

// ── Preset Preview Card (Interactive In-Chat UI) ───────────────────────────
class _PresetPreviewCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  final Function(String title, String category, List<String> exerciseNames) onImport;
  final Function(String title, List<String> exerciseNames) onStartNow;
  final Function(String prompt) onAskChanges;

  const _PresetPreviewCard({
    required this.data,
    required this.onImport,
    required this.onStartNow,
    required this.onAskChanges,
  });

  @override
  ConsumerState<_PresetPreviewCard> createState() => _PresetPreviewCardState();
}

class _PresetPreviewCardState extends ConsumerState<_PresetPreviewCard> {
  bool _isImported = false;
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title']?.toString() ?? 'Workout Preset';
    final category = widget.data['category']?.toString() ?? 'Hypertrophy';
    final description = widget.data['description']?.toString() ?? '';
    final rawExercises = widget.data['exercises'] as List? ?? [];
    final exercises = rawExercises.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final exerciseNames = exercises.map((e) => e['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.accent.withValues(alpha: isDark ? 0.45 : 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.accent.withValues(alpha: isDark ? 0.16 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.accent.withValues(alpha: 0.4)),
                  ),
                  child: Icon(Icons.fitness_center_rounded, color: context.accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: context.accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${exercises.length} movements • Recommended Split',
                        style: TextStyle(fontSize: 11, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20),
                  color: context.textTertiary,
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
          ),

          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Text(
                description,
                style: TextStyle(fontSize: 12, color: context.textSecondary, height: 1.35),
              ),
            ),

          const Divider(height: 16, thickness: 0.6),

          // Exercise List (if expanded)
          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: exercises.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final ex = entry.value;
                  final name = ex['name']?.toString() ?? 'Exercise';
                  final sets = ex['targetSets'] ?? 3;
                  final reps = ex['targetReps']?.toString() ?? '8-12';
                  final rest = ex['restSeconds'] ?? 90;
                  final notes = ex['notes']?.toString();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF171A24) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.cardBorder, width: 0.7),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: context.accent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$idx',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: context.accent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.chipBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$sets sets × $reps',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.chipBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${rest}s',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (notes != null && notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              '💡 $notes',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textTertiary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Quick Preset Customization Chips ("Ask for Changes")
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask AI for changes to this preset:',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: context.textTertiary),
                ),
                const SizedBox(height: 5),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChangeChip('Swap an exercise', () => widget.onAskChanges('Can you swap one of the exercises in "$title"? Give me alternative options.')),
                      const SizedBox(width: 6),
                      _buildChangeChip('Higher volume (+sets)', () => widget.onAskChanges('Make "$title" higher volume with 4-5 sets per exercise.')),
                      const SizedBox(width: 6),
                      _buildChangeChip('Dumbbell only', () => widget.onAskChanges('Modify "$title" to use only dumbbells and bodyweight.')),
                      const SizedBox(width: 6),
                      _buildChangeChip('Shorten to 40 min', () => widget.onAskChanges('Streamline "$title" so it can be completed in under 40 minutes.')),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Primary Actions: Import / Start Today
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13151D) : const Color(0xFFEAEFF6),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => widget.onStartNow(title, exerciseNames),
                    icon: Icon(Icons.play_arrow_rounded, size: 18, color: context.accent),
                    label: Text(
                      'Start Today',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isImported ? AppColors.workingSet : context.accent,
                      foregroundColor: context.onAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _isImported
                        ? null
                        : () async {
                            await widget.onImport(title, category, exerciseNames);
                            setState(() => _isImported = true);
                          },
                    icon: Icon(
                      _isImported ? Icons.check_circle_rounded : Icons.bookmark_add_rounded,
                      size: 17,
                    ),
                    label: Text(
                      _isImported ? 'Saved!' : 'Save Preset',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
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

  Widget _buildChangeChip(String label, VoidCallback onTap) {
    return ScaleTap(
      onPressed: () {
        AppHaptics.step();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E212D)
              : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2E3344)
                : const Color(0xFFDCE2EE),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 11, color: context.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Workout Deletion Confirmation Card (In-Chat UI) ────────────────────────
class _WorkoutDeletionCard extends StatelessWidget {
  final AiToolExecutionResult result;
  final VoidCallback onAllow;
  final VoidCallback onReject;

  const _WorkoutDeletionCard({
    required this.result,
    required this.onAllow,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final status = result.data?['status']?.toString() ?? '';
    final isPending = status == 'pending_confirmation';
    final isDeleted = status == 'deleted';
    final isCancelled = status == 'cancelled';

    if (isDeleted) {
      final title = result.data?['workoutTitle']?.toString() ?? 'Workout';
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1E212D) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.workingSet),
            const SizedBox(width: 7),
            Text(
              'Workout "$title" deleted',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (isCancelled) {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1E212D) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, size: 14, color: context.textTertiary),
            const SizedBox(width: 7),
            Text(
              'Workout deletion rejected — kept session',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    if (!isPending) return const SizedBox.shrink();

    final message = result.data?['message']?.toString() ??
        'The AI assistant is requesting to permanently delete this workout session. All logged exercises and sets will be removed.';

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  size: 16,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Delete Workout Request',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 1.4,
              color: context.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: context.textSecondary,
                  side: BorderSide(
                    color: context.isDark ? const Color(0x33FFFFFF) : const Color(0xFFCBD5E1),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                ),
                onPressed: onReject,
                child: const Text(
                  'Reject',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                ),
                icon: const Icon(Icons.delete_forever_rounded, size: 14),
                label: const Text(
                  'Allow Delete',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: onAllow,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Agent Question Card (Interactive In-Chat UI) ──────────────────────────
class _AgentQuestionCard extends StatefulWidget {
  final AiToolExecutionResult result;
  final Function(String option) onAnswer;

  const _AgentQuestionCard({
    required this.result,
    required this.onAnswer,
  });

  @override
  State<_AgentQuestionCard> createState() => _AgentQuestionCardState();
}

class _AgentQuestionCardState extends State<_AgentQuestionCard> {
  final TextEditingController _customController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _submitCustom() {
    final text = _customController.text.trim();
    if (text.isNotEmpty) {
      widget.onAnswer(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.result.data?['question']?.toString() ?? 'Question';
    final summary = widget.result.data?['summary']?.toString();
    final optionsRaw = widget.result.data?['options'] as List?;
    final options = optionsRaw?.map((e) => e.toString()).toList() ?? [];
    final selectedOption = widget.result.data?['selectedOption']?.toString();
    final isAnswered = selectedOption != null;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.94),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF161B26) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.isDark ? const Color(0x3364B5F6) : const Color(0xFF90CAF9),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  size: 15,
                  color: context.accent,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Coach Question',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              // Copy Question Action
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 14, color: context.textTertiary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Copy question',
                onPressed: () {
                  final textToCopy = '${summary != null && summary.isNotEmpty ? "$summary\n\n" : ""}$question\nOptions: ${options.join(', ')}';
                  Clipboard.setData(ClipboardData(text: textToCopy));
                  AppHaptics.tap();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Question copied to clipboard', style: TextStyle(fontSize: 12)),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      width: 220,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
              ),
            ],
          ),

          // Context Summary ("What is what")
          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.isDark ? const Color(0xFF0F131C) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.isDark ? const Color(0x1FFFFFFF) : const Color(0x1F000000),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: context.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      summary,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        height: 1.35,
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          Text(
            question,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.38,
              color: context.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          // Option choices - handles both long sentences (full-width) & short tags without any overflow
          if (options.any((o) => o.length > 22)) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final opt in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: BouncyPressable(
                      onTap: isAnswered ? null : () => widget.onAnswer(opt),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                        decoration: BoxDecoration(
                          color: selectedOption == opt
                              ? context.accent
                              : (context.isDark ? const Color(0xFF1E2433) : Colors.white),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedOption == opt
                                ? context.accent
                                : (context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFCBD5E1)),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (selectedOption == opt) ...[
                              const Icon(Icons.check_circle_rounded, size: 15, color: Colors.black),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                opt,
                                softWrap: true,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: selectedOption == opt
                                      ? Colors.black
                                      : context.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (isAnswered && !options.contains(selectedOption))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                      decoration: BoxDecoration(
                        color: context.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 15, color: Colors.black),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedOption,
                              softWrap: true,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final opt in options)
                  BouncyPressable(
                    onTap: isAnswered ? null : () => widget.onAnswer(opt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: selectedOption == opt
                            ? context.accent
                            : (context.isDark ? const Color(0xFF1E2433) : Colors.white),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selectedOption == opt
                              ? context.accent
                              : (context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFCBD5E1)),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selectedOption == opt) ...[
                            const Icon(Icons.check_rounded, size: 13, color: Colors.black),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              opt,
                              softWrap: true,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selectedOption == opt
                                    ? Colors.black
                                    : context.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isAnswered && !options.contains(selectedOption))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: context.accent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded, size: 13, color: Colors.black),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            selectedOption,
                            softWrap: true,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          // Custom Write-In Option when not answered
          if (!isAnswered) ...[
            const SizedBox(height: 8),
            if (!_showCustomInput)
              BouncyPressable(
                onTap: () {
                  AppHaptics.tap();
                  setState(() => _showCustomInput = true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0x15FFFFFF) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note_rounded, size: 14, color: context.accent),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Write custom answer...',
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: context.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.isDark ? const Color(0xFF0F131C) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.accent, width: 1.2),
                      ),
                      child: TextField(
                        controller: _customController,
                        autofocus: true,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: context.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type your custom response...',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            color: context.textTertiary,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _submitCustom(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  BouncyPressable(
                    onTap: _submitCustom,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_upward_rounded, size: 18, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

// ── Agent Thoughts Widget (Tool Calls Shown Lively as Thinking Stuffs) ─────
class _AgentThoughtsWidget extends StatefulWidget {
  final List<String> thoughts;
  final bool isStreaming;
  final String? activeThought;
  final bool hasContent;

  const _AgentThoughtsWidget({
    required this.thoughts,
    required this.isStreaming,
    this.activeThought,
    this.hasContent = false,
  });

  @override
  State<_AgentThoughtsWidget> createState() => _AgentThoughtsWidgetState();
}

class _AgentThoughtsWidgetState extends State<_AgentThoughtsWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isStreaming = widget.isStreaming;
    final active = widget.activeThought;
    final allThoughts = widget.thoughts;
    final hasContent = widget.hasContent;

    // While streaming: show up to 3 tool calls newest down bounded by top/bottom dark fade, then thinking
    if (isStreaming) {
      final String thinkingLine;
      if (active != null && active.isNotEmpty && (allThoughts.isEmpty || allThoughts.last != active)) {
        thinkingLine = active;
      } else {
        thinkingLine = 'Thinking...';
      }

      return Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // <fade dark out> 3 toolcalls show newest down <fade dark out>
            if (allThoughts.isNotEmpty)
              _FadingToolCallsCarousel(toolCalls: allThoughts),

            // <thinking stuffs>
            if (!hasContent) ...[
              if (allThoughts.isNotEmpty) const SizedBox(height: 5),
              _WaveringShimmerText(thinkingLine),
            ],
          ],
        ),
      );
    }

    // When done streaming: show collapsible thoughts header if there were steps
    if (allThoughts.isEmpty) return const SizedBox.shrink();

    final count = allThoughts.length;
    final summaryLabel = count == 1 ? '1 tool action completed' : '$count tool actions completed';

    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Borderless, minimal click-to-expand header
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              AppHaptics.tap();
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: context.accent.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    summaryLabel,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: context.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded thoughts list using borderless fading carousel
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _FadingToolCallsCarousel(
                toolCalls: allThoughts,
                showAll: true,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Fading Tool Calls Carousel (Borderless, Top/Bottom Fade, Auto-Scroll Up) ──
/// Displays tool calls (newest at bottom) without any boxy containers or borders.
/// Shows up to 3 items in a vertical viewport bounded by top & bottom fade-out shades.
/// Automatically scrolls older items up into the top fade when new tool calls arrive.
class _FadingToolCallsCarousel extends StatefulWidget {
  final List<String> toolCalls;
  final bool showAll;

  const _FadingToolCallsCarousel({
    required this.toolCalls,
    this.showAll = false,
  });

  @override
  State<_FadingToolCallsCarousel> createState() => _FadingToolCallsCarouselState();
}

class _FadingToolCallsCarouselState extends State<_FadingToolCallsCarousel> {
  final ScrollController _scrollController = ScrollController();
  static const double _itemHeight = 24.0;
  static const double _verticalPad = 4.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _FadingToolCallsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.toolCalls.length != oldWidget.toolCalls.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.toolCalls.isEmpty) return const SizedBox.shrink();

    final count = widget.toolCalls.length;
    final visibleCount = widget.showAll ? count.clamp(1, 8) : count.clamp(1, 3);
    final viewportHeight = (visibleCount * _itemHeight) + (_verticalPad * 2);
    final hasOverflow = count > 3 || (widget.showAll && count > 8);

    return SizedBox(
      height: viewportHeight,
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          if (!hasOverflow && count <= 2) {
            return const LinearGradient(
              colors: [Colors.black, Colors.black],
            ).createShader(bounds);
          }
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.16, 0.86, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: _scrollController,
          physics: widget.showAll
              ? const BouncingScrollPhysics()
              : const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: _verticalPad),
          itemCount: count,
          itemExtent: _itemHeight,
          itemBuilder: (context, index) {
            final isLatest = index == count - 1;
            final isExecuting = isLatest && widget.toolCalls[index].endsWith('...');

            return SizedBox(
              height: _itemHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    isExecuting
                        ? Icons.motion_photos_on_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 13,
                    color: isExecuting
                        ? context.accent
                        : context.accent.withValues(alpha: isLatest ? 0.95 : 0.65),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.toolCalls[index],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: isLatest ? context.textSecondary : context.textTertiary,
                        fontWeight: isLatest ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Wavering Shimmer Text (Animation IN the Text Itself) ───────────────────
/// Smooth traveling light-wave animation sweeping across characters of the text itself.
class _WaveringShimmerText extends StatefulWidget {
  final String text;

  const _WaveringShimmerText(this.text);

  @override
  State<_WaveringShimmerText> createState() => _WaveringShimmerTextState();
}

class _WaveringShimmerTextState extends State<_WaveringShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF8E9BAE) : const Color(0xFF64748B);
    final highlightColor = isDark ? const Color(0xFF90CAF9) : const Color(0xFF1976D2);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final v = _ctrl.value;
        final startX = -1.2 + (v * 2.4);
        final endX = startX + 0.85;

        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(startX, 0),
              end: Alignment(endX, 0),
              colors: [
                baseColor,
                baseColor,
                highlightColor,
                baseColor,
                baseColor,
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Text(
        widget.text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

// ── ChatGPT-Style Sentence Drop Streaming Fade ─────────────────────────────

/// Soft vertical fade on the bottom trailing edge of the streaming response.
/// Previous sentences are 100% crisp and solid; the newest incoming sentence at the bottom
/// emerges softly from a subtle dimmed gradient and illuminates as it completes.
class _ChatGptStreamingSentenceFade extends StatefulWidget {
  final Widget child;

  const _ChatGptStreamingSentenceFade({
    required this.child,
  });

  @override
  State<_ChatGptStreamingSentenceFade> createState() =>
      _ChatGptStreamingSentenceFadeState();
}

class _ChatGptStreamingSentenceFadeState
    extends State<_ChatGptStreamingSentenceFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final shimmerGlow = 0.55 + (_ctrl.value * 0.35); // 0.55 -> 0.90
        final trailingGlow = 0.38 + (_ctrl.value * 0.22); // 0.38 -> 0.60

        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (Rect bounds) {
            // Keep everything above the last sentence at 100% solid opacity
            final fadeHeight = (bounds.height * 0.40).clamp(24.0, 56.0);
            final fadeStart = (bounds.height <= fadeHeight)
                ? 0.0
                : (bounds.height - fadeHeight) / bounds.height;

            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.white,
                Colors.white.withValues(alpha: shimmerGlow),
                Colors.white.withValues(alpha: trailingGlow),
              ],
              stops: [
                0.0,
                fadeStart,
                (fadeStart + (1.0 - fadeStart) * 0.55).clamp(0.0, 0.95),
                1.0,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ── Inline Chat Exercise Image (with Shimmer Loading & Tap to Enlarge) ───────
class _InlineChatExerciseImage extends StatelessWidget {
  final String imageUrl;
  final String? title;
  final String? altText;

  const _InlineChatExerciseImage({
    required this.imageUrl,
    this.title,
    this.altText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayLabel = (altText != null && altText!.isNotEmpty)
        ? altText!
        : (title != null && title!.isNotEmpty ? title! : 'Exercise Form');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () {
          AppHaptics.tap();
          _showFullScreenImage(context, imageUrl, displayLabel);
        },
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 420,
            maxHeight: 220,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141722) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (imageUrl.startsWith('assets/'))
                Image.asset(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                )
              else
                Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return ShimmerLoading(
                      width: double.infinity,
                      height: 200,
                      borderRadius: BorderRadius.circular(14),
                      label: 'Loading $displayLabel...',
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    final local = ExerciseMediaService.getVerifiedMedia(displayLabel);
                    if (local != null) {
                      return Image.asset(
                        local.source,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      );
                    }
                    return Container(
                      width: double.infinity,
                      height: 120,
                      padding: const EdgeInsets.all(12),
                      color: isDark ? const Color(0xFF161924) : const Color(0xFFE2E8F0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fitness_center_rounded, size: 22, color: context.accent),
                          const SizedBox(height: 6),
                          Text(
                            displayLabel,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              // Bottom Pill Tag Badge
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fit_screen_rounded,
                        size: 11,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          displayLabel,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFullScreenImage(BuildContext context, String url, String label) async {
    // Unfocus any active focus in the sheet before opening the dialog
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
    FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.scope);

    await showDialog(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                clipBehavior: Clip.none,
                minScale: 0.8,
                maxScale: 3.5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: url.startsWith('assets/')
                      ? Image.asset(url, fit: BoxFit.contain)
                      : Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (c, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          },
                          errorBuilder: (c, e, s) {
                            final local = ExerciseMediaService.getVerifiedMedia(label);
                            if (local != null) {
                              return Image.asset(local.source, fit: BoxFit.contain);
                            }
                            return const Center(
                              child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.white54),
                            );
                          },
                        ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  onPressed: () {
                    FocusScope.of(ctx).unfocus(disposition: UnfocusDisposition.scope);
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    // After exiting the dialog, ensure input field does not auto-focus and trigger keyboard
    if (context.mounted) {
      FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
      FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.scope);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
          FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.scope);
        }
      });
    }
  }
}

// ── In-Chat Badge When Memory is Persisted ────────────────────────────────────
class _MemorySavedBadge extends StatelessWidget {
  final String fact;
  final String? category;

  const _MemorySavedBadge({
    required this.fact,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4, left: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.psychology_rounded, size: 14, color: context.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '🧠 Remembered: "$fact"',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Manage Memories Sheet (Modal UI) ──────────────────────────────────────────
class _ManageMemoriesSheet extends ConsumerStatefulWidget {
  final String companionName;

  const _ManageMemoriesSheet({
    required this.companionName,
  });

  @override
  ConsumerState<_ManageMemoriesSheet> createState() => _ManageMemoriesSheetState();
}

class _ManageMemoriesSheetState extends ConsumerState<_ManageMemoriesSheet> {
  final TextEditingController _addController = TextEditingController();
  List<AiUserMemory> _memories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _loadMemories() async {
    final list = await ref.read(aiMemoryServiceProvider).getMemories();
    if (mounted) {
      setState(() {
        _memories = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _addMemory() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;

    AppHaptics.success();
    await ref.read(aiMemoryServiceProvider).saveMemory(fact: text);
    _addController.clear();
    await _loadMemories();
  }

  Future<void> _deleteMemory(AiUserMemory mem) async {
    AppHaptics.tap();
    await ref.read(aiMemoryServiceProvider).deleteMemory(mem.id);
    await _loadMemories();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed memory: "${mem.fact}"', style: const TextStyle(fontSize: 12)),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Memories?'),
        content: Text('This will erase all facts ${widget.companionName} remembers about you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      AppHaptics.warning();
      await ref.read(aiMemoryServiceProvider).clearAllMemories();
      await _loadMemories();
    }
  }

  Color _categoryColor(String category, BuildContext context) {
    switch (category.toLowerCase()) {
      case 'injury':
        return const Color(0xFFEF4444); // Red
      case 'goal':
        return const Color(0xFFF59E0B); // Amber
      case 'equipment':
        return const Color(0xFF06B6D4); // Cyan
      case 'preference':
        return const Color(0xFFA855F7); // Purple
      case 'schedule':
        return const Color(0xFF10B981); // Emerald
      default:
        return context.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0F18) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.psychology_rounded, size: 24, color: context.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agent Memory',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamilyDisplay,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        'What ${widget.companionName} remembers across all conversations',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_memories.isNotEmpty)
                  TextButton(
                    onPressed: _clearAll,
                    child: Text(
                      'Clear',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Input Bar to Add Memory Manually
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161926) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _addController,
                      style: TextStyle(fontSize: 13, color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Add fact (e.g. "Left wrist pain during bench")',
                        hintStyle: TextStyle(fontSize: 12, color: context.textTertiary),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _addMemory(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ScaleTap(
                  onPressed: _addMemory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '+ Add',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Memory Items List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _memories.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.psychology_outlined,
                                size: 48,
                                color: context.textTertiary.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No memories stored yet',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'As you chat with ${widget.companionName}, key injuries, equipment limits, and goals you share will be remembered here automatically across all sessions.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textTertiary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        itemCount: _memories.length,
                        itemBuilder: (context, index) {
                          final mem = _memories[index];
                          final catColor = _categoryColor(mem.category, context);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141724) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    mem.category.toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: catColor,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mem.fact,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: context.textPrimary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 16,
                                    color: context.textTertiary,
                                  ),
                                  tooltip: 'Forget this memory',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _deleteMemory(mem),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Multi-Exercise Visuals Gallery (Interactive In-Chat UI) ─────────────────
class _MultiExerciseVisualsCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(String exerciseName) onAskExercise;

  const _MultiExerciseVisualsCard({
    required this.data,
    required this.onAskExercise,
  });

  @override
  State<_MultiExerciseVisualsCard> createState() => _MultiExerciseVisualsCardState();
}

class _MultiExerciseVisualsCardState extends State<_MultiExerciseVisualsCard> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final rawItems = widget.data['items'] as List?;
    final items = rawItems?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.94),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF141923) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.isDark ? const Color(0x3364B5F6) : const Color(0xFF90CAF9),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.collections_rounded, size: 14, color: context.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Exercise Visuals & Targets',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${items.length} MOVEMENTS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ScaleTap(
                onPressed: () {
                  AppHaptics.tap();
                  setState(() => _isCollapsed = !_isCollapsed);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: context.chipBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.chipBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isCollapsed ? 'Show' : 'Hide',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.textSecondary),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                        size: 13,
                        color: context.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isCollapsed) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () {
                AppHaptics.tap();
                setState(() => _isCollapsed = false);
              },
              child: Row(
                children: [
                  Text(
                    '${items.length} form guides loaded • Tap to expand visual cards',
                    style: TextStyle(fontSize: 11, color: context.textSecondary),
                  ),
                  const Spacer(),
                  Icon(Icons.visibility_outlined, size: 14, color: context.accent),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final name = item['name']?.toString() ?? 'Exercise';
                final imgUrl = item['imageUrl']?.toString();
                final muscle = item['primaryMuscle']?.toString() ?? 'General';

                return Container(
                  width: 154,
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0xFF1B2230) : Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Thumbnail with Tap to Enlarge
                      InkWell(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        onTap: () {
                          AppHaptics.selection();
                          _showEnlargedExerciseModal(context, item);
                        },
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                          child: Stack(
                            children: [
                              Container(
                                height: 94,
                                width: double.infinity,
                                color: context.isDark ? const Color(0xFF0F131C) : const Color(0xFFF1F5F9),
                                child: _buildAdaptiveExerciseThumbnail(imgUrl, name, context),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Icon(Icons.fullscreen_rounded, size: 13, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () {
                                AppHaptics.selection();
                                _showEnlargedExerciseModal(context, item);
                              },
                              child: Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: context.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    muscle.toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: context.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            BouncyPressable(
                              onTap: () {
                                AppHaptics.selection();
                                widget.onAskExercise(name);
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    'Ask Cues',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: context.accent,
                                    ),
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
              },
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdaptiveExerciseThumbnail(String? imgUrl, String exerciseName, BuildContext context) {
    if (imgUrl != null && imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('assets/')) {
        return Image.asset(imgUrl, fit: BoxFit.cover);
      }
      if (imgUrl.startsWith('http://') || imgUrl.startsWith('https://')) {
        return Image.network(
          imgUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            final local = ExerciseMediaService.getVerifiedMedia(exerciseName);
            if (local != null) {
              return Image.asset(local.source, fit: BoxFit.cover);
            }
            return Center(
              child: Icon(Icons.fitness_center_rounded, size: 28, color: context.textTertiary),
            );
          },
        );
      }
    }
    final local = ExerciseMediaService.getVerifiedMedia(exerciseName);
    if (local != null) {
      return Image.asset(local.source, fit: BoxFit.cover);
    }
    return Center(
      child: Icon(Icons.fitness_center_rounded, size: 28, color: context.textTertiary),
    );
  }

  Future<void> _showEnlargedExerciseModal(BuildContext context, Map<String, dynamic> item) async {
    final name = item['name']?.toString() ?? 'Exercise';
    final imgUrl = item['imageUrl']?.toString();
    final muscle = item['primaryMuscle']?.toString() ?? 'General';
    final equipment = item['equipment']?.toString();

    // Ensure keyboard and active focus are cleared
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
    FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.scope);

    await showDialog(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header bar: muscle pill + close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ctx.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ctx.accent.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fitness_center_rounded, size: 13, color: ctx.accent),
                        const SizedBox(width: 5),
                        Text(
                          muscle.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ctx.accent,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Enlarged interactive image viewer
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.52,
                  maxWidth: double.infinity,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F131C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 3.5,
                  child: Center(
                    child: _buildAdaptiveExerciseThumbnail(imgUrl, name, ctx),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bottom card with details and coach cues button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: ctx.isDark ? const Color(0xFF1B2230) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: ctx.isDark ? const Color(0x3364B5F6) : const Color(0xFF90CAF9),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ctx.textPrimary,
                      ),
                    ),
                    if (equipment != null && equipment.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Equipment: $equipment',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: ctx.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Pinch to zoom • Drag to pan',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: ctx.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: BouncyPressable(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              widget.onAskExercise(name);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: ctx.accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.black),
                                    SizedBox(width: 6),
                                    Text(
                                      'Ask Coach Cues & Tips',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (context.mounted) {
      FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
      FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.scope);
    }
  }
}

// ── Flowchart & Visual Diagram Engine (Multi-Branching Mermaid Graph) ─────────

class FlowchartNode {
  final String id;
  final String label;
  final String phase;
  final String? description;
  final bool isDecision;
  final String? shape;
  final List<String> next;

  FlowchartNode({
    required this.id,
    required this.label,
    required this.phase,
    this.description,
    this.isDecision = false,
    this.shape,
    this.next = const [],
  });
}

class FlowchartEdge {
  final String from;
  final String to;
  final String? label;

  FlowchartEdge({
    required this.from,
    required this.to,
    this.label,
  });
}

class FlowchartGraph {
  final String title;
  final String direction;
  final List<FlowchartNode> nodes;
  final List<FlowchartEdge> edges;

  FlowchartGraph({
    required this.title,
    this.direction = 'TD',
    required this.nodes,
    required this.edges,
  });
}

class MermaidFlowchartParser {
  static FlowchartGraph parse(
    String code, {
    String defaultTitle = 'Visual Flowchart',
    List<Map<String, dynamic>>? fallbackNodes,
  }) {
    final cleanCode = code
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(r'\n', '\n');

    final lines = cleanCode.split('\n');
    String direction = 'TD';
    final Map<String, FlowchartNode> nodesMap = {};
    final List<FlowchartEdge> edges = [];

    // Parse direction
    final dirMatch = RegExp(r'(?:graph|flowchart)\s+([A-Za-z]{2})', caseSensitive: false).firstMatch(cleanCode);
    if (dirMatch != null) {
      direction = dirMatch.group(1)?.toUpperCase() ?? 'TD';
    }

    void registerNode(String id, String label, {bool isDecision = false, String? shape}) {
      final cleanId = id.trim();
      final cleanLabel = label.trim();
      if (cleanId.isEmpty) return;

      if (!nodesMap.containsKey(cleanId)) {
        final phase = _inferPhase(cleanLabel, isDecision: isDecision);
        nodesMap[cleanId] = FlowchartNode(
          id: cleanId,
          label: cleanLabel.isNotEmpty ? cleanLabel : cleanId,
          phase: phase,
          isDecision: isDecision,
          shape: shape,
        );
      }
    }

    // Node shape regexes
    final pillRegex = RegExp(r'([A-Za-z0-9_]+)\s*\(\[\s*"?([^"\]\)]+)"?\s*\]\)');
    final diamondRegex = RegExp(r'([A-Za-z0-9_]+)\s*\{\s*"?([^"\}]+)"?\s*\}');
    final roundRegex = RegExp(r'([A-Za-z0-9_]+)\s*\(\s*"?([^"\)]+)"?\s*\)');
    final squareRegex = RegExp(r'([A-Za-z0-9_]+)\s*\[\s*"?([^"\]]+)"?\s*\]');

    final edgeLabeled1 = RegExp(r'(.+?)\s*(?:-->|==>|-\.->)\s*\|([^|]+)\|\s*(.+)');
    final edgeLabeled2 = RegExp(r'(.+?)\s*--\s*([^-]+)\s*-->\s*(.+)');
    final edgeSimple = RegExp(r'(.+?)\s*(?:-->|==>|-\.->)\s*(.+)');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('%%') ||
          trimmed.startsWith('graph ') ||
          trimmed.startsWith('flowchart ')) {
        continue;
      }

      // 1. Extract node definitions
      for (final m in pillRegex.allMatches(trimmed)) {
        registerNode(m.group(1)!, m.group(2)!, shape: 'pill');
      }
      for (final m in diamondRegex.allMatches(trimmed)) {
        registerNode(m.group(1)!, m.group(2)!, isDecision: true, shape: 'diamond');
      }
      for (final m in roundRegex.allMatches(trimmed)) {
        if (!m.group(0)!.contains('([')) {
          registerNode(m.group(1)!, m.group(2)!, shape: 'round');
        }
      }
      for (final m in squareRegex.allMatches(trimmed)) {
        registerNode(m.group(1)!, m.group(2)!, shape: 'square');
      }

      // 2. Extract edge connections
      final m1 = edgeLabeled1.allMatches(trimmed);
      final m2 = edgeLabeled2.allMatches(trimmed);
      if (m1.isNotEmpty) {
        for (final m in m1) {
          _addEdges(m.group(1)!, m.group(3)!, m.group(2)?.trim(), edges, registerNode);
        }
      } else if (m2.isNotEmpty) {
        for (final m in m2) {
          _addEdges(m.group(1)!, m.group(3)!, m.group(2)?.trim(), edges, registerNode);
        }
      } else {
        for (final m in edgeSimple.allMatches(trimmed)) {
          _addEdges(m.group(1)!, m.group(2)!, null, edges, registerNode);
        }
      }
    }

    // 3. Fallback nodes from toolcall
    if (fallbackNodes != null && fallbackNodes.isNotEmpty) {
      for (int i = 0; i < fallbackNodes.length; i++) {
        final fn = fallbackNodes[i];
        final id = fn['id']?.toString() ?? '${i + 1}';
        final label = fn['label']?.toString() ?? id;
        final phase = fn['phase']?.toString() ?? _inferPhase(label);
        final desc = fn['description']?.toString();
        final rawNext = fn['next'];
        final nextList = rawNext is List
            ? rawNext.map((e) => e.toString()).toList()
            : (i < fallbackNodes.length - 1 ? ['${i + 2}'] : <String>[]);

        final existing = nodesMap[id];
        final isDec = existing?.isDecision ?? (phase.toLowerCase().contains('decis') || label.contains('?'));

        nodesMap[id] = FlowchartNode(
          id: id,
          label: existing != null && existing.label.isNotEmpty ? existing.label : label,
          phase: phase,
          description: desc,
          isDecision: isDec,
          shape: existing?.shape,
          next: nextList,
        );

        for (final nxt in nextList) {
          if (!edges.any((e) => e.from == id && e.to == nxt)) {
            edges.add(FlowchartEdge(from: id, to: nxt));
          }
        }
      }
    }

    return FlowchartGraph(
      title: defaultTitle,
      direction: direction,
      nodes: nodesMap.values.toList(),
      edges: edges,
    );
  }

  static void _addEdges(
    String fromStr,
    String toStr,
    String? label,
    List<FlowchartEdge> edges,
    void Function(String id, String label, {bool isDecision, String? shape}) registerNode,
  ) {
    final fromIds = _extractIds(fromStr);
    final toIds = _extractIds(toStr);

    for (final f in fromIds) {
      registerNode(f, f);
      for (final t in toIds) {
        registerNode(t, t);
        if (!edges.any((e) => e.from == f && e.to == t)) {
          edges.add(FlowchartEdge(from: f, to: t, label: label));
        }
      }
    }
  }

  static List<String> _extractIds(String str) {
    final tokens = str.split('&');
    final List<String> result = [];
    for (final tok in tokens) {
      final m = RegExp(r'([A-Za-z0-9_]+)').firstMatch(tok.trim());
      if (m != null) {
        result.add(m.group(1)!);
      }
    }
    return result;
  }

  static String _inferPhase(String label, {bool isDecision = false}) {
    if (isDecision) return 'Decision';
    final lower = label.toLowerCase();
    if (lower.contains('?')) return 'Decision';
    if (lower.contains('warm')) return 'Warm-up';
    if (lower.contains('compound') ||
        lower.contains('heavy') ||
        lower.contains('squat') ||
        lower.contains('bench') ||
        lower.contains('deadlift') ||
        lower.contains('press')) {
      return 'Compound';
    }
    if (lower.contains('accessory') ||
        lower.contains('hypertrophy') ||
        lower.contains('curl') ||
        lower.contains('raise') ||
        lower.contains('fly') ||
        lower.contains('extension') ||
        lower.contains('pull') ||
        lower.contains('row')) {
      return 'Accessory';
    }
    if (lower.contains('finish') ||
        lower.contains('burn') ||
        lower.contains('pump') ||
        lower.contains('drop') ||
        lower.contains('cooldown')) {
      return 'Finisher';
    }
    if (lower.contains('rest') || lower.contains('deload') || lower.contains('recover')) {
      return 'Rest';
    }
    if (lower.contains('split') ||
        lower.contains('day 1') ||
        lower.contains('day 2') ||
        lower.contains('day 3') ||
        lower.contains('push') ||
        lower.contains('legs')) {
      return 'Split';
    }
    return 'Step';
  }

  static List<List<FlowchartNode>> computeLayers(
    List<FlowchartNode> nodes,
    List<FlowchartEdge> edges,
  ) {
    if (nodes.isEmpty) return [];

    final nodeMap = {for (final n in nodes) n.id: n};
    final incomingCount = <String, int>{for (final n in nodes) n.id: 0};
    final outgoing = <String, List<String>>{for (final n in nodes) n.id: []};

    for (final e in edges) {
      if (nodeMap.containsKey(e.from) && nodeMap.containsKey(e.to)) {
        incomingCount[e.to] = (incomingCount[e.to] ?? 0) + 1;
        outgoing[e.from]!.add(e.to);
      }
    }

    var roots = nodes.where((n) => (incomingCount[n.id] ?? 0) == 0).map((n) => n.id).toList();
    if (roots.isEmpty) {
      roots = [nodes.first.id];
    }

    final levelMap = <String, int>{};
    for (final r in roots) {
      levelMap[r] = 0;
    }

    final queue = List<String>.from(roots);
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      visited.add(curr);
      final currLevel = levelMap[curr] ?? 0;

      for (final next in outgoing[curr] ?? []) {
        final existingLevel = levelMap[next] ?? 0;
        final newLevel = currLevel + 1;
        if (newLevel > existingLevel) {
          levelMap[next] = newLevel;
        }
        if (!visited.contains(next) && !queue.contains(next)) {
          queue.add(next);
        }
      }
    }

    int maxLevel = levelMap.values.fold(0, (max, v) => v > max ? v : max);
    for (final n in nodes) {
      if (!levelMap.containsKey(n.id)) {
        maxLevel++;
        levelMap[n.id] = maxLevel;
      }
    }

    final Map<int, List<FlowchartNode>> layersMap = {};
    for (final n in nodes) {
      final lvl = levelMap[n.id] ?? 0;
      layersMap.putIfAbsent(lvl, () => []).add(n);
    }

    final sortedKeys = layersMap.keys.toList()..sort();
    return sortedKeys.map((k) => layersMap[k]!).toList();
  }
}

// ── Flowchart Graphical Visualizer Widget ────────────────────────────────────

class _FlowchartGraphView extends StatefulWidget {
  final FlowchartGraph graph;

  const _FlowchartGraphView({
    required this.graph,
  });

  @override
  State<_FlowchartGraphView> createState() => _FlowchartGraphViewState();
}

class _FlowchartGraphViewState extends State<_FlowchartGraphView> {
  bool _zoomMode = false;

  Color _getPhaseColor(String phase, BuildContext context) {
    final lower = phase.toLowerCase();
    if (lower.contains('warm')) return const Color(0xFFF59E0B);
    if (lower.contains('compound') || lower.contains('heavy') || lower.contains('primary')) {
      return context.accent;
    }
    if (lower.contains('accessory') || lower.contains('hypertrophy') || lower.contains('secondary')) {
      return const Color(0xFF8B5CF6);
    }
    if (lower.contains('finish') || lower.contains('pump') || lower.contains('burn')) {
      return const Color(0xFF10B981);
    }
    if (lower.contains('decision') || lower.contains('eval')) {
      return const Color(0xFFF59E0B);
    }
    if (lower.contains('rest') || lower.contains('deload')) {
      return const Color(0xFF64748B);
    }
    if (lower.contains('split') || lower.contains('day')) {
      return const Color(0xFF38BDF8);
    }
    return context.accent;
  }

  @override
  Widget build(BuildContext context) {
    final layers = MermaidFlowchartParser.computeLayers(widget.graph.nodes, widget.graph.edges);
    if (layers.isEmpty) {
      return const Center(child: Text('No diagram nodes available'));
    }

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < layers.length; i++) ...[
          _buildLayerRow(layers[i], i),
          if (i < layers.length - 1)
            _buildConnectorBetweenLayers(layers[i], layers[i + 1]),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Controls Toolbar (Nodes & Connections stats + Zoom/Pan Mode toggle)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF0F131C) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.hub_rounded, size: 12, color: context.accent),
              const SizedBox(width: 5),
              Text(
                '${widget.graph.nodes.length} nodes • ${widget.graph.edges.length} branches',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
              const Spacer(),
              ScaleTap(
                onPressed: () {
                  AppHaptics.selection();
                  setState(() => _zoomMode = !_zoomMode);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _zoomMode ? context.accent.withValues(alpha: 0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _zoomMode ? context.accent : Colors.transparent,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _zoomMode ? Icons.zoom_out_map_rounded : Icons.pan_tool_outlined,
                        size: 11,
                        color: _zoomMode ? context.accent : context.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _zoomMode ? 'Interactive Pan' : 'Scroll View',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: _zoomMode ? context.accent : context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Graph Canvas
        _zoomMode
            ? SizedBox(
                height: 380,
                width: double.infinity,
                child: InteractiveViewer(
                  constrained: false,
                  minScale: 0.4,
                  maxScale: 2.8,
                  boundaryMargin: const EdgeInsets.all(80),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: content,
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width * 0.84,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: content,
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildLayerRow(List<FlowchartNode> layerNodes, int layerIndex) {
    if (layerNodes.length == 1) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, minWidth: 160),
          child: _buildNodeCard(layerNodes.first),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < layerNodes.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180, minWidth: 120),
            child: _buildNodeCard(layerNodes[i]),
          ),
        ],
      ],
    );
  }

  Widget _buildConnectorBetweenLayers(
    List<FlowchartNode> parentLayer,
    List<FlowchartNode> childLayer,
  ) {
    final connectingEdges = widget.graph.edges.where((e) {
      return parentLayer.any((p) => p.id == e.from) &&
          childLayer.any((c) => c.id == e.to);
    }).toList();

    // Case 1: 1 parent -> 1 child
    if (parentLayer.length == 1 && childLayer.length == 1) {
      final label = connectingEdges.isNotEmpty ? connectingEdges.first.label : null;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 1.5,
            height: label != null && label.isNotEmpty ? 8 : 12,
            color: context.accent.withValues(alpha: 0.45),
          ),
          if (label != null && label.isNotEmpty) ...[
            _buildEdgeLabelBadge(label),
            Container(
              width: 1.5,
              height: 6,
              color: context.accent.withValues(alpha: 0.45),
            ),
          ],
          Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: context.accent),
        ],
      );
    }

    // Case 2: 1 parent -> Multiple children (Branch Split!)
    if (parentLayer.length == 1 && childLayer.length > 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 1.5,
            height: 10,
            color: context.accent.withValues(alpha: 0.45),
          ),
          Container(
            height: 1.5,
            width: math.max(60.0, (childLayer.length - 1) * 140.0),
            color: context.accent.withValues(alpha: 0.45),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int c = 0; c < childLayer.length; c++) ...[
                if (c > 0)
                  SizedBox(
                    width: math.max(12.0, 140.0 - 24.0),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 1.5,
                      height: 6,
                      color: context.accent.withValues(alpha: 0.45),
                    ),
                    Builder(builder: (context) {
                      final edge = connectingEdges.firstWhere(
                        (e) => e.to == childLayer[c].id,
                        orElse: () => FlowchartEdge(from: '', to: ''),
                      );
                      if (edge.label != null && edge.label!.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: _buildEdgeLabelBadge(edge.label!),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: context.accent),
                  ],
                ),
              ],
            ],
          ),
        ],
      );
    }

    // Case 3: Multiple parents -> 1 child (Branch Merge!)
    if (parentLayer.length > 1 && childLayer.length == 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int p = 0; p < parentLayer.length; p++) ...[
                if (p > 0)
                  SizedBox(
                    width: math.max(12.0, 140.0 - 24.0),
                  ),
                Container(
                  width: 1.5,
                  height: 8,
                  color: context.accent.withValues(alpha: 0.45),
                ),
              ],
            ],
          ),
          Container(
            height: 1.5,
            width: math.max(60.0, (parentLayer.length - 1) * 140.0),
            color: context.accent.withValues(alpha: 0.45),
          ),
          Container(
            width: 1.5,
            height: 6,
            color: context.accent.withValues(alpha: 0.45),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: context.accent),
        ],
      );
    }

    // Default multi-to-multi
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Icon(Icons.arrow_downward_rounded, size: 14, color: context.accent),
    );
  }

  Widget _buildEdgeLabelBadge(String label) {
    final lower = label.toLowerCase();
    Color bg = context.accent.withValues(alpha: 0.15);
    Color fg = context.accent;

    if (lower.contains('yes') || lower.contains('pass') || lower.contains('+')) {
      bg = const Color(0xFF10B981).withValues(alpha: 0.18);
      fg = const Color(0xFF10B981);
    } else if (lower.contains('no') || lower.contains('fail') || lower.contains('-')) {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.18);
      fg = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildNodeCard(FlowchartNode node) {
    final phaseColor = _getPhaseColor(node.phase, context);
    final isDark = context.isDark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          AppHaptics.selection();
          _showNodeDetailsDialog(node);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B2230) : Colors.white,
            borderRadius: BorderRadius.circular(node.shape == 'pill' ? 20 : 10),
            border: Border.all(
              color: node.isDecision
                  ? const Color(0xFFF59E0B)
                  : phaseColor.withValues(alpha: isDark ? 0.45 : 0.6),
              width: node.isDecision ? 1.4 : 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: (node.isDecision ? const Color(0xFFF59E0B) : phaseColor).withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (node.isDecision) ...[
                    const Icon(Icons.alt_route_rounded, size: 12, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 3),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: (node.isDecision ? const Color(0xFFF59E0B) : phaseColor).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (node.isDecision ? 'DECISION' : node.phase).toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: node.isDecision ? const Color(0xFFF59E0B) : phaseColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                node.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: context.textPrimary,
                ),
              ),
              if (node.description != null && node.description!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  node.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    height: 1.25,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showNodeDetailsDialog(FlowchartNode node) {
    final phaseColor = _getPhaseColor(node.phase, context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.isDark ? const Color(0xFF1E2638) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: phaseColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: phaseColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                node.phase.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: phaseColor),
              ),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              node.label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: ctx.textPrimary,
              ),
            ),
            if (node.description != null && node.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                node.description!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: ctx.textSecondary,
                ),
              ),
            ],
            if (node.next.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Connected Steps: ${node.next.join(", ")}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ctx.accent,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: TextStyle(color: ctx.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ── Visual Diagram & Flowchart Card (Interactive In-Chat UI) ────────────────
class _VisualDiagramCard extends StatefulWidget {
  final Map<String, dynamic> data;

  const _VisualDiagramCard({required this.data});

  @override
  State<_VisualDiagramCard> createState() => _VisualDiagramCardState();
}

class _VisualDiagramCardState extends State<_VisualDiagramCard> {
  int _activeTab = 0; // 0 = Flowchart Graph, 1 = Step Cards, 2 = Mermaid Code
  bool _isCollapsed = false;

  Color _getPhaseColor(String phase, BuildContext context) {
    final lower = phase.toLowerCase();
    if (lower.contains('warm')) return const Color(0xFFF59E0B);
    if (lower.contains('compound') || lower.contains('heavy') || lower.contains('primary')) {
      return context.accent;
    }
    if (lower.contains('accessory') || lower.contains('hypertrophy') || lower.contains('secondary')) {
      return const Color(0xFF8B5CF6);
    }
    if (lower.contains('finish') || lower.contains('pump') || lower.contains('burn')) {
      return const Color(0xFF10B981);
    }
    if (lower.contains('rest') || lower.contains('deload')) {
      return const Color(0xFF64748B);
    }
    return context.accent;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title']?.toString() ?? 'Visual Flowchart';
    final diagramType = widget.data['diagramType']?.toString().toUpperCase() ?? 'FLOWCHART';
    final summary = widget.data['summary']?.toString();
    final rawNodes = widget.data['nodes'] as List?;
    final nodes = rawNodes?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    final mermaidCode = widget.data['mermaidCode']?.toString() ?? '';

    final graph = MermaidFlowchartParser.parse(
      mermaidCode,
      defaultTitle: title,
      fallbackNodes: nodes,
    );

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.94),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF141923) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.isDark ? const Color(0x3364B5F6) : const Color(0xFF90CAF9),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.account_tree_rounded, size: 14, color: context.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  diagramType,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: context.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ScaleTap(
                onPressed: () {
                  AppHaptics.tap();
                  setState(() => _isCollapsed = !_isCollapsed);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: context.chipBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.chipBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isCollapsed ? 'Show' : 'Hide',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.textSecondary),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                        size: 13,
                        color: context.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_isCollapsed) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () {
                AppHaptics.tap();
                setState(() => _isCollapsed = false);
              },
              child: Row(
                children: [
                  Text(
                    '${graph.nodes.length} nodes (${graph.edges.length} connections) • Tap to expand flowchart',
                    style: TextStyle(fontSize: 11, color: context.textSecondary),
                  ),
                  const Spacer(),
                  Icon(Icons.visibility_outlined, size: 14, color: context.accent),
                ],
              ),
            ),
          ] else ...[
            if (summary != null && summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                summary,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 1.35,
                  color: context.textSecondary,
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Mode Selector Tabs (Flowchart, Step Cards, Mermaid Code)
            Row(
              children: [
                _buildModePill(0, Icons.account_tree_outlined, 'Flowchart'),
                const SizedBox(width: 6),
                _buildModePill(1, Icons.view_agenda_outlined, 'Steps'),
                if (mermaidCode.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildModePill(2, Icons.code_rounded, 'Mermaid'),
                ],
              ],
            ),

            const SizedBox(height: 10),

            if (_activeTab == 0)
              _FlowchartGraphView(graph: graph)
            else if (_activeTab == 1)
              _buildStepCardsList(graph.nodes)
            else if (_activeTab == 2 && mermaidCode.isNotEmpty)
              _buildMermaidCodeView(mermaidCode),
          ],
        ],
      ),
    );
  }

  Widget _buildModePill(int index, IconData icon, String label) {
    final isSelected = _activeTab == index;
    return ScaleTap(
      onPressed: () {
        AppHaptics.selection();
        setState(() => _activeTab = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? context.accent : (context.isDark ? const Color(0xFF1B2230) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11.5,
              color: isSelected ? Colors.black : context.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.black : context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMermaidCodeView(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF0F131C) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mermaid Syntax',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
              ),
              BouncyPressable(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  AppHaptics.tap();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mermaid code copied to clipboard'), duration: Duration(seconds: 2)),
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 12, color: context.accent),
                    const SizedBox(width: 4),
                    Text('Copy', style: TextStyle(fontSize: 11, color: context.accent, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              height: 1.35,
              color: Color(0xFF38BDF8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCardsList(List<FlowchartNode> nodes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < nodes.length; i++) ...[
          _buildNodeItem(nodes[i], i, i == nodes.length - 1),
          if (i < nodes.length - 1)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_downward_rounded, size: 14, color: context.accent),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildNodeItem(FlowchartNode node, int index, bool isLast) {
    final phaseColor = _getPhaseColor(node.phase, context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1B2230) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: node.isDecision
              ? const Color(0xFFF59E0B)
              : (context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: (node.isDecision ? const Color(0xFFF59E0B) : phaseColor).withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: node.isDecision ? const Color(0xFFF59E0B) : phaseColor, width: 1.2),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: node.isDecision ? const Color(0xFFF59E0B) : phaseColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        node.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (node.isDecision ? const Color(0xFFF59E0B) : phaseColor).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (node.isDecision ? 'DECISION' : node.phase).toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: node.isDecision ? const Color(0xFFF59E0B) : phaseColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (node.description != null && node.description!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    node.description!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      height: 1.3,
                      color: context.textSecondary,
                    ),
                  ),
                ],
                if (node.next.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '➔ Next: ${node.next.join(", ")}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: context.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progression Chart Card (Interactive In-Chat UI) ─────────────────────────
class _ProgressionChartCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ProgressionChartCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? 'Progression Chart';
    final unit = data['unit']?.toString() ?? 'kg';
    final summary = data['summary']?.toString();
    final rawPoints = data['dataPoints'] as List?;
    final points = rawPoints?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

    if (points.isEmpty) return const SizedBox.shrink();

    final values = points.map((p) => (p['value'] as num?)?.toDouble() ?? 0.0).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final double minY = (minVal * 0.9).clamp(0.0, double.infinity);
    final double maxY = maxVal > minY ? maxVal * 1.15 : minY + 10;
    final gain = maxVal - minVal;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.94),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF141923) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.isDark ? const Color(0x3364B5F6) : const Color(0xFF90CAF9),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.trending_up_rounded, size: 14, color: context.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+${gain.toStringAsFixed(1)} $unit',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.accent,
                  ),
                ),
              ),
            ],
          ),

          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.35,
                color: context.textSecondary,
              ),
            ),
          ],

          const SizedBox(height: 14),

          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ((maxY - minY) / 3).clamp(1.0, double.infinity),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: context.isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: ((maxY - minY) / 3).clamp(1.0, double.infinity),
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'Inter',
                          color: context.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < points.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              points[idx]['label']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontFamily: 'Inter',
                                color: context.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: points.asMap().entries.map((entry) {
                      final val = (entry.value['value'] as num?)?.toDouble() ?? 0.0;
                      return FlSpot(entry.key.toDouble(), val);
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: context.accent,
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          context.accent.withValues(alpha: 0.3),
                          context.accent.withValues(alpha: 0.0),
                        ],
                      ),
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
}

// ── Native Mermaid Diagram Renderer (Interactive In-Chat UI) ────────────────
class _MermaidDiagramNativeCard extends StatelessWidget {
  final String mermaidCode;

  const _MermaidDiagramNativeCard({required this.mermaidCode});

  @override
  Widget build(BuildContext context) {
    return _VisualDiagramCard(
      data: {
        'title': 'Workflow Flowchart',
        'diagramType': 'FLOWCHART',
        'mermaidCode': mermaidCode,
        'nodes': [],
      },
    );
  }
}

// ── Gold Sparkles Custom Painter for PR Celebrations ────────────────────────
class _GoldSparklesPainter extends CustomPainter {
  final Animation<double> animation;
  _GoldSparklesPainter({required this.animation}) : super(repaint: animation);

  static final List<math.Point<double>> _points = [
    const math.Point(0.12, 0.28),
    const math.Point(0.88, 0.22),
    const math.Point(0.94, 0.76),
    const math.Point(0.06, 0.78),
    const math.Point(0.50, 0.05),
    const math.Point(0.52, 0.95),
    const math.Point(0.26, 0.88),
    const math.Point(0.74, 0.45),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    for (int i = 0; i < _points.length; i++) {
      final p = _points[i];
      final phase = (t + (i / _points.length)) % 1.0;
      final opacity = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final radius = 1.2 + math.sin(phase * math.pi) * 1.8;
      final center = Offset(p.x * size.width, p.y * size.height);

      final paint = Paint()
        ..color = (i % 2 == 0 ? const Color(0xFFFFD700) : const Color(0xFFFFF7C2))
            .withValues(alpha: opacity * 0.9)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, radius, paint);

      if (i % 3 == 0 && opacity > 0.35) {
        final crossPaint = Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.85)
          ..strokeWidth = 0.8;
        final arm = radius * 1.6;
        canvas.drawLine(Offset(center.dx - arm, center.dy), Offset(center.dx + arm, center.dy), crossPaint);
        canvas.drawLine(Offset(center.dx, center.dy - arm), Offset(center.dx, center.dy + arm), crossPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GoldSparklesPainter oldDelegate) => true;
}

// ── Personal Record & Strength Milestone Showcase (Interactive In-Chat UI) ───
class _PrHistoryMilestoneCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(String prompt)? onAskBreakPr;
  final ChibiAvatar? companion;

  const _PrHistoryMilestoneCard({
    required this.data,
    this.onAskBreakPr,
    this.companion,
  });

  @override
  State<_PrHistoryMilestoneCard> createState() => _PrHistoryMilestoneCardState();
}

class _PrHistoryMilestoneCardState extends State<_PrHistoryMilestoneCard> with SingleTickerProviderStateMixin {
  late final AnimationController _sparkleController;
  double? _target1rmGoal;
  ChibiAvatar _companion = ChibiAvatar.aiko;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _initCompanion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppHaptics.success();
    });
  }

  Future<void> _initCompanion() async {
    if (widget.companion != null) {
      if (mounted) setState(() => _companion = widget.companion!);
      return;
    }
    final c = await ChibiAvatar.loadCurrent();
    if (mounted) setState(() => _companion = c);
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  String _getCompanionCelebrationQuote(ChibiAvatar companion, String? exerciseName) {
    final ex = exerciseName ?? 'this lift';
    switch (companion.id) {
      case 'shiba':
        return 'WOOF! MUCH STRENGTH! VERY GAINZ! Beast mode on $ex! 🐕🔥';
      case 'ken':
        return 'Flawless execution. Consistency and calculated overload triumph again.';
      case 'roxy':
        return 'Max wattage detected! Neurological power surge on $ex! ⚡';
      case 'bao':
        return 'Tremendous power and solid bracing! Time for a hearty protein feast! 🐼🍚';
      case 'kuro':
        return 'Precision in stillness, explosive in execution. True mastery of the iron.';
      case 'ren':
        return 'THAT is the fighting spirit! Break your limits and set the gym ablaze! 🔥';
      case 'aiko':
      default:
        return 'Amazing milestone! Your hard work on $ex is truly paying off. Proud of you! ✨';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSingle = widget.data['isSingleExercise'] == true;
    final unit = widget.data['unit']?.toString() ?? 'kg';
    final exName = widget.data['exerciseName']?.toString() ?? 'Exercise';

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.94),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF161720) : const Color(0xFFFBFBFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.38),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: context.isDark ? 0.09 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Gold Sparkles
          Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GoldSparklesPainter(animation: _sparkleController),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.emoji_events_rounded, size: 14, color: Colors.black),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSingle ? 'PERSONAL RECORD MILESTONE' : 'RECENT PERSONAL RECORDS',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  ),
                  if (isSingle && widget.data['percentageGain'] != null && widget.data['percentageGain'] != '0')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${widget.data['percentageGain']}%',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          if (isSingle) ...[
            const SizedBox(height: 10),
            // Exercise Title & Muscle
            Row(
              children: [
                Expanded(
                  child: Text(
                    exName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                if (widget.data['muscleGroup'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      widget.data['muscleGroup'].toString().toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: context.accent,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Milestone Stat Grid
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0xFF1E202B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🥇 Max Weight',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.data['maxWeight'] ?? 0} $unit',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          'for ${widget.data['maxWeightReps'] ?? 1} reps',
                          style: TextStyle(fontSize: 10, color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0xFF1E202B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚡ Est. 1RM',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${((widget.data['peakE1rm'] as num?) ?? 0).toStringAsFixed(1)} $unit',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                        const Text(
                          'Epley Formula',
                          style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Chibi Companion Reaction Card
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.isDark ? const Color(0xFF1A1F2C) : const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Image.asset(
                    _companion.assetPath,
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_companion.name} celebrating your lift:',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.accent),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _getCompanionCelebrationQuote(_companion, exName),
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: context.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Rep Ladder
            if (widget.data['repLadder'] != null && widget.data['repLadder'] is Map) ...[
              const SizedBox(height: 10),
              const Text(
                'REP MAX LADDER',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  for (final entry in (widget.data['repLadder'] as Map).entries)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.isDark ? const Color(0xFF1E202B) : Colors.white,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        '${entry.key}RM: ${entry.value} $unit',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ],

            // Mini Progression Timeline Curve
            if (widget.data['timeline'] != null && (widget.data['timeline'] as List).length >= 2) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: Builder(
                  builder: (context) {
                    final points = (widget.data['timeline'] as List).whereType<Map>().toList();
                    final values = points.map((p) => (p['weight'] as num).toDouble()).toList();
                    final minVal = values.reduce((a, b) => a < b ? a : b);
                    final maxVal = values.reduce((a, b) => a > b ? a : b);
                    final double minY = (minVal * 0.9).clamp(0.0, double.infinity);
                    final double maxY = maxVal > minY ? maxVal * 1.12 : minY + 10;

                    return LineChart(
                      LineChartData(
                        minY: minY,
                        maxY: maxY,
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 18,
                              interval: 1,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx >= 0 && idx < points.length) {
                                  return Text(
                                    points[idx]['label']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: points.asMap().entries.map((e) {
                              return FlSpot(e.key.toDouble(), (e.value['weight'] as num).toDouble());
                            }).toList(),
                            isCurved: true,
                            color: const Color(0xFFFFD700),
                            barWidth: 2.4,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFFFFD700).withValues(alpha: 0.25),
                                  const Color(0xFFFFD700).withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            // ── Interactive 1RM Goal Slider & Periodization Ramp ───────────────
            Builder(
              builder: (context) {
                final current1rm = ((widget.data['peakE1rm'] as num?) ?? (widget.data['maxWeight'] as num?) ?? 50.0).toDouble();
                final minGoal = current1rm;
                final maxGoal = math.max(minGoal + 10.0, ((current1rm * 1.35) / 2.5).ceil() * 2.5);
                _target1rmGoal ??= (((current1rm * 1.05) / 2.5).round() * 2.5).clamp(minGoal, maxGoal);
                final goalDelta = _target1rmGoal! - current1rm;
                final pctDelta = current1rm > 0 ? (goalDelta / current1rm * 100) : 0.0;

                final rep3Needed = (_target1rmGoal! * 0.93 / 2.5).round() * 2.5;
                final rep5Needed = (_target1rmGoal! * 0.86 / 2.5).round() * 2.5;
                final rep8Needed = (_target1rmGoal! * 0.79 / 2.5).round() * 2.5;

                final w1 = (_target1rmGoal! * 0.75 / 2.5).round() * 2.5;
                final w2 = (_target1rmGoal! * 0.80 / 2.5).round() * 2.5;
                final w3 = (_target1rmGoal! * 0.875 / 2.5).round() * 2.5;
                final w4 = (_target1rmGoal! / 2.5).round() * 2.5;

                final divisions = ((maxGoal - minGoal) / 2.5).round().clamp(1, 40);

                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0xFF191B24) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.track_changes_rounded, size: 14, color: Color(0xFFFFD700)),
                              SizedBox(width: 5),
                              Text(
                                'TARGET 1RM GOAL CALCULATOR',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '+${goalDelta.toStringAsFixed(1)} $unit (+${pctDelta.toStringAsFixed(1)}%)',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Target: ${_target1rmGoal!.toStringAsFixed(1)} $unit',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Current: ${current1rm.toStringAsFixed(1)} $unit',
                            style: TextStyle(fontSize: 10, color: context.textTertiary),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFFFD700),
                          inactiveTrackColor: context.isDark ? const Color(0x33FFFFFF) : const Color(0xFFCBD5E1),
                          thumbColor: const Color(0xFFFFD700),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: _target1rmGoal!.clamp(minGoal, maxGoal),
                          min: minGoal,
                          max: maxGoal,
                          divisions: divisions,
                          onChanged: (val) {
                            AppHaptics.step();
                            setState(() => _target1rmGoal = val);
                          },
                        ),
                      ),
                      // Rep Equivalent Requirements
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildRepTargetChip('3RM Need', '$rep3Needed $unit', context),
                          _buildRepTargetChip('5RM Need', '$rep5Needed $unit', context),
                          _buildRepTargetChip('8RM Need', '$rep8Needed $unit', context),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 4-Week Wave Periodization
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.isDark ? const Color(0xFF111319) : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '4-WEEK WAVE PERIODIZATION RAMP',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• W1 (Base): $w1 $unit × 8 reps\n'
                              '• W2 (Volume): $w2 $unit × 6 reps\n'
                              '• W3 (Intensify): $w3 $unit × 4 reps\n'
                              '• W4 (Peak Test): $w4 $unit × 1-2 reps',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10.5,
                                height: 1.35,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ScaleTap(
                        onPressed: () {
                          AppHaptics.selection();
                          final prompt = 'Build me a dedicated 4-week wave periodization plan to take my $exName from ${current1rm.toStringAsFixed(1)} $unit to ${_target1rmGoal!.toStringAsFixed(1)} $unit.';
                          if (widget.onAskBreakPr != null) {
                            widget.onAskBreakPr!(prompt);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fitness_center_rounded, size: 12, color: Color(0xFFFFD700)),
                                const SizedBox(width: 4),
                                Text(
                                  'Ask AI to Build 4-Week Cycle for ${_target1rmGoal!.toStringAsFixed(1)} $unit',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFFD700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 10),
            BouncyPressable(
              onTap: () {
                AppHaptics.selection();
                if (widget.onAskBreakPr != null) {
                  widget.onAskBreakPr!('Give me a dedicated periodized progression strategy to break my PR on $exName.');
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFFFD700)),
                    SizedBox(width: 5),
                    Text(
                      'Ask AI How to Break This PR',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Multi-Exercise Recent PRs
            const SizedBox(height: 8),
            for (final pr in (widget.data['records'] as List? ?? []))
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: context.isDark ? const Color(0xFF1E202B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFD700)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        pr['exerciseName']?.toString() ?? 'Exercise',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${pr['value'] ?? 0} $unit',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRepTargetChip(String label, String value, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF111319) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.isDark ? const Color(0x1FFFFFFF) : const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          const SizedBox(height: 1),
          Text(value, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
        ],
      ),
    );
  }
}





