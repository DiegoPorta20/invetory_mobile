import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/client_config.dart';
import '../../core/data/data_revision.dart';
import '../../core/format/formatters.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/data_widgets.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/toast.dart';
import '../movements/movement_tile.dart';
import '../movements/register_movement_sheet.dart';
import 'products_repository.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  bool _showImports = false;

  Future<void> _refresh() async {
    ref.invalidate(productDetailProvider(widget.id));
    ref.invalidate(productMovementsProvider(widget.id));
    ref.invalidate(productImportsProvider(widget.id));
    try {
      await ref.read(productDetailProvider(widget.id).future);
    } catch (_) {}
  }

  Future<void> _toggleActive(Product p) async {
    try {
      await ref.read(productsRepositoryProvider).update(p.id, {'isActive': !p.isActive});
      ref.read(dataRevisionProvider.notifier).bump();
      Toast.success(p.isActive ? 'Producto desactivado.' : 'Producto activado.');
    } catch (error) {
      Toast.error(errorText(error));
    }
  }

  Future<void> _remove(Product p) async {
    final confirmed = await confirmAction(
      context,
      title: 'Eliminar producto',
      message: '¿Eliminar "${p.name}" (${p.code})? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(productsRepositoryProvider).remove(p.id);
      ref.read(dataRevisionProvider.notifier).bump();
      Toast.success('Producto eliminado.');
      if (mounted) context.pop();
    } catch (error) {
      Toast.error(errorText(error));
    }
  }

  void _openMenu(Product p) {
    final config = ref.read(clientConfigProvider);
    final canUpdate = config?.can('products.update') ?? false;
    final canDelete = config?.can('products.delete') ?? false;
    showAppSheet<void>(
      context,
      builder: (sheetContext) => SheetFrame(
        title: 'Acciones',
        subtitle: p.code,
        child: Column(
          children: [
            if (canUpdate)
              _MenuRow(
                icon: Icons.edit_outlined,
                label: 'Editar producto',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/products/${p.id}/edit');
                },
              ),
            if (canUpdate)
              _MenuRow(
                icon: p.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                label: p.isActive ? 'Desactivar' : 'Activar',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _toggleActive(p);
                },
              ),
            if (canUpdate && canDelete) const Divider(),
            if (canDelete)
              _MenuRow(
                icon: Icons.delete_outline_rounded,
                label: 'Eliminar',
                color: AppColors.rose600,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _remove(p);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(productDetailProvider(widget.id));
    final config = ref.watch(clientConfigProvider);
    final canUpdate = config?.can('products.update') ?? false;
    final canDelete = config?.can('products.delete') ?? false;
    final canMove = config?.can('movements.create') ?? false;

    return detail.when(
      loading: () =>
          const ScreenScaffold(title: 'Producto', showBack: true, slivers: [_DetailSkeleton()]),
      error: (error, _) => ScreenScaffold(
        title: 'Producto',
        showBack: true,
        slivers: [
          SliverToBoxAdapter(
            child: ErrorState(
              message: errorText(error),
              onRetry: () => ref.invalidate(productDetailProvider(widget.id)),
            ),
          ),
        ],
      ),
      data: (p) => ScreenScaffold(
        title: p.name,
        showBack: true,
        onRefresh: _refresh,
        actions: [
          if (canUpdate || canDelete)
            AppIconButton(
              icon: Icons.more_horiz_rounded,
              tooltip: 'Más acciones',
              onPressed: () => _openMenu(p),
            ),
        ],
        bottomBar: (canUpdate || canMove)
            ? Row(
                children: [
                  if (canUpdate)
                    Expanded(
                      child: AppButton(
                        label: 'Editar',
                        icon: Icons.edit_outlined,
                        variant: ButtonVariant.secondary,
                        onPressed: () => context.push('/products/${p.id}/edit'),
                      ),
                    ),
                  if (canUpdate && canMove) const SizedBox(width: 12),
                  if (canMove)
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: 'Registrar movimiento',
                        icon: Icons.swap_horiz_rounded,
                        onPressed: () => showRegisterMovementSheet(context, product: p),
                      ),
                    ),
                ],
              )
            : null,
        slivers: [_content(context, p)],
      ),
    );
  }

  Widget _content(BuildContext context, Product p) {
    final textTheme = Theme.of(context).textTheme;
    final config = ref.watch(clientConfigProvider);
    final canImports = config?.can('imports.view') ?? false;
    final showImports = _showImports && canImports;
    final movements = ref.watch(productMovementsProvider(widget.id));
    final imports = canImports ? ref.watch(productImportsProvider(widget.id)) : null;

    Widget section(int index, Widget child) => Reveal(
      index: index,
      child: Padding(padding: const EdgeInsets.only(bottom: 14), child: child),
    );

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      sliver: SliverList.list(
        children: [
          section(
            0,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(p.code, style: textTheme.titleSmall?.copyWith(color: AppColors.slate700)),
                if (p.isInternalCode) const AppBadge('Código interno'),
                StockBadge(p.stockStatus),
                if (!p.isActive) const AppBadge('Inactivo'),
                if (p.isConsignment) const AppBadge('Consignación', tone: Tone.info),
                if (p.categoryPath != null)
                  Text(
                    p.categoryPath!,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                  ),
              ],
            ),
          ),
          section(1, _StockCard(product: p)),
          if (config?.canSeePrices == true || config?.canSeeCosts == true)
            section(
              2,
              _PricesCard(
                product: p,
                showPrices: config?.canSeePrices ?? false,
                showCost: config?.canSeeCosts ?? false,
              ),
            ),
          section(3, _DetailsCard(product: p)),
          section(
            4,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canImports) ...[
                  SegmentedPills<bool>(
                    options: const [(false, 'Movimientos'), (true, 'Importaciones')],
                    value: showImports,
                    onChanged: (value) => setState(() => _showImports = value),
                  ),
                  const SizedBox(height: 12),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('Movimientos', style: textTheme.titleMedium),
                  ),
                AnimatedSize(
                  duration: AppMotion.normal,
                  curve: AppMotion.ease,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: AppMotion.normal,
                    switchInCurve: AppMotion.ease,
                    child: KeyedSubtree(
                      key: ValueKey(showImports),
                      child: showImports && imports != null
                          ? _importsList(context, imports)
                          : _movementsList(context, movements, p),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _movementsList(
    BuildContext context,
    AsyncValue<PagedResult<StockMovement>> movements,
    Product p,
  ) {
    return movements.when(
      loading: () => const SkeletonList(count: 3, height: 80),
      error: (error, _) => ErrorState(
        message: errorText(error),
        onRetry: () => ref.invalidate(productMovementsProvider(widget.id)),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return const AppCard(child: Center(child: Text('Sin movimientos registrados.')));
        }
        return Column(
          children: [
            for (final m in page.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MovementTile(movement: m, showProduct: false),
              ),
            AppButton(
              label: 'Ver todos los movimientos',
              variant: ButtonVariant.ghost,
              small: true,
              icon: Icons.chevron_right_rounded,
              onPressed: () => context.push('/history?productId=${p.id}'),
            ),
          ],
        );
      },
    );
  }

  Widget _importsList(BuildContext context, AsyncValue<PagedResult<ImportOrderSummary>> imports) {
    final textTheme = Theme.of(context).textTheme;
    return imports.when(
      loading: () => const SkeletonList(count: 2, height: 80),
      error: (error, _) => ErrorState(
        message: errorText(error),
        onRetry: () => ref.invalidate(productImportsProvider(widget.id)),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return const AppCard(
            child: Center(child: Text('Este producto no está en ninguna importación.')),
          );
        }
        return Column(
          children: [
            for (final order in page.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => context.push('/imports/${order.id}'),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Importación #${order.number}', style: textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              order.supplierName ?? 'Sin proveedor',
                              style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppBadge(order.status.label, tone: order.status.tone),
                          const SizedBox(height: 4),
                          Text(
                            '${formatQuantity(order.totalReceived)} / ${formatQuantity(order.totalOrdered)}',
                            style: textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color ?? AppColors.slate600),
            const SizedBox(width: 14),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: color ?? AppColors.slate800, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final textTheme = Theme.of(context).textTheme;

    Widget metric(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodySmall?.copyWith(color: AppColors.slate500)),
          const SizedBox(height: 3),
          Text(value, style: textTheme.titleMedium),
        ],
      ),
    );

    final tone = p.stockStatus.tone.color;
    final ratio = p.minStock > 0 ? p.stock / (p.minStock * 2) : (p.stock > 0 ? 1.0 : 0.0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Stock'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedNumber(
                value: p.stock.toDouble(),
                format: (v) => formatQuantity(v.round()),
                style: textTheme.displaySmall?.copyWith(color: tone),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  p.unit.label,
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MeterBar(fraction: ratio, color: tone),
          const SizedBox(height: 16),
          Row(
            children: [
              metric('Stock mínimo', p.minStock > 0 ? formatQuantity(p.minStock) : '—'),
              metric('Reposición', p.reorderQuantity > 0 ? formatQuantity(p.reorderQuantity) : '—'),
              metric('En camino', p.incomingQty > 0 ? formatQuantity(p.incomingQty) : '—'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PricesCard extends StatelessWidget {
  const _PricesCard({required this.product, required this.showPrices, required this.showCost});

  final Product product;
  final bool showPrices;
  final bool showCost;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final textTheme = Theme.of(context).textTheme;
    final retail = p.pricing.retail;
    final wholesale = p.pricing.wholesale;
    final margin = p.pricing.marginPercent;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(showPrices ? 'Precios' : 'Costos'),
          const SizedBox(height: 10),
          if (showPrices && retail != null) ...[
            Text.rich(
              TextSpan(
                text: formatPen(retail.priceWithIgvPen),
                style: textTheme.headlineSmall,
                children: [
                  TextSpan(
                    text: '  con IGV',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            DetailRow('Precio sin IGV', formatPen(retail.pricePen)),
            DetailRow('IGV', formatPen(retail.igvPen)),
            if (margin != null && showCost)
              DetailRow(
                'Margen',
                formatPercent(margin),
                valueStyle: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: margin >= 0 ? AppColors.emerald700 : AppColors.rose600,
                ),
              ),
            if (wholesale != null) ...[
              const Divider(height: 24),
              Text(
                wholesale.minQty != null
                    ? 'Por mayor (desde ${formatQuantity(wholesale.minQty)} unidades)'
                    : 'Por mayor',
                style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  text: formatPen(wholesale.priceWithIgvPen),
                  style: textTheme.titleLarge,
                  children: [
                    TextSpan(
                      text: '  con IGV · ${formatPen(wholesale.pricePen)} sin IGV',
                      style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (showPrices) ...[
            Text(
              'Sin precio registrado.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
            ),
          ],
          if (showPrices && showCost) const Divider(height: 24),
          if (showCost) DetailRow('Costo (sin IGV)', formatPen(p.costPen, precise: true)),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final textTheme = Theme.of(context).textTheme;

    Widget block(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodySmall?.copyWith(color: AppColors.slate500)),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Detalles'),
          const SizedBox(height: 6),
          DetailRow('Unidad', p.unit.label),
          DetailRow('Ubicación', p.location ?? '—'),
          DetailRow('Categoría', p.categoryName ?? 'Sin categoría'),
          DetailRow('Centro de costo', p.costCenterName ?? '—'),
          DetailRow('Consignación', p.isConsignment ? 'Sí' : 'No'),
          if (p.description != null && p.description!.isNotEmpty)
            block('Descripción', Text(p.description!, style: textTheme.bodyMedium)),
          if (p.specification != null && p.specification!.isNotEmpty)
            block('Especificación', Text(p.specification!, style: textTheme.bodyMedium)),
          if (p.equipment.isNotEmpty)
            block(
              'Equipos compatibles',
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final model in p.equipment) AppBadge(model.name, tone: Tone.brand)],
              ),
            ),
          if (p.notes != null && p.notes!.isNotEmpty)
            block('Notas', Text(p.notes!, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: kGutter),
      sliver: SliverToBoxAdapter(child: SkeletonList(count: 4, height: 130)),
    );
  }
}
