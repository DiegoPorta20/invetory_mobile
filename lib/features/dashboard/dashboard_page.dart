import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/client_config.dart';
import '../../core/data/data_revision.dart';
import '../../core/format/formatters.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/data_widgets.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/states.dart';
import '../account/account_menu.dart';
import '../movements/movement_tile.dart';
import 'trend_chart.dart';

final dashboardProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  ref.watch(dataRevisionProvider);
  final json = await ref.watch(apiClientProvider).get('/api/dashboard/summary');
  return DashboardSummary.fromJson(json);
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final user = ref.watch(authControllerProvider).user;
    final config = ref.watch(clientConfigProvider);
    final firstName = (user?.name ?? '').split(' ').first;

    return ScreenScaffold(
      title: 'Panel',
      subtitle: firstName.isEmpty
          ? 'Estado actual del inventario.'
          : 'Hola, $firstName. Así está el inventario.',
      hasTabBar: true,
      actions: const [AccountAvatarButton()],
      onRefresh: () => ref.refresh(dashboardProvider.future).then((_) {}).catchError((_) {}),
      slivers: [
        boxSliver(const _GlobalSearch()),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        summary.when(
          loading: () => boxSliver(const _DashboardSkeleton()),
          error: (error, _) => SliverToBoxAdapter(
            child: ErrorState(
              message: errorText(error),
              onRetry: () => ref.invalidate(dashboardProvider),
            ),
          ),
          data: (data) => SliverList.list(children: _content(context, data, config)),
        ),
      ],
    );
  }

  Widget _layout(List<Widget> cards) => cards.length == 1
      ? cards.first
      : _TwoColumns(left: cards[0], right: cards[1]);

  List<Widget> _content(BuildContext context, DashboardSummary d, ClientConfig? config) {
    final t = d.totals;
    final canCosts = config?.canSeeCosts ?? false;
    final canPrices = config?.canSeePrices ?? false;
    final canImports = config?.can('imports.view') ?? false;

    Widget pad(Widget child, int index, {double bottom = 12}) => Reveal(
          index: index,
          child: Padding(
            padding: EdgeInsets.fromLTRB(kGutter, 0, kGutter, bottom),
            child: child,
          ),
        );

    final valueCards = <Widget>[
      if (canPrices)
        StatCard(
          label: 'Valor a precio de venta',
          value: formatPen(t.inventoryValueAtPricePen),
          hint: 'En soles, sin IGV',
        ),
      if (config?.allows('imports') ?? false)
        StatCard(
          label: 'En camino',
          value: '${formatQuantity(t.incomingUnits)} u.',
          hint: '${t.openImports} importaciones abiertas',
          onTap: canImports ? () => context.push('/imports') : null,
        ),
    ];
    final noteCards = <Widget>[
      AlertTile(
        icon: Icons.info_outline_rounded,
        tint: AppColors.sky50,
        foreground: AppColors.sky600,
        count: t.unconfiguredMinStock,
        label: 'Sin stock mínimo configurado',
        onTap: () => context.go('/products?stockStatus=UNCONFIGURED'),
      ),
      if (canPrices)
        AlertTile(
          icon: Icons.sell_outlined,
          tint: AppColors.slate100,
          foreground: AppColors.slate600,
          count: t.withoutPrice,
          label: 'Productos sin precio',
          onTap: () => context.go('/products?hasPrice=false'),
        ),
    ];

    return [
      if (canCosts) pad(_ValueHero(totals: t), 0),
      pad(
        _TwoColumns(
          left: StatCard(
            label: 'Productos activos',
            value: formatQuantity(t.activeProducts),
            numeric: t.activeProducts.toDouble(),
            format: (v) => formatQuantity(v.round()),
          ),
          right: StatCard(
            label: 'Unidades en stock',
            value: formatQuantity(t.totalUnits),
            numeric: t.totalUnits.toDouble(),
            format: (v) => formatQuantity(v.round()),
            hint: t.consignmentUnits > 0
                ? '${formatQuantity(t.consignmentUnits)} u. en consignación'
                : null,
          ),
        ),
        1,
      ),
      if (valueCards.isNotEmpty) pad(_layout(valueCards), 2),
      pad(
        _TwoColumns(
          left: AlertTile(
            icon: Icons.warning_amber_rounded,
            tint: AppColors.rose50,
            foreground: AppColors.rose600,
            count: t.outOfStock,
            label: 'Productos sin stock',
            onTap: () => context.go('/products?stockStatus=OUT'),
          ),
          right: AlertTile(
            icon: Icons.trending_down_rounded,
            tint: AppColors.amber50,
            foreground: AppColors.amber500,
            count: t.lowStock,
            label: 'Con stock bajo',
            onTap: () => context.go('/products?stockStatus=LOW'),
          ),
        ),
        3,
      ),
      pad(_layout(noteCards), 4),
      if (t.unconfiguredMinStock > 0 && d.attention.isEmpty)
        pad(
          const InfoBanner(
            'Para recibir alertas de reposición define el stock mínimo de tus productos. Puedes hacerlo en lote desde Productos.',
          ),
          5,
        ),
      pad(_AttentionCard(items: d.attention), 6),
      pad(_CategoriesCard(rows: d.stockByCategory), 7),
      pad(TrendCard(days: d.dailyMovements), 8),
      pad(_TopSoldCard(items: d.topSold), 9),
      pad(_RecentCard(items: d.recentMovements), 10, bottom: 0),
    ];
  }
}

class _GlobalSearch extends StatelessWidget {
  const _GlobalSearch();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(color: Color(0x0D101A38), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: TextField(
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyLarge,
        onSubmitted: (value) {
          final term = value.trim();
          context.go(
            term.isEmpty
                ? '/products'
                : '/products?search=${Uri.encodeQueryComponent(term)}',
          );
        },
        decoration: const InputDecoration(
          hintText: 'Buscar producto por código o descripción',
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: Icon(Icons.search_rounded, size: 22, color: AppColors.slate400),
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _ValueHero extends StatelessWidget {
  const _ValueHero({required this.totals});

  final DashboardTotals totals;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand800, AppColors.brand900],
        ),
        boxShadow: AppShadows.lifted,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand700.withValues(alpha: 0.45),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.payments_outlined,
                        color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Valor del inventario',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.brand200),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedNumber(
                  value: totals.inventoryValuePen,
                  format: formatPen,
                  style: textTheme.displaySmall?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                totals.inventoryValuePen == 0
                    ? 'Registra costos para calcularlo'
                    : 'A costo, en soles',
                style: textTheme.bodySmall?.copyWith(color: AppColors.brand300),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title, {this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (actionLabel != null)
          AppButton(
            label: actionLabel!,
            small: true,
            variant: ButtonVariant.ghost,
            icon: Icons.chevron_right_rounded,
            onPressed: onAction,
          ),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.items});

  final List<AttentionItem> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _CardTitle(
              'Requieren reposición',
              actionLabel: 'Ver todo',
              onAction: () => context.push('/reorder'),
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 8, 22),
              child: Center(
                child: Text(
                  'No hay productos por debajo de su stock mínimo.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
                ),
              ),
            )
          else
            for (final item in items)
              Pressable(
                onTap: () => context.push('/products/${item.product.id}'),
                scale: 0.985,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.product.code} · Stock ${formatQuantity(item.product.stock)} / ${formatQuantity(item.product.minStock)}',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: AppColors.slate500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StockBadge(item.product.stockStatus),
                          const SizedBox(height: 4),
                          Text(
                            'Pedir ${formatQuantity(item.suggestedQty)}',
                            style: textTheme.labelMedium
                                ?.copyWith(color: AppColors.slate700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({required this.rows});

  final List<CategoryStock> rows;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final visible = rows.take(8).toList();
    final max = visible.fold<int>(1, (m, r) => r.units > m ? r.units : m);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stock por categoría', style: textTheme.titleMedium),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            Text(
              'Aún no hay productos con stock.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
            ),
          for (final row in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge,
                        ),
                      ),
                      Text(
                        '${formatQuantity(row.units)} u. · ${formatQuantity(row.products)} prod.',
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.slate500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  MeterBar(fraction: row.units / max),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopSoldCard extends StatelessWidget {
  const _TopSoldCard({required this.items});

  final List<TopSoldItem> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Más vendidos (30 días)', style: textTheme.titleMedium),
          const SizedBox(height: 6),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 8, 22),
              child: Center(
                child: Text(
                  'Aún no hay ventas registradas en este periodo.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
                ),
              ),
            ),
          for (var i = 0; i < items.length; i++)
            Pressable(
              onTap: () => context.push('/products/${items[i].productId}'),
              scale: 0.985,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 9, 8, 9),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.slate100,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: textTheme.labelMedium
                            ?.copyWith(color: AppColors.slate600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall,
                          ),
                          Text(
                            items[i].code,
                            style: textTheme.bodySmall
                                ?.copyWith(color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatQuantity(items[i].quantity),
                      style: textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.items});

  final List<StockMovement> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardTitle(
          'Últimos movimientos',
          actionLabel: 'Ver todos',
          onAction: () => context.go('/movements'),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          AppCard(
            child: Center(
              child: Text(
                'Todavía no hay movimientos.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
              ),
            ),
          ),
        for (final m in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MovementTile(
              movement: m,
              showStockAfter: false,
              onTap: () => context.push('/products/${m.productId}'),
            ),
          ),
      ],
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        AppCard(
          child: SizedBox(
            height: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Skeleton(width: 120, height: 12),
                SizedBox(height: 14),
                Skeleton(width: 200, height: 28),
              ],
            ),
          ),
        ),
        SizedBox(height: 12),
        SkeletonList(count: 4, height: 90),
      ],
    );
  }
}
