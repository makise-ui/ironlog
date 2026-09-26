import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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
        onError: (_) => setState(() => _isListening = false),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
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

  void _handleSend([String? presetText]) {
    final text = (presetText ?? _textController.text).trim();
    final attachedImagePath = _selectedImagePath;
    final chatState = ref.read(aiChatNotifierProvider);
    if ((text.isEmpty && attachedImagePath == null) || chatState.isLoading) return;

    AppHaptics.tap();
    _textController.clear();
    setState(() {
      _selectedImagePath = null;
    });

    ref.read(aiChatNotifierProvider.notifier).sendMessage(
      text,
      imagePath: attachedImagePath,
    );
    _scrollToBottom();
  }

  void _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available on this device.')),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      AppHaptics.tap();
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _textController.text = result.recognizedWords;
          });
          if (result.finalResult) {
            _speech.stop();
            setState(() => _isListening = false);
            _handleSend();
          }
        },
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
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

    ref.listen<AiChatState>(aiChatNotifierProvider, (prev, next) {
      final prevLen = prev?.messages.length ?? 0;
      final nextLen = next.messages.length;
      final isStreaming = next.messages.isNotEmpty && next.messages.last.isStreaming;
      final contentChanged = prev?.messages.isNotEmpty == true &&
          next.messages.isNotEmpty &&
          prev!.messages.last.content.length != next.messages.last.content.length;

      if (prevLen != nextLen || (isStreaming && contentChanged)) {
        _scrollToBottom();
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
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.handleBar,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                        // Quick Action Buttons
                        Row(
                          children: [
                            _buildHeaderIconButton(
                              icon: Icons.refresh_rounded,
                              tooltip: 'New Conversation',
                              onPressed: _clearChat,
                            ),
                            _buildHeaderIconButton(
                              icon: Icons.history_rounded,
                              tooltip: 'Conversation History',
                              onPressed: () {
                                ref.read(aiChatNotifierProvider.notifier).loadAllSessions();
                                setState(() => _showHistorySidebar = true);
                              },
                            ),
                            _buildHeaderIconButton(
                              icon: Icons.delete_outline_rounded,
                              tooltip: 'Delete Conversation',
                              color: AppColors.error,
                              onPressed: _deleteCurrentChat,
                            ),
                            _buildHeaderIconButton(
                              icon: Icons.tune_rounded,
                              tooltip: 'Configure AI Provider',
                              onPressed: () {
                                if (!widget.isFullScreen) Navigator.of(context).pop();
                                context.go('/settings');
                              },
                            ),
                            _buildHeaderIconButton(
                              icon: Icons.psychology_rounded,
                              tooltip: 'Agent Memories',
                              color: context.accent,
                              onPressed: _showMemoriesSheet,
                            ),
                            if (!widget.isFullScreen)
                              _buildHeaderIconButton(
                                icon: Icons.open_in_full_rounded,
                                tooltip: 'Open Full Screen',
                                onPressed: () {
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
                                },
                              )
                            else
                              _buildHeaderIconButton(
                                icon: Icons.close_fullscreen_rounded,
                                tooltip: 'Exit Full Screen',
                                onPressed: () => Navigator.of(context).pop(),
                              ),
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
            child: messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),

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
            child: Row(
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
                              fontSize: 14.5,
                              height: 1.4,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: _isListening
                                  ? '🎙 Listening...'
                                  : 'Message AI coach…',
                              hintStyle: TextStyle(
                                color: context.textTertiary,
                                fontSize: 14,
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

                // 3. round(send button)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Builder(
                    builder: (context) {
                      final hasContent = _textController.text.trim().isNotEmpty || _selectedImagePath != null;
                      return BouncyPressable(
                        onTap: (isLoading || !hasContent) ? null : _handleSend,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isLoading
                                ? context.accent.withValues(alpha: 0.45)
                                : (hasContent
                                    ? context.accent
                                    : (context.isDark ? const Color(0xFF1E212D) : const Color(0xFFE2E8F0))),
                            shape: BoxShape.circle,
                            boxShadow: hasContent
                                ? [
                                    BoxShadow(
                                      color: context.accent.withValues(alpha: 0.28),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
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

    final mainContainer = Container(
      height: widget.isFullScreen ? double.infinity : MediaQuery.of(context).size.height * 0.86,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        child: _buildFormattedMarkdown(
          msg.content,
          isUser: false,
          isStreaming: false,
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
              fontSize: 13.5,
              height: 1.45,
              color: isUser ? Colors.black : context.textPrimary,
              fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
            ),
            strong: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: isUser ? Colors.black : context.textPrimary,
            ),
            em: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              fontStyle: FontStyle.italic,
              color: isUser ? Colors.black87 : context.textSecondary,
            ),
            h1: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isUser ? Colors.black : context.textPrimary,
            ),
            h2: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isUser ? Colors.black : context.textPrimary,
            ),
            h3: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isUser ? Colors.black : context.textPrimary,
            ),
            listBullet: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isUser ? Colors.black : context.accent,
            ),
            tableHead: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isUser ? Colors.black : context.accent,
            ),
            tableBody: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
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
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
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

          // Option chips
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
                        Text(
                          opt,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selectedOption == opt
                                ? Colors.black
                                : context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // If answered with a custom option that wasn't in preset chips
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
                      Text(
                        selectedOption,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

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
                      Text(
                        'Write custom answer...',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.accent,
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

  void _showFullScreenImage(BuildContext context, String url, String label) {
    showDialog(
      context: context,
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
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (c, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    },
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
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




