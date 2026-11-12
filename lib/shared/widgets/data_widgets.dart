import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import 'app_card.dart';

/// Counts up from zero the first time it appears.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final String Function(double value) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(format(value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: AppMotion.ease,
      builder: (context, current, _) => Text(format(current), style: style),
    );
  }
}

/// Horizontal progress bar that grows from the left (web `.meter-fill`).
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.fraction,
    this.color,
    this.height = 8,
  });

  final double fraction;
  /// Defaults to the company's brand color.
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final target = fraction.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: AppColors.slate100,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target),
          duration: const Duration(milliseconds: 900),
          curve: AppMotion.ease,
          builder: (context, value, _) => FractionallySizedBox(
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: color ?? AppColors.brand500,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small metric tile: label, big number and optional hint (web `ui-stat-card`).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.numeric,
    this.format,
    this.onTap,
  });

  final String label;
  final String value;
  final String? hint;

  /// When set (with [format]) the number counts up instead of showing [value].
  final double? numeric;
  final String Function(double)? format;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final valueStyle = textTheme.headlineSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: numeric != null && format != null
                ? AnimatedNumber(value: numeric!, format: format!, style: valueStyle)
                : Text(value, style: valueStyle),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: AppColors.slate400),
            ),
          ],
        ],
      ),
    );
  }
}

/// Icon tile + number + caption; used for the dashboard alert shortcuts.
class AlertTile extends StatelessWidget {
  const AlertTile({
    super.key,
    required this.icon,
    required this.tint,
    required this.foreground,
    required this.count,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color foreground;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(icon, size: 21, color: foreground),
          ),
          const SizedBox(height: 12),
          AnimatedNumber(
            value: count.toDouble(),
            format: (v) => v.round().toString(),
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
          ),
        ],
      ),
    );
  }
}
