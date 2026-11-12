import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/client_config.dart';
import '../../core/data/data_revision.dart';
import '../../core/format/formatters.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/data_widgets.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/toast.dart';
import 'imports_repository.dart';
import 'receive_import_sheet.dart';

class ImportDetailPage extends ConsumerStatefulWidget {
  const ImportDetailPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ImportDetailPage> createState() => _ImportDetailPageState();
}

class _ImportDetailPageState extends ConsumerState<ImportDetailPage> {
  bool _busy = false;

  bool _can(String permission) =>
      ref.read(clientConfigProvider)?.can(permission) ?? false;

  /// Saving the form replaces every line, which erases unit costs the user cannot see.
  bool get _canEdit =>
      _can('imports.update') && (ref.read(clientConfigProvider)?.canSeeCosts ?? false);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      Toast.error(errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(ImportStatus status, String message) => _run(() async {
        await ref.read(importsRepositoryProvider).changeStatus(widget.id, status);
        ref.read(dataRevisionProvider.notifier).bump();
        Toast.success(message);
      });

  Future<void> _cancelOrder() async {
    final ok = await confirmAction(
      context,
      title: 'Cancelar importación',
      message: '¿Seguro que deseas cancelar esta importación?',
      confirmLabel: 'Cancelar importación',
      cancelLabel: 'Volver',
      danger: true,
    );
    if (ok) await _setStatus(ImportStatus.cancelled, 'Importación cancelada.');
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Eliminar importación',
      message: 'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      danger: true,
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(importsRepositoryProvider).remove(widget.id);
      ref.read(dataRevisionProvider.notifier).bump();
      Toast.success('Importación eliminada.');
      if (mounted) context.pop();
    });
  }

  Future<void> _receive(ImportOrderDetail order) async {
    await showReceiveImportSheet(context, order);
  }

  bool _hasMenu(ImportStatus status) =>
      (status.isEditable && _can('imports.update')) ||
      (status == ImportStatus.draft && _can('imports.delete')) ||
      _can('movements.view');

  void _openMenu(ImportOrderDetail order) {
    final status = order.summary.status;
    final canUpdate = _can('imports.update');
    final canCancel = canUpdate && status.isEditable;
    final canDelete = _can('imports.delete') && status == ImportStatus.draft;
    showAppSheet<void>(
      context,
      builder: (sheetContext) => SheetFrame(
        title: 'Acciones',
        subtitle: 'Importación #${order.summary.number}',
        child: Column(
          children: [
            if (status.isEditable && _canEdit)
              _Action(
                icon: Icons.edit_outlined,
                label: 'Editar importación',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/imports/${order.summary.id}/edit');
                },
              ),
            if (_can('movements.view'))
            _Action(
              icon: Icons.swap_horiz_rounded,
              label: 'Ver movimientos generados',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(
                  '/history?referenceType=IMPORT_ORDER&referenceId=${order.summary.id}',
                );
              },
            ),
            if (canCancel) ...[
              const Divider(),
              _Action(
                icon: Icons.cancel_outlined,
                label: 'Cancelar importación',
                color: AppColors.rose600,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _cancelOrder();
                },
              ),
            ],
            if (canDelete)
              _Action(
                icon: Icons.delete_outline_rounded,
                label: 'Eliminar borrador',
                color: AppColors.rose600,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _delete();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget? _bottomBar(ImportOrderDetail order) {
    final canUpdate = _can('imports.update');
    final canReceive = _can('imports.receive');
    switch (order.summary.status) {
      case ImportStatus.draft:
        if (!canUpdate) return null;
        return AppButton(
          label: 'Marcar como pedido',
          icon: Icons.send_outlined,
          expand: true,
          loading: _busy,
          onPressed: () => _setStatus(ImportStatus.ordered, 'Importación marcada como pedida.'),
        );
      case ImportStatus.ordered:
        if (!canUpdate && !canReceive) return null;
        return Row(
          children: [
            if (canUpdate)
            Expanded(
              child: AppButton(
                label: 'En tránsito',
                icon: Icons.local_shipping_outlined,
                variant: ButtonVariant.secondary,
                loading: _busy,
                onPressed: () =>
                    _setStatus(ImportStatus.inTransit, 'Importación en tránsito.'),
              ),
            ),
            if (canUpdate && canReceive) const SizedBox(width: 12),
            if (canReceive)
            Expanded(
              child: AppButton(
                label: 'Recibir',
                icon: Icons.inventory_rounded,
                onPressed: _busy ? null : () => _receive(order),
              ),
            ),
          ],
        );
      case ImportStatus.inTransit:
        if (!canReceive) return null;
        return AppButton(
          label: 'Recibir mercadería',
          icon: Icons.inventory_rounded,
          expand: true,
          onPressed: _busy ? null : () => _receive(order),
        );
      case ImportStatus.received:
      case ImportStatus.cancelled:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(importDetailProvider(widget.id));

    return detail.when(
      loading: () => const ScreenScaffold(
        title: 'Importación',
        showBack: true,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: kGutter),
            sliver: SliverToBoxAdapter(child: SkeletonList(count: 3, height: 130)),
          ),
        ],
      ),
      error: (error, _) => ScreenScaffold(
        title: 'Importación',
        showBack: true,
        slivers: [
          SliverToBoxAdapter(
            child: ErrorState(
              message: errorText(error),
              onRetry: () => ref.invalidate(importDetailProvider(widget.id)),
            ),
          ),
        ],
      ),
      data: (order) => _content(context, order),
    );
  }

  Widget _content(BuildContext context, ImportOrderDetail order) {
    final textTheme = Theme.of(context).textTheme;
    final s = order.summary;
    final showCost = ref.watch(clientConfigProvider)?.canSeeCosts ?? false;
    final fraction = s.totalOrdered == 0 ? 0.0 : s.totalReceived / s.totalOrdered;

    return ScreenScaffold(
      title: 'Importación #${s.number}',
      showBack: true,
      onRefresh: () async {
        ref.invalidate(importDetailProvider(widget.id));
        try {
          await ref.read(importDetailProvider(widget.id).future);
        } catch (_) {}
      },
      actions: [
        if (_hasMenu(s.status))
          AppIconButton(
            icon: Icons.more_horiz_rounded,
            tooltip: 'Más acciones',
            onPressed: () => _openMenu(order),
          ),
      ],
      bottomBar: _bottomBar(order),
      slivers: [
        gutterSliver(
          SliverList.list(
            children: [
              Reveal(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppBadge(s.status.label, tone: s.status.tone),
                            const Spacer(),
                            if (showCost)
                              Text(formatPen(s.totalCostPen), style: textTheme.titleLarge),
                          ],
                        ),
                        const SizedBox(height: 14),
                        MeterBar(fraction: fraction, color: AppColors.emerald500),
                        const SizedBox(height: 8),
                        Text(
                          '${formatQuantity(s.totalReceived)} de ${formatQuantity(s.totalOrdered)} unidades recibidas',
                          style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                        ),
                        const Divider(height: 28),
                        DetailRow('Proveedor', s.supplierName ?? '—'),
                        DetailRow('Referencia', s.reference ?? '—'),
                        DetailRow('Fecha de pedido', formatDate(s.orderedAt)),
                        DetailRow('Fecha esperada', formatDate(s.expectedAt)),
                        DetailRow('Fecha de recepción', formatDate(s.receivedAt)),
                        if (s.notes != null && s.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            s.notes!,
                            style: textTheme.bodyMedium?.copyWith(color: AppColors.slate600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 2),
                child: SectionTitle('Productos (${order.items.length})'),
              ),
              for (var i = 0; i < order.items.length; i++)
                Reveal(
                  key: ValueKey(order.items[i].id),
                  index: i + 1,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ItemCard(
                      item: order.items[i],
                      showCost: showCost,
                      onTap: () => context.push('/products/${order.items[i].productId}'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.showCost, required this.onTap});

  final ImportOrderItem item;
  final bool showCost;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final complete = item.quantityReceived >= item.quantityOrdered && item.quantityReceived > 0;
    final subtotal =
        item.unitCostPen == null ? null : item.unitCostPen! * item.quantityOrdered;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productCode,
                    style: textTheme.labelLarge?.copyWith(color: AppColors.slate700)),
                const SizedBox(height: 3),
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                if (showCost) ...[
                const SizedBox(height: 4),
                Text(
                  'Costo unit. ${formatPen(item.unitCostPen, precise: true)}'
                  '${subtotal != null ? ' · ${formatPen(subtotal)}' : ''}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${formatQuantity(item.quantityReceived)} / ${formatQuantity(item.quantityOrdered)}',
                style: textTheme.titleMedium,
              ),
              Text(
                item.unit.label,
                style: textTheme.bodySmall?.copyWith(color: AppColors.slate400),
              ),
              if (complete) ...[
                const SizedBox(height: 4),
                const AppBadge('Recibido', tone: Tone.success),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

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
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: color ?? AppColors.slate800,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
