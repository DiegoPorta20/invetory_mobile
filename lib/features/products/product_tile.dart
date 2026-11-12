import 'package:flutter/material.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/client_config.dart';

/// Product list row: code, name, category, stock with unit, minimum and price.
class ProductTile extends ConsumerWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selecting = false,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selecting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final p = product;
    final retail = p.pricing.retail;
    final showPrice = ref.watch(canSeePricesProvider);

    return AppCard(
      onTap: onTap,
      onLongPress: onLongPress,
      accent: stockAccent(p.stockStatus),
      selected: selected,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.ease,
            alignment: Alignment.centerLeft,
            child: selecting
                ? Padding(
                    padding: const EdgeInsets.only(right: 12, top: 2),
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.brand600 : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? AppColors.brand600 : AppColors.slate300,
                          width: 1.6,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                          : null,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.slate700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    if (!p.isActive) ...[const SizedBox(width: 6), const AppBadge('Inactivo')],
                    if (p.isConsignment) ...[
                      const SizedBox(width: 6),
                      const AppBadge('Consignación', tone: Tone.info),
                    ],
                    const Spacer(),
                    StockBadge(p.stockStatus),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    p.categoryName ?? 'Sin categoría',
                    if (p.costCenterName != null) p.costCenterName!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: formatQuantity(p.stock),
                              style: textTheme.titleLarge?.copyWith(
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                              children: [
                                TextSpan(
                                  text: ' ${p.unit.label}',
                                  style: textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            [
                              if (p.minStock > 0) 'Mín. ${formatQuantity(p.minStock)}',
                              if (p.incomingQty > 0) '+${formatQuantity(p.incomingQty)} en camino',
                            ].join(' · '),
                            style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!showPrice)
                      const SizedBox.shrink()
                    else if (retail != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatPen(retail.priceWithIgvPen), style: textTheme.titleSmall),
                          Text(
                            '${formatPen(retail.pricePen)} sin IGV',
                            style: textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Sin precio',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
