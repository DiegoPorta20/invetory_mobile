import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/client_config.dart';
import '../../core/data/data_revision.dart';
import '../../core/export/excel_export.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/paged_list.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import 'movement_tile.dart';
import 'movements_repository.dart';
import 'register_movement_sheet.dart';

class MovementsPage extends ConsumerStatefulWidget {
  const MovementsPage({
    super.key,
    this.query = const {},
    this.queryKey = '',
    this.showBack = false,
  });

  final Map<String, String> query;
  final String queryKey;

  /// True when opened as a detail route (from a product, count or import).
  final bool showBack;

  @override
  ConsumerState<MovementsPage> createState() => _MovementsPageState();
}

class _MovementsPageState extends ConsumerState<MovementsPage> {
  late MovementFilters _filters = MovementFilters.fromQuery(widget.query);
  late final PagedController<StockMovement> _controller = PagedController(
    fetch: (page) => ref.read(movementsRepositoryProvider).list(_filters, page),
  );

  @override
  void initState() {
    super.initState();
    _controller.reset();
  }

  @override
  void didUpdateWidget(MovementsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.queryKey != oldWidget.queryKey && widget.query.isNotEmpty) {
      _setFilters(MovementFilters.fromQuery(widget.query));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setFilters(MovementFilters next) {
    setState(() => _filters = next);
    _controller.reset();
  }

  Future<void> _openFilters() async {
    final result = await showAppSheet<MovementFilters>(
      context,
      builder: (_) => _MovementFiltersSheet(initial: _filters),
    );
    if (result != null) _setFilters(result);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dataRevisionProvider, (_, _) => _controller.refresh());
    final textTheme = Theme.of(context).textTheme;
    final f = _filters;
    final hasFilters = f.activeCount > 0;

    return ScreenScaffold(
      title: 'Movimientos',
      subtitle: 'Libro mayor de entradas, salidas y ajustes.',
      showBack: widget.showBack,
      hasTabBar: !widget.showBack,
      onRefresh: _controller.refresh,
      actions: [
        AppIconButton(
          icon: Icons.download_rounded,
          tooltip: 'Exportar a Excel',
          onPressed: () => shareExcel(
            () => ref.read(movementsRepositoryProvider).export(_filters),
            filename: datedExcelName('movimientos'),
            subject: 'Movimientos',
          ),
        ),
      ],
      fab: (ref.watch(clientConfigProvider)?.can('movements.create') ?? false)
          ? AppFab(
              label: 'Registrar',
              icon: Icons.add_rounded,
              onPressed: () => showRegisterMovementSheet(context),
            )
          : null,
      slivers: [
        PinnedBar(
          height: 66,
          child: Row(
            children: [
              Expanded(
                child: SearchPill(
                  hint: 'Producto o nota',
                  initialValue: f.search,
                  onChanged: (value) => _setFilters(f.copyWith(search: value)),
                ),
              ),
              const SizedBox(width: 10),
              AppIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Filtros',
                badge: f.activeCount - (f.search.isNotEmpty ? 1 : 0) -
                        (f.type != null ? 1 : 0) >
                    0,
                onPressed: _openFilters,
              ),
            ],
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
                    label: 'Todos',
                    selected: f.type == null,
                    onTap: () => _setFilters(f.copyWith(type: null)),
                  ),
                ),
                for (final type in MovementType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
                    child: PillChip(
                      label: type.label,
                      selected: f.type == type,
                      onTap: () => _setFilters(f.copyWith(type: type)),
                    ),
                  ),
                if (f.productId != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
                    child: PillChip(
                      label: 'Un producto',
                      icon: Icons.inventory_2_outlined,
                      selected: true,
                      onDeleted: () => _setFilters(f.copyWith(productId: null)),
                    ),
                  ),
                if (f.referenceType != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
                    child: PillChip(
                      label: f.referenceType == 'STOCK_COUNT' ? 'De un conteo' : 'De una importación',
                      selected: true,
                      onDeleted: () => _setFilters(
                        f.copyWith(referenceType: null, referenceId: null),
                      ),
                    ),
                  ),
                if (f.reason != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
                    child: PillChip(
                      label: f.reason!.label,
                      selected: true,
                      onDeleted: () => _setFilters(f.copyWith(reason: null)),
                    ),
                  ),
                if (f.from != null || f.to != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
                    child: PillChip(
                      label: '${f.from != null ? formatDate(f.from) : '…'} → ${f.to != null ? formatDate(f.to) : '…'}',
                      selected: true,
                      onDeleted: () => _setFilters(f.copyWith(from: null, to: null)),
                    ),
                  ),
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 8),
        ),
        PagedSliver<StockMovement>(
          controller: _controller,
          keyOf: (m) => m.id,
          skeletonHeight: 104,
          empty: EmptyState(
            icon: Icons.swap_horiz_rounded,
            title: 'Sin movimientos',
            description: hasFilters
                ? 'Ningún movimiento coincide con los filtros.'
                : 'Los movimientos de stock aparecerán aquí.',
            action: hasFilters
                ? AppButton(
                    label: 'Limpiar filtros',
                    variant: ButtonVariant.secondary,
                    onPressed: () => _setFilters(const MovementFilters()),
                  )
                : null,
          ),
          itemBuilder: (context, m, index) => MovementTile(
            movement: m,
            onTap: () => context.push('/products/${m.productId}'),
          ),
        ),
        SliverToBoxAdapter(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _controller.items.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Center(
                      child: Text(
                        'Mostrando ${formatQuantity(_controller.items.length)} de ${formatQuantity(_controller.total)}',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _MovementFiltersSheet extends StatefulWidget {
  const _MovementFiltersSheet({required this.initial});

  final MovementFilters initial;

  @override
  State<_MovementFiltersSheet> createState() => _MovementFiltersSheetState();
}

class _MovementFiltersSheetState extends State<_MovementFiltersSheet> {
  late MovementFilters _f = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Filtros',
      footer: SheetActions(
        primaryLabel: 'Aplicar',
        secondaryLabel: 'Limpiar',
        onSecondary: () => Navigator.of(context).pop(
          MovementFilters(search: _f.search, type: _f.type),
        ),
        onPrimary: () => Navigator.of(context).pop(_f),
      ),
      child: Column(
        children: [
          PickerField<MovementReason>(
            label: 'Motivo',
            value: _f.reason,
            nullLabel: 'Todos los motivos',
            options: [
              for (final r in MovementReason.values)
                PickerOption(value: r, label: r.label),
            ],
            onChanged: (value) => setState(() => _f = _f.copyWith(reason: value)),
          ),
          const SizedBox(height: 16),
          DateField(
            label: 'Desde',
            value: _f.from,
            onChanged: (value) => setState(() => _f = _f.copyWith(from: value)),
          ),
          const SizedBox(height: 16),
          DateField(
            label: 'Hasta',
            value: _f.to,
            onChanged: (value) => setState(() => _f = _f.copyWith(to: value)),
          ),
        ],
      ),
    );
  }
}
