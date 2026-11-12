import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../models/enums.dart';

/// Soft status pill: tinted background with a leading dot (web `.badge`).
class AppBadge extends StatelessWidget {
  const AppBadge(this.label, {super.key, this.tone = Tone.neutral, this.icon});

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = tone.color;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: tone.tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 13, color: color)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Urbanist', fontSize: 12, color: color)
                  .w(650),
            ),
          ),
        ],
      ),
    );
  }
}

class StockBadge extends StatelessWidget {
  const StockBadge(this.status, {super.key});

  final StockStatus status;

  @override
  Widget build(BuildContext context) =>
      AppBadge(status.label, tone: status.tone);
}

/// Colour of the row accent for low and out-of-stock products.
Color? stockAccent(StockStatus status) => switch (status) {
      StockStatus.out => AppColors.rose400,
      StockStatus.low => AppColors.amber400,
      StockStatus.ok => null,
    };
