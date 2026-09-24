import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/haptics.dart';

/// Tactile bouncy pressable widget that smoothly scales down on tap-down
/// and springs back on release, giving modern iOS/Linear tactile feel.
class BouncyPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final Duration duration;
  final bool enableHaptics;

  const BouncyPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.96,
    this.duration = const Duration(milliseconds: 110),
    this.enableHaptics = true,
  });

  @override
  State<BouncyPressable> createState() => _BouncyPressableState();
}

class _BouncyPressableState extends State<BouncyPressable> {
  bool _isPressed = false;
  Timer? _deferTimer;

  @override
  void dispose() {
    _deferTimer?.cancel();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    final inScrollable = Scrollable.maybeOf(context) != null;
    if (inScrollable) {
      _deferTimer?.cancel();
      _deferTimer = Timer(const Duration(milliseconds: 60), () {
        if (mounted) {
          setState(() => _isPressed = true);
          if (widget.enableHaptics) {
            AppHaptics.tap();
          }
        }
      });
    } else {
      setState(() => _isPressed = true);
      if (widget.enableHaptics) {
        AppHaptics.tap();
      }
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _deferTimer?.cancel();
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _deferTimer?.cancel();
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: widget.onLongPress != null
          ? () {
              if (widget.enableHaptics) AppHaptics.heavy();
              widget.onLongPress!();
            }
          : null,
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleDown : 1.0,
        duration: widget.duration,
        curve: _isPressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
