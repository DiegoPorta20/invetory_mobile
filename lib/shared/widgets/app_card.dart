import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'pressable.dart';

/// Off-white surface with a hairline border and soft shadow (web `.card`).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.onLongPress,
    this.accent,
    this.selected = false,
    this.radius = AppRadius.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Colour of the thin left strip used to flag low and out-of-stock rows.
  final Color? accent;
  final bool selected;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    Widget body = Padding(padding: padding, child: child);
    if (accent != null) {
      body = Stack(
        children: [
          Padding(padding: const EdgeInsets.only(left: 4), child: body),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: accent!),
          ),
        ],
      );
    }

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: margin,
      decoration: BoxDecoration(
        color: selected ? AppColors.brand50 : AppColors.surface,
        borderRadius: shape,
        border: Border.all(
          color: selected ? AppColors.brand500 : AppColors.line,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: body,
      ),
    );

    if (onTap == null && onLongPress == null) return card;
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scale: 0.985,
      child: card,
    );
  }
}
