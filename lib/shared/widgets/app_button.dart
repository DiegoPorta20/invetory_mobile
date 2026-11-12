import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import 'pressable.dart';

enum ButtonVariant { primary, secondary, ghost, danger }

/// Pill button (web `.btn`). Shows a spinner and ignores taps while [loading].
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.small = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool small;
  final bool expand;

  (Color bg, Color fg, Color? border) get _colors => switch (variant) {
        ButtonVariant.primary => (AppColors.brand600, Colors.white, null),
        ButtonVariant.secondary => (
            AppColors.surface,
            AppColors.slate700,
            AppColors.lineStrong,
          ),
        ButtonVariant.ghost => (Colors.transparent, AppColors.slate600, null),
        ButtonVariant.danger => (AppColors.rose600, Colors.white, null),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _colors;
    final enabled = onPressed != null && !loading;
    final height = small ? 38.0 : 48.0;
    final fontSize = small ? 13.0 : 14.5;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSize(
          duration: AppMotion.fast,
          curve: AppMotion.ease,
          child: loading
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  ),
                )
              : icon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(icon, size: small ? 17 : 19, color: fg),
                    )
                  : const SizedBox.shrink(),
        ),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Urbanist',
              fontSize: fontSize,
              color: fg,
            ).w(650),
          ),
        ),
      ],
    );

    return Pressable(
      onTap: enabled ? onPressed : null,
      haptic: true,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: onPressed == null ? 0.5 : 1,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.ease,
          height: height,
          padding: EdgeInsets.symmetric(horizontal: small ? 16 : 22),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: border == null ? null : Border.all(color: border),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Round icon-only button (web `.btn-icon rounded-full`).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.filled = true,
    this.badge = false,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool filled;
  final bool badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onPressed,
        haptic: true,
        semanticLabel: tooltip,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: filled ? AppColors.surface : Colors.transparent,
                shape: BoxShape.circle,
                border: filled ? Border.all(color: AppColors.line) : null,
                boxShadow: filled
                    ? const [
                        BoxShadow(
                          color: Color(0x0F101A38),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(icon, size: 21, color: AppColors.slate700),
            ),
            if (badge)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: AppColors.brand600,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.page, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
