import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/data/data_revision.dart';
import '../../core/data/reference_data.dart';
import '../../core/export/excel_export.dart';
import '../../core/format/formatters.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/data_widgets.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/states.dart';
import '../../core/config/client_config.dart';
import '../imports/imports_repository.dart';

class ReorderFilters {
  const ReorderFilters({
    this.search = '',
    this.categoryId,
    this.equipmentId,
    this.onlyOutOfStock = false,
  });

  final String search;
  final int? categoryId;
  final int? equipmentId;
  final bool onlyOutOfStock;

  @override
  bool operator ==(Object other) =>
      other is ReorderFilters &&
      other.search == search &&
      other.categoryId == categoryId &&
      other.equipmentId == equipmentId &&
      other.onlyOutOfStock == onlyOutOfStock;

  @override
  int get hashCode => Object.hash(search, categoryId, equipmentId, onlyOutOfStock);

  QueryParams toQuery() => {
        'search': search.isEmpty ? null : search,
        'categoryId': categoryId,
        'equipmentId': equipmentId,
        'onlyOutOfStock': onlyOutOfStock ? true : null,
      };
}

final reorderProvider =
    FutureProvider.autoDispose.family<ReorderReport, ReorderFilters>((ref, filters) async {
  ref.watch(dataRevisionProvider);
  final json = await ref
      .watch(apiClientProvider)
      .get('/api/reorder/suggestions', query: filters.toQuery());
  return ReorderReport.fromJson(json);
});

class ReorderPage extends ConsumerStatefulWidget {
  const ReorderPage({super.key});

  @override
  ConsumerState<ReorderPage> createState() => _ReorderPageState();
}

class _ReorderPageState extends ConsumerState<ReorderPage> {
  ReorderFilters _filters = const ReorderFilters();
  final Set<int> _selected = {};

  void _setFilters(ReorderFilters next) {
    setState(() {
      _filters = next;
      _selected.clear();
    });
  }

  void _toggle(int id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _createImport(ReorderReport report) {
    final lines = [
      for (final s in report.items)
        if (_selected.contains(s.product.id))
          ImportPrefillLine(
            productId: s.product.id,
            code: s.product.code,
            name: s.product.name,
            unit: s.product.unit,
            quantityOrdered: s.suggestedQty,
            unitCostPen: s.product.costPen,
          ),
    ];
    context.push('/imports/new', extra: ImportPrefill(lines));
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(reorderProvider(_filters));
    final categories = ref.watch(categoriesProvider).asData?.value ?? const [];
    final equipment = ref.watch(equipmentProvider).asData?.value ?? const [];
    final data = report.asData?.value;
    final config = ref.watch(clientConfigProvider);
    final canCreateImport = config?.can('imports.create') ?? false;
    final canCosts = config?.canSeeCosts ?? false;

    return ScreenScaffold(
      title: 'Reposición',
      subtitle: 'Qué pedir, cuánto y por qué.',
      showBack: true,
      actions: [
        AppIconButton(
          icon: Icons.download_rounded,
          tooltip: 'Exportar a Excel',
          onPressed: (data?.items.isEmpty ?? true)
              ? null
              : () => shareExcel(
                    () => ref
                        .read(apiClientProvider)
                        .getBytes('/api/reorder/export', query: _filters.toQuery()),
                    filename: datedExcelName('reposicion'),
                    subject: 'Reposición',
                  ),
        ),
      ],
      onRefresh: () async {
        ref.invalidate(reorderProvider(_filters));
        try {
          await ref.read(reorderProvider(_filters).future);
        } catch (_) {}
      },
      bottomBar: _selected.isEmpty || data == null || !canCreateImport
          ? null
          : AppButton(
              label: 'Crear importación (${_selected.length})',
              icon: Icons.local_shipping_outlined,
              expand: true,
              onPressed: () => _createImport(data),
            ),
      slivers: [
        PinnedBar(
          height: 66,
          child: SearchPill(
            hint: 'Código o descripción',
            initialValue: _filters.search,
            onChanged: (value) => _setFilters(
              ReorderFilters(
                search: value,
                categoryId: _filters.categoryId,
                equipmentId: _filters.equipmentId,
                onlyOutOfStock: _filters.onlyOutOfStock,
              ),
            ),
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
                    label: 'Solo críticos',
                    icon: Icons.warning_amber_rounded,
                    selected: _filters.onlyOutOfStock,
                    onTap: () => _setFilters(
                      ReorderFilters(
                        search: _filters.search,
                        categoryId: _filters.categoryId,
                        equipmentId: _filters.equipmentId,
                        onlyOutOfStock: !_filters.onlyOutOfStock,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
                  child: _PickChip(
                    label: 'Categoría',
                    selectedLabel: _nameOf(categories, _filters.categoryId, (c) => c.id, (c) => c.name),
                    options: buildCategoryOptions(categories),
                    onChanged: (value) => _setFilters(
                      ReorderFilters(
                        search: _filters.search,
                        categoryId: value,
                        equipmentId: _filters.equipmentId,
                        onlyOutOfStock: _filters.onlyOutOfStock,
                      ),
                    ),
                    value: _filters.categoryId,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
                  child: _PickChip(
                    label: 'Equipo',
                    selectedLabel: _nameOf(equipment, _filters.equipmentId, (e) => e.id, (e) => e.name),
                    options: [
                      for (final e in equipment) PickerOption(value: e.id, label: e.name),
                    ],
                    onChanged: (value) => _setFilters(
                      ReorderFilters(
                        search: _filters.search,
                        categoryId: _filters.categoryId,
                        equipmentId: value,
                        onlyOutOfStock: _filters.onlyOutOfStock,
                      ),
                    ),
                    value: _filters.equipmentId,
                  ),
                ),
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 8),
        ),
        report.when(
          loading: () => boxSliver(const SkeletonList(count: 5, height: 120)),
          error: (error, _) => SliverToBoxAdapter(
            child: ErrorState(
              message: errorText(error),
              onRetry: () => ref.invalidate(reorderProvider(_filters)),
            ),
          ),
          data: (r) => r.items.isEmpty
              ? SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.task_alt_rounded,
                    title: 'Nada por reponer',
                    description: _filters.search.isEmpty &&
                            _filters.categoryId == null &&
                            _filters.equipmentId == null &&
                            !_filters.onlyOutOfStock
                        ? 'Ningún producto está por debajo de su stock mínimo.'
                        : 'Ningún producto coincide con los filtros.',
                  ),
                )
              : SliverList.list(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 12),
                      child: _SummaryCard(
                        report: r,
                        showCost: canCosts,
                        allSelected: _selected.length == r.items.length,
                        onToggleAll: () => setState(() {
                          if (_selected.length == r.items.length) {
                            _selected.clear();
                          } else {
                            _selected
                              ..clear()
                              ..addAll(r.items.map((s) => s.product.id));
                          }
                        }),
                      ),
                    ),
                    for (var i = 0; i < r.items.length; i++)
                      Reveal(
                        key: ValueKey(r.items[i].product.id),
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 12),
                          child: _SuggestionCard(
                            suggestion: r.items[i],
                            showCost: canCosts,
                            selected: _selected.contains(r.items[i].product.id),
                            onToggle: () => _toggle(r.items[i].product.id),
                            onOpen: () => context.push('/products/${r.items[i].product.id}'),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  String? _nameOf<T>(List<T> items, int? id, int Function(T) idOf, String Function(T) nameOf) {
    if (id == null) return null;
    for (final item in items) {
      if (idOf(item) == id) return nameOf(item);
    }
    return null;
  }
}

class _PickChip extends StatelessWidget {
  const _PickChip({
    required this.label,
    required this.selectedLabel,
    required this.options,
    required this.onChanged,
    required this.value,
  });

  final String label;
  final String? selectedLabel;
  final List<PickerOption<int>> options;
  final ValueChanged<int?> onChanged;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return PillChip(
      label: selectedLabel ?? label,
      selected: value != null,
      icon: value == null ? Icons.expand_more_rounded : null,
      onDeleted: value == null ? null : () => onChanged(null),
      onTap: value != null
          ? null
          : () async {
              final picked = await showPickerSheet<int>(
                context,
                title: label,
                options: options,
                selected: value,
              );
              if (picked != null) onChanged(picked);
            },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.report,
    required this.showCost,
    required this.allSelected,
    required this.onToggleAll,
  });

  final ReorderReport report;
  final bool showCost;
  final bool allSelected;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget metric(String label, Widget value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.slate500)),
              const SizedBox(height: 3),
              value,
            ],
          ),
        );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              metric(
                'Productos',
                AnimatedNumber(
                  value: report.total.toDouble(),
                  format: (v) => formatQuantity(v.round()),
                  style: textTheme.titleLarge,
                ),
              ),
              metric(
                'Sin stock',
                AnimatedNumber(
                  value: report.outOfStock.toDouble(),
                  format: (v) => formatQuantity(v.round()),
                  style: textTheme.titleLarge?.copyWith(
                    color: report.outOfStock > 0 ? AppColors.rose600 : null,
                  ),
                ),
              ),
              if (showCost)
              metric(
                'Costo estimado',
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedNumber(
                    value: report.estimatedCostPen,
                    format: formatPen,
                    style: textTheme.titleLarge,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppButton(
            label: allSelected ? 'Quitar selección' : 'Seleccionar todos',
            icon: allSelected ? Icons.remove_done_rounded : Icons.done_all_rounded,
            variant: ButtonVariant.secondary,
            small: true,
            onPressed: onToggleAll,
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.showCost,
    required this.selected,
    required this.onToggle,
    required this.onOpen,
  });

  final ReorderSuggestion suggestion;
  final bool showCost;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = suggestion.product;

    return AppCard(
      selected: selected,
      accent: stockAccent(p.stockStatus),
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(8, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: selected ? 'Quitar de la selección' : 'Seleccionar',
            onPressed: onToggle,
            icon: AnimatedContainer(
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
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.code,
                        style: textTheme.labelLarge?.copyWith(color: AppColors.slate700),
                      ),
                    ),
                    StockBadge(p.stockStatus),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'Stock ${formatQuantity(p.stock)} · Mín. ${formatQuantity(p.minStock)}'
                        '${p.incomingQty > 0 ? ' · +${formatQuantity(p.incomingQty)} en camino' : ''}',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Pedir ${formatQuantity(suggestion.suggestedQty)}',
                          style: textTheme.titleMedium?.copyWith(color: AppColors.brand700),
                        ),
                        if (showCost && suggestion.estimatedCostPen != null)
                          Text(
                            formatPen(suggestion.estimatedCostPen),
                            style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                          ),
                      ],
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
