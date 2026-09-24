import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bouncy_pressable.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/providers.dart';
import '../../../../domain/services/ai_chat_notifier.dart';
import '../../../../domain/models/chibi_avatar_model.dart';
import 'ai_assistant_sheet.dart';

class AiFloatingCapsule extends ConsumerStatefulWidget {
  final VoidCallback? onTap;

  const AiFloatingCapsule({super.key, this.onTap});

  @override
  ConsumerState<AiFloatingCapsule> createState() => _AiFloatingCapsuleState();
}

class _AiFloatingCapsuleState extends ConsumerState<AiFloatingCapsule>
    with TickerProviderStateMixin {
  Offset? _position;
  bool _isDragging = false;
  bool _isPeeking = true;
  String _dockSide = 'right'; // 'left' or 'right'
  double _dragDistance = 0.0;
  double _dragTilt = 0.0;
  ChibiAvatar _currentAvatar = ChibiAvatar.aiko;

  late final AnimationController _hopController;
  late final AnimationController _dockSnapController;
  Offset _dockStartPos = Offset.zero;
  Offset _dockTargetPos = Offset.zero;

  static const double _mascotWidth = 58.0;
  static const double _mascotHeight = 64.0;
  static const double _peekVisibleWidth = 34.0;
  static const double _peekHiddenOffset = _mascotWidth - _peekVisibleWidth; // ~24.0

  @override
  void initState() {
    super.initState();

    _hopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _dockSnapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (_dockSnapController.isAnimating && mounted) {
          final t = Curves.easeOutCubic.transform(_dockSnapController.value);
          setState(() {
            _position = Offset.lerp(_dockStartPos, _dockTargetPos, t);
          });
        }
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _isPeeking = true;
          });
        }
      });

    _loadSavedPosition();
    _loadSavedAvatar();
  }

  @override
  void dispose() {
    _hopController.dispose();
    _dockSnapController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final y = prefs.getDouble('ai_peeking_y') ?? prefs.getDouble('ai_floating_y');
      final side = prefs.getString('ai_peeking_side') ?? 'right';
      if (mounted) {
        setState(() {
          _dockSide = side;
          if (y != null) {
            _position = Offset(0, y);
          }
          _isPeeking = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _savePosition(Offset pos, String side) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('ai_peeking_y', pos.dy);
      await prefs.setString('ai_peeking_side', side);
    } catch (_) {}
  }

  Future<void> _loadSavedAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('ai_chibi_avatar');
      if (id != null && mounted) {
        setState(() {
          _currentAvatar = ChibiAvatar.fromId(id);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveAvatar(ChibiAvatar avatar) async {
    setState(() {
      _currentAvatar = avatar;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_chibi_avatar', avatar.id);
    } catch (_) {}
  }

  void _openAi() {
    AppHaptics.tap();
    _hopController.forward(from: 0.0);
    ref.read(aiChatNotifierProvider.notifier).onOpenChat();
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      Future.delayed(const Duration(milliseconds: 140), () {
        if (mounted) {
          AiAssistantSheet.show(context);
        }
      });
    }
  }

  void _showAvatarSelector() {
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
                'Choose Your AI Companion',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select a chibi character to keep you company',
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
                    final isSelected = avatar == _currentAvatar;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          AppHaptics.tap();
                          _saveAvatar(avatar);
                          Navigator.pop(ctx);
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
                                width: 56,
                                height: 62,
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

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatNotifierProvider);
    final isWorkoutActive = ref.watch(isWorkoutActiveProvider);

    final snippet = chatState.latestAssistantSnippet?.trim();
    final showCloud = !_isDragging &&
        chatState.showFloatingCloud &&
        snippet != null &&
        snippet.isNotEmpty;
    final isLoading = chatState.isLoading;

    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final screenH = media.size.height;
    final topSafe = media.padding.top;
    final bottomSafe = media.padding.bottom;

    final minY = topSafe + 16.0;
    final maxY = math.max(minY, screenH - bottomSafe - (isWorkoutActive ? 140.0 : 110.0));

    // Calculate clamped docked positions for left and right edges
    final leftDockX = -_peekHiddenOffset;
    final rightDockX = screenW - _peekVisibleWidth;

    // Resolve current X, Y coordinates
    double currentY = _position?.dy ?? (screenH - (isWorkoutActive ? 150.0 : 170.0));
    currentY = currentY.clamp(minY, maxY);

    double currentX;
    if (_isDragging && _position != null) {
      currentX = _position!.dx;
    } else if (_dockSnapController.isAnimating && _position != null) {
      currentX = _position!.dx;
    } else {
      currentX = _dockSide == 'left' ? leftDockX : rightDockX;
    }

    final isDockedOnRight = _dockSide == 'right';
    final isPeekingMode = _isPeeking && !_isDragging;

    // Chibi Mascot Widget (Free-standing, NO circular container)
    final mascotWidget = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        _dockSnapController.stop();
        setState(() {
          _isDragging = true;
          _isPeeking = false;
          _dragDistance = 0.0;
        });
        AppHaptics.step();
      },
      onPanUpdate: (details) {
        _dragDistance += details.delta.distance;
        final nextX = currentX + details.delta.dx;
        final nextY = (currentY + details.delta.dy).clamp(minY, maxY);
        final tiltTarget = (details.delta.dx * 0.04).clamp(-0.25, 0.25);
        setState(() {
          _position = Offset(nextX, nextY);
          _dragTilt = tiltTarget;
        });
      },
      onPanEnd: (details) {
        setState(() {
          _isDragging = false;
          _dragTilt = 0.0;
        });

        if (_dragDistance < 7.0) {
          _openAi();
          return;
        }

        // Snap to nearest edge (left or right)
        final snapToRight = (currentX + (_mascotWidth / 2)) >= (screenW / 2);
        final targetSide = snapToRight ? 'right' : 'left';
        final targetX = snapToRight ? rightDockX : leftDockX;
        final targetY = currentY.clamp(minY, maxY);

        _dockSide = targetSide;
        _dockStartPos = Offset(currentX, currentY);
        _dockTargetPos = Offset(targetX, targetY);

        AppHaptics.tap();
        _savePosition(Offset(targetX, targetY), targetSide);
        _dockSnapController.forward(from: 0.0);
      },
      onTap: _openAi,
      onLongPress: _showAvatarSelector,
      child: AnimatedBuilder(
        animation: _hopController,
        builder: (context, child) {
          // Hop bounce on tap
          final hopProgress = _hopController.value;
          final hopY = -math.sin(hopProgress * math.pi) * 14.0;
          final hopOutShift = math.sin(hopProgress * math.pi) * (_peekHiddenOffset + 6.0);

          // In peeking mode, tilt cute mascot towards center of screen
          final peekingTilt = isDockedOnRight ? -0.10 : 0.10;
          final effectiveTilt = _isDragging ? _dragTilt : (isPeekingMode ? peekingTilt : 0.0);

          // Horizontal offset: if hopped, pop out into view
          final hopShiftX = isDockedOnRight ? -hopOutShift : hopOutShift;

          return Transform.translate(
            offset: Offset(hopShiftX, hopY),
            child: Transform.rotate(
              angle: effectiveTilt,
              child: child,
            ),
          );
        },
        child: AnimatedScale(
          scale: _isDragging ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: SizedBox(
            width: _mascotWidth,
            height: _mascotHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Clean drop shadow silhouette for high contrast on light & dark themes
                Positioned(
                  bottom: 0,
                  child: Image.asset(
                    _currentAvatar.assetPath,
                    width: _mascotWidth,
                    height: _mascotHeight,
                    fit: BoxFit.contain,
                    color: Colors.black.withValues(alpha: 0.35),
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                // Free-standing Chibi Mascot
                Positioned(
                  bottom: 2,
                  child: Image.asset(
                    _currentAvatar.assetPath,
                    width: _mascotWidth,
                    height: _mascotHeight,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                // AI Thinking / Computation badge
                if (isLoading)
                  Positioned(
                    top: 0,
                    right: isDockedOnRight ? null : 0,
                    left: isDockedOnRight ? 0 : null,
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.isDark ? Colors.black : Colors.white,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.65),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.black,
                        size: 11,
                      ),
                    ),
                  ),
                // Subtle glowing peek indicator tab along bezel
                if (isPeekingMode)
                  Positioned(
                    top: 18,
                    bottom: 18,
                    right: isDockedOnRight ? 0 : null,
                    left: isDockedOnRight ? null : 0,
                    child: Container(
                      width: 3.5,
                      decoration: BoxDecoration(
                        color: context.accent.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: context.accent.withValues(alpha: 0.60),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // Speech Cloud Preview Bubble
    Widget? cloudWidget;
    if (showCloud) {
      cloudWidget = BouncyPressable(
        onTap: _openAi,
        scaleDown: 0.96,
        child: Container(
          constraints: BoxConstraints(maxWidth: math.min(220.0, screenW - 90.0)),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF1E212D) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isDockedOnRight ? 16 : 4),
              bottomRight: Radius.circular(isDockedOnRight ? 4 : 16),
            ),
            border: Border.all(
              color: context.accent.withValues(alpha: context.isDark ? 0.40 : 0.60),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.accent,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: context.accent,
                  ),
                ),
              Flexible(
                child: Text(
                  snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  AppHaptics.tap();
                  ref.read(aiChatNotifierProvider.notifier).dismissCloud();
                },
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: context.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isDragging || _dockSnapController.isAnimating) {
      return Positioned(
        left: currentX,
        top: currentY,
        child: mascotWidget,
      );
    }

    if (isDockedOnRight) {
      return Positioned(
        right: -_peekHiddenOffset,
        top: currentY,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (cloudWidget != null) ...[
              cloudWidget,
              const SizedBox(width: 8),
            ],
            mascotWidget,
          ],
        ),
      );
    } else {
      return Positioned(
        left: -_peekHiddenOffset,
        top: currentY,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            mascotWidget,
            if (cloudWidget != null) ...[
              const SizedBox(width: 8),
              cloudWidget,
            ],
          ],
        ),
      );
    }
  }
}
