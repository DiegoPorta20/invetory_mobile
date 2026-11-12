import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/client_config.dart';
import '../../core/data/data_revision.dart';
import '../../core/data/reference_data.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/data_widgets.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/paged_list.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/states.dart';
import 'imports_repository.dart';

class ImportsPage extends ConsumerStatefulWidget {
  const ImportsPage({super.key});

  @override
  ConsumerState<ImportsPage> createState() => _ImportsPageState();
}

class _ImportsPageState extends ConsumerState<ImportsPage> {
  ImportFilters _filters = const ImportFilters();
  late final PagedController<ImportOrderSummary> _controller = PagedController(
    fetch: (page) => ref.read(importsRepositoryProvider).list(_filters, page),
  );

  @override
  void initState() {
    super.initState();
    _controller.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setFilters(ImportFilters next) {
    setState(() => _filters = next);
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dataRevisionProvider, (_, _) => _controller.refresh());
    final suppliers = ref.watch(suppliersProvider).asData?.value ?? const [];
    final canCreate = ref.watch(clientConfigProvider)?.can('imports.create') ?? false;
    String? supplierName;
    for (final s in suppliers) {
      if (s.id == _filters.supplierId) supplierName = s.name;
    }

    return ScreenScaffold(
      title: 'Importaciones',
      subtitle: 'Pedidos a proveedores y recepciones.',
      showBack: true,
      onRefresh: _controller.refresh,
      fab: canCreate
          ? AppFab(
              label: 'Nueva importación',
              icon: Icons.add_rounded,
              onPressed: () => context.push('/imports/new'),
            )
          : null,
      slivers: [
        PinnedBar(
          height: 66,
          child: SearchPill(
            hint: 'Número o producto',
            initialValue: _filters.search,
            onChanged: (value) => _setFilters(_filters.copyWith(search: value)),
          ),
        ),
        boxSliver(
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
                  child: PillChip(
                    label: 'Todas',
                    selected: _filters.status == null,
                    onTap: () => _setFilters(_filters.copyWith(status: null)),
                  ),
                ),
                for (final status in ImportStatus.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
                    child: PillChip(
                      label: status.label,
                      selected: _filters.status == status,
                      onTap: () => _setFilters(_filters.copyWith(status: status)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
                  child: PillChip(
                    label: supplierName ?? 'Proveedor',
                    icon: _filters.supplierId == null ? Icons.expand_more_rounded : null,
                    selected: _filters.supplierId != null,
                    onDeleted: _filters.supplierId == null
                        ? null
                        : () => _setFilters(_filters.copyWith(supplierId: null)),
                    onTap: _filters.supplierId != null
                        ? null
                        : () async {
                            final picked = await showPickerSheet<int>(
                              context,
                              title: 'Proveedor',
                              searchable: true,
                              options: [
                                for (final s in suppliers)
                                  PickerOption(value: s.id, label: s.name),
                              ],
                            );
                            if (picked != null) {
                              _setFilters(_filters.copyWith(supplierId: picked));
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 8),
        ),
        PagedSliver<ImportOrderSummary>(
          controller: _controller,
          keyOf: (o) => o.id,
          skeletonHeight: 130,
          empty: EmptyState(
            icon: Icons.local_shipping_outlined,
            title: 'Sin importaciones',
            description: _filters.activeCount > 0
                ? 'Ninguna importación coincide con los filtros.'
                : 'Registra un pedido a un proveedor para llevar el control de lo que viene en camino.',
            action: canCreate
                ? AppButton(
                    label: 'Nueva importación',
                    icon: Icons.add_rounded,
                    onPressed: () => context.push('/imports/new'),
                  )
                : null,
          ),
          itemBuilder: (context, order, index) => ImportCard(
            order: order,
            onTap: () => context.push('/imports/${order.id}'),
          ),
        ),
      ],
    );
  }
}

class ImportCard extends ConsumerWidget {
  const ImportCard({super.key, required this.order, required this.onTap});

  final ImportOrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCost = ref.watch(clientConfigProvider)?.canSeeCosts ?? false;
    final textTheme = Theme.of(context).textTheme;
    final fraction = order.totalOrdered == 0 ? 0.0 : order.totalReceived / order.totalOrdered;
    final dates = [
      if (order.orderedAt != null) 'Pedido ${formatDate(order.orderedAt)}',
      if (order.expectedAt != null && order.status != ImportStatus.received)
        'Llega ${formatDate(order.expectedAt)}',
      if (order.receivedAt != null) 'Recibido ${formatDate(order.receivedAt)}',
    ];

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Importación #${order.number}', style: textTheme.titleMedium),
              ),
              AppBadge(order.status.label, tone: order.status.tone),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            [
              order.supplierName ?? 'Sin proveedor',
              if (order.reference != null && order.reference!.isNotEmpty) order.reference!,
            ].join(' · '),
            style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
          ),
          if (dates.isNotEmpty)
            Text(
              dates.join(' · '),
              style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
            ),
          const SizedBox(height: 14),
          MeterBar(
            fraction: fraction,
            color: order.status == ImportStatus.cancelled
                ? AppColors.slate300
                : AppColors.emerald500,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${formatQuantity(order.totalReceived)} / ${formatQuantity(order.totalOrdered)} u. · ${order.itemCount} líneas',
                style: textTheme.labelMedium?.copyWith(color: AppColors.slate700),
              ),
              const Spacer(),
              if (showCost) Text(formatPen(order.totalCostPen), style: textTheme.titleSmall),
            ],
          ),
        ],
      ),
    );
  }
}
