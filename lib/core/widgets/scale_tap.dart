import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/haptics.dart';

class ScaleTap extends StatefulWidget {
  const ScaleTap({
    super.key,
    required this.onPressed,
    required this.child,
    this.scaleDown = 0.97,
    this.enableHaptic = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double scaleDown;
  final bool enableHaptic;

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> {
  bool _down = false;
  Timer? _deferTimer;

  @override
  void dispose() {
    _deferTimer?.cancel();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    final inScrollable = Scrollable.maybeOf(context) != null;
    if (inScrollable) {
      _deferTimer?.cancel();
      _deferTimer = Timer(const Duration(milliseconds: 60), () {
        if (mounted) {
          if (widget.enableHaptic) {
            AppHaptics.tap();
          }
          setState(() => _down = true);
        }
      });
    } else {
      if (widget.enableHaptic) {
        AppHaptics.tap();
      }
      setState(() => _down = true);
    }
  }

  void _onTapCancel() {
    _deferTimer?.cancel();
    if (_down) {
      setState(() => _down = false);
    }
  }

  void _onTapUp(TapUpDetails details) {
    _deferTimer?.cancel();
    if (_down) {
      setState(() => _down = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onPressed != null ? _onTapDown : null,
      onTapCancel: _onTapCancel,
      onTapUp: _onTapUp,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _down ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
