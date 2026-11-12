import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/router/navigator_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';

/// Short feedback message that pops in above the tab bar (web `ToastService`).
abstract final class Toast {
  static OverlayEntry? _entry;
  static Timer? _timer;
  static GlobalKey<_ToastViewState>? _viewKey;

  static void success(String message) => _show(message, Tone.success);
  static void error(String message) => _show(message, Tone.danger);
  static void info(String message) => _show(message, Tone.info);

  static void _show(String message, Tone tone) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    _dismissNow();

    final key = GlobalKey<_ToastViewState>();
    _viewKey = key;
    _entry = OverlayEntry(
      builder: (_) => _ToastView(key: key, message: message, tone: tone),
    );
    overlay.insert(_entry!);
    SemanticsService.sendAnnouncement(
      View.of(overlay.context),
      message,
      TextDirection.ltr,
    );
    _timer = Timer(
      Duration(milliseconds: tone == Tone.danger ? 4500 : 2800),
      _dismiss,
    );
  }

  static void _dismiss() {
    final state = _viewKey?.currentState;
    if (state == null) return _dismissNow();
    state.hide().then((_) => _dismissNow());
  }

  static void _dismissNow() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
    _viewKey = null;
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({super.key, required this.message, required this.tone});

  final String message;
  final Tone tone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    reverseDuration: const Duration(milliseconds: 220),
  )..forward();
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: AppMotion.ease);

  Future<void> hide() => _controller.reverse().orCancel.catchError((_) {});

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (widget.tone) {
      Tone.success => (Icons.check_circle_rounded, AppColors.emerald500),
      Tone.danger => (Icons.error_rounded, AppColors.rose400),
      _ => (Icons.info_rounded, AppColors.accent400),
    };
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom + 96,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _curve,
          builder: (context, child) => Opacity(
            opacity: _curve.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - _curve.value) * 16),
              child: Transform.scale(
                scale: 0.96 + 0.04 * _curve.value,
                child: child,
              ),
            ),
          ),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.brand900,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppShadows.lifted,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 21, color: color),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          fontFamily: 'Urbanist',
                          fontSize: 14,
                          color: Colors.white,
                        ).w(600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
