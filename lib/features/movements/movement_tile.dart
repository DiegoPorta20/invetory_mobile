import 'package:flutter/material.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_card.dart';

/// One ledger row: type icon, product, reason/date and the signed quantity.
class MovementTile extends StatelessWidget {
  const MovementTile({
    super.key,
    required this.movement,
    this.onTap,
    this.showStockAfter = true,
    this.showProduct = true,
  });

  final StockMovement movement;
  final VoidCallback? onTap;
  final bool showStockAfter;
  final bool showProduct;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final m = movement;
    final tone = m.type.tone;
    final negative = m.quantity < 0;
    final icon = switch (m.type) {
      MovementType.inbound => Icons.south_west_rounded,
      MovementType.outbound => Icons.north_east_rounded,
      MovementType.adjustment => Icons.tune_rounded,
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.tint,
              borderRadius: BorderRadius.circular(AppRadius.control + 2),
            ),
            child: Icon(icon, size: 21, color: tone.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showProduct) ...[
                  Text(
                    m.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.productCode,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  '${m.type.label} · ${m.reason.label}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.slate700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    formatDateTime(m.occurredAt),
                    if (m.userName != null) m.userName!,
                  ].join(' · '),
                  style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                ),
                if (m.counterparty != null && m.counterparty!.isNotEmpty)
                  Text(
                    m.counterparty!,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                  ),
                if (m.note != null && m.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      m.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.slate500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatSignedQuantity(m.quantity),
                style: textTheme.titleMedium?.copyWith(
                  color: negative ? AppColors.rose600 : AppColors.emerald700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (showStockAfter)
                Text(
                  'Stock ${formatQuantity(m.stockAfter)}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
