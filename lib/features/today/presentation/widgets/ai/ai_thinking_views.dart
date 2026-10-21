import 'package:flutter/material.dart';
import 'package:ironlog/core/theme/app_colors.dart';
import 'package:ironlog/core/utils/haptics.dart';

// ── Agent Thoughts Widget (Tool Calls Shown Lively as Thinking Stuffs) ─────
class AgentThoughtsWidget extends StatefulWidget {
  final List<String> thoughts;
  final bool isStreaming;
  final String? activeThought;
  final bool hasContent;

  const AgentThoughtsWidget({
    super.key,
    required this.thoughts,
    required this.isStreaming,
    this.activeThought,
    this.hasContent = false,
  });

  @override
  State<AgentThoughtsWidget> createState() => AgentThoughtsWidgetState();
}

class AgentThoughtsWidgetState extends State<AgentThoughtsWidget> {
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
              FadingToolCallsCarousel(toolCalls: allThoughts),

            // <thinking stuffs>
            if (!hasContent) ...[
              if (allThoughts.isNotEmpty) const SizedBox(height: 5),
              WaveringShimmerText(thinkingLine),
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
              child: FadingToolCallsCarousel(
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
class FadingToolCallsCarousel extends StatefulWidget {
  final List<String> toolCalls;
  final bool showAll;

  const FadingToolCallsCarousel({
    super.key,
    required this.toolCalls,
    this.showAll = false,
  });

  @override
  State<FadingToolCallsCarousel> createState() => FadingToolCallsCarouselState();
}

class FadingToolCallsCarouselState extends State<FadingToolCallsCarousel> {
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
  void didUpdateWidget(covariant FadingToolCallsCarousel oldWidget) {
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
class WaveringShimmerText extends StatefulWidget {
  final String text;

  const WaveringShimmerText(this.text, {super.key});

  @override
  State<WaveringShimmerText> createState() => WaveringShimmerTextState();
}

class WaveringShimmerTextState extends State<WaveringShimmerText>
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
class ChatGptStreamingSentenceFade extends StatefulWidget {
  final Widget child;

  const ChatGptStreamingSentenceFade({
    super.key,
    required this.child,
  });

  @override
  State<ChatGptStreamingSentenceFade> createState() =>
      ChatGptStreamingSentenceFadeState();
}

class ChatGptStreamingSentenceFadeState
    extends State<ChatGptStreamingSentenceFade>
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

