import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// Entrance animation: fades in while rising 14px, staggered by [index] (web `rise`).
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 14,
    this.maxStagger = 8,
  });

  final Widget child;
  final int index;
  final double offset;
  final int maxStagger;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: AppMotion.ease);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    // Items far down a long list appear immediately instead of waiting for their turn.
    if (widget.index >= 12) {
      _controller.duration = AppMotion.normal;
      _controller.forward();
      return;
    }
    final delay = Duration(
      milliseconds: 40 + widget.index.clamp(0, widget.maxStagger) * 45,
    );
    _timer = Timer(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - _curve.value) * widget.offset),
          child: child,
        ),
      ),
    );
  }
}
