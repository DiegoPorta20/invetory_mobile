import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/reference_data.dart';
import '../../shared/models/enums.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/sheets.dart';
import 'products_repository.dart';

/// Opens the filters sheet; resolves to the new filters or null when dismissed.
Future<ProductFilters?> showProductFiltersSheet(
  BuildContext context,
  ProductFilters current,
) {
  return showAppSheet<ProductFilters>(
    context,
    builder: (_) => _ProductFiltersSheet(initial: current),
  );
}

class _ProductFiltersSheet extends ConsumerStatefulWidget {
  const _ProductFiltersSheet({required this.initial});

  final ProductFilters initial;

  @override
  ConsumerState<_ProductFiltersSheet> createState() => _ProductFiltersSheetState();
}

class _ProductFiltersSheetState extends ConsumerState<_ProductFiltersSheet> {
  late ProductFilters _f = widget.initial;

  Widget _group(String label, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: LabeledField(label: label, child: child),
      );

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).asData?.value ?? const [];
    final costCenters = ref.watch(costCentersProvider).asData?.value ?? const [];
    final equipment = ref.watch(equipmentProvider).asData?.value ?? const [];
    final imports = ref.watch(importsLookupProvider).asData?.value ?? const [];

    return SheetFrame(
      title: 'Filtros y orden',
      footer: Row(
        children: [
          Expanded(
            child: SheetActions(
              primaryLabel: 'Aplicar',
              secondaryLabel: 'Limpiar',
              onSecondary: () => Navigator.of(context)
                  .pop(ProductFilters(search: _f.search)),
              onPrimary: () => Navigator.of(context).pop(_f),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _group(
            'Ordenar por',
            Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sort in ProductSort.values)
                      PillChip(
                        label: sort.label,
                        selected: _f.sortBy == sort,
                        onTap: () => setState(() => _f = _f.copyWith(sortBy: sort)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedPills<bool>(
                  options: const [(false, 'Ascendente'), (true, 'Descendente')],
                  value: _f.descending,
                  onChanged: (value) =>
                      setState(() => _f = _f.copyWith(descending: value)),
                ),
              ],
            ),
          ),
          _group(
            'Estado de stock',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PillChip(
                  label: 'Todos',
                  selected: _f.stockStatus == null,
                  onTap: () => setState(() => _f = _f.copyWith(stockStatus: null)),
                ),
                for (final status in StockFilter.values)
                  PillChip(
                    label: status.label,
                    selected: _f.stockStatus == status,
                    onTap: () =>
                        setState(() => _f = _f.copyWith(stockStatus: status)),
                  ),
              ],
            ),
          ),
          PickerField<int>(
            label: 'Categoría',
            value: _f.categoryId,
            nullLabel: 'Todas las categorías',
            searchable: true,
            options: buildCategoryOptions(categories),
            onChanged: (value) => setState(() => _f = _f.copyWith(categoryId: value)),
          ),
          const SizedBox(height: 16),
          PickerField<int>(
            label: 'Centro de costo',
            value: _f.costCenterId,
            nullLabel: 'Todos los centros',
            options: [
              for (final c in costCenters) PickerOption(value: c.id, label: c.name),
            ],
            onChanged: (value) => setState(() => _f = _f.copyWith(costCenterId: value)),
          ),
          const SizedBox(height: 16),
          PickerField<int>(
            label: 'Equipo compatible',
            value: _f.equipmentId,
            nullLabel: 'Todos los equipos',
            searchable: true,
            options: [
              for (final e in equipment)
                PickerOption(value: e.id, label: e.name, subtitle: e.brand),
            ],
            onChanged: (value) => setState(() => _f = _f.copyWith(equipmentId: value)),
          ),
          const SizedBox(height: 16),
          PickerField<int>(
            label: 'Importación',
            value: _f.importOrderId,
            nullLabel: 'Todas las importaciones',
            searchable: true,
            options: [
              for (final i in imports)
                PickerOption(
                  value: i.id,
                  label: '#${i.number}',
                  subtitle: i.supplierName,
                ),
            ],
            onChanged: (value) =>
                setState(() => _f = _f.copyWith(importOrderId: value)),
          ),
          const SizedBox(height: 18),
          _group(
            'Unidad',
            Wrap(
              spacing: 8,
              children: [
                PillChip(
                  label: 'Todas',
                  selected: _f.unit == null,
                  onTap: () => setState(() => _f = _f.copyWith(unit: null)),
                ),
                for (final unit in UnitOfMeasure.values)
                  PillChip(
                    label: unit.label,
                    selected: _f.unit == unit,
                    onTap: () => setState(() => _f = _f.copyWith(unit: unit)),
                  ),
              ],
            ),
          ),
          _group(
            'Estado del producto',
            SegmentedPills<ActiveFilter>(
              options: [for (final a in ActiveFilter.values) (a, a.label)],
              value: _f.active,
              onChanged: (value) => setState(() => _f = _f.copyWith(active: value)),
            ),
          ),
          _group(
            'Tipo de código',
            SegmentedPills<bool?>(
              options: const [
                (null, 'Todos'),
                (false, 'Proveedor'),
                (true, 'Interno'),
              ],
              value: _f.internalCode,
              onChanged: (value) =>
                  setState(() => _f = _f.copyWith(internalCode: value)),
            ),
          ),
          _group(
            'Precio',
            SegmentedPills<bool?>(
              options: const [
                (null, 'Todos'),
                (true, 'Con precio'),
                (false, 'Sin precio'),
              ],
              value: _f.hasPrice,
              onChanged: (value) => setState(() => _f = _f.copyWith(hasPrice: value)),
            ),
          ),
          SwitchTile(
            title: 'Solo consignación',
            value: _f.consignment,
            onChanged: (value) => setState(() => _f = _f.copyWith(consignment: value)),
          ),
        ],
      ),
    );
  }
}
