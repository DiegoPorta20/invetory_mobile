import 'package:flutter/material.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_card.dart';

const _trendDays = 30;

class _Day {
  const _Day(this.date, this.inQty, this.outQty);
  final String date;
  final int inQty;
  final int outQty;
}

/// Stacked entries/exits per day for the last 30 days (Lima calendar).
List<_Day> _buildDays(List<DailyMovement> source) {
  final byDate = {for (final d in source) d.date: d};
  final nowLima = DateTime.now().toUtc().subtract(const Duration(hours: 5));
  return List.generate(_trendDays, (index) {
    final date = nowLima.subtract(Duration(days: _trendDays - 1 - index));
    final key = toIsoDay(date);
    final entry = byDate[key];
    return _Day(key, entry?.inQty ?? 0, entry?.outQty ?? 0);
  });
}

class TrendCard extends StatefulWidget {
  const TrendCard({super.key, required this.days});

  final List<DailyMovement> days;

  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final days = _buildDays(widget.days);
    final maxTotal = days.fold<int>(1, (m, d) {
      final total = d.inQty + d.outQty;
      return total > m ? total : m;
    });
    final selected = _selected == null ? null : days[_selected!];

    Widget legend(Color color, String label) => Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
            ),
          ],
        );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Movimientos de 30 días', style: textTheme.titleMedium),
              ),
              legend(AppColors.emerald500, 'Entradas'),
              const SizedBox(width: 12),
              legend(AppColors.rose500, 'Salidas'),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: AppMotion.fast,
            child: SizedBox(
              key: ValueKey(_selected),
              height: 20,
              child: Text(
                selected == null
                    ? 'Toca una barra para ver el detalle.'
                    : '${formatShortDay(selected.date)}: +${formatQuantity(selected.inQty)} / −${formatQuantity(selected.outQty)}',
                style: textTheme.bodySmall?.copyWith(
                  color: selected == null ? AppColors.slate400 : AppColors.slate700,
                  fontWeight: selected == null ? null : FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slot = constraints.maxWidth / days.length;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => setState(() {
                    _selected = (details.localPosition.dx / slot)
                        .floor()
                        .clamp(0, days.length - 1);
                  }),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: AppMotion.ease,
                    builder: (context, progress, _) => CustomPaint(
                      size: Size(constraints.maxWidth, 140),
                      painter: _BarsPainter(
                        days: days,
                        maxTotal: maxTotal,
                        progress: progress,
                        selected: _selected,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatShortDay(days.first.date),
                style: textTheme.bodySmall?.copyWith(color: AppColors.slate400),
              ),
              Text(
                formatShortDay(days.last.date),
                style: textTheme.bodySmall?.copyWith(color: AppColors.slate400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.days,
    required this.maxTotal,
    required this.progress,
    required this.selected,
  });

  final List<_Day> days;
  final int maxTotal;
  final double progress;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / days.length;
    final barWidth = slot * 0.62;
    final inPaint = Paint()..color = AppColors.emerald500;
    final outPaint = Paint()..color = AppColors.rose500;
    final basePaint = Paint()..color = AppColors.slate100;
    final highlight = Paint()..color = AppColors.brand100;

    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final x = i * slot + (slot - barWidth) / 2;

      if (selected == i) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(i * slot, 0, slot, size.height),
            const Radius.circular(6),
          ),
          highlight,
        );
      }

      // Each bar grows slightly after the previous one, left to right.
      final local = ((progress * 1.6) - (i / days.length) * 0.6).clamp(0.0, 1.0);
      final inH = day.inQty / maxTotal * size.height * local;
      final outH = day.outQty / maxTotal * size.height * local;

      if (inH == 0 && outH == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - 3, barWidth, 3),
            const Radius.circular(2),
          ),
          basePaint,
        );
        continue;
      }

      var bottom = size.height;
      if (outH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, bottom - outH, barWidth, outH),
            bottomLeft: const Radius.circular(3),
            bottomRight: const Radius.circular(3),
            topLeft: inH == 0 ? const Radius.circular(3) : Radius.zero,
            topRight: inH == 0 ? const Radius.circular(3) : Radius.zero,
          ),
          outPaint,
        );
        bottom -= outH + 1;
      }
      if (inH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, bottom - inH, barWidth, inH),
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
            bottomLeft: outH == 0 ? const Radius.circular(3) : Radius.zero,
            bottomRight: outH == 0 ? const Radius.circular(3) : Radius.zero,
          ),
          inPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.progress != progress || old.selected != selected || old.days != days;
}
