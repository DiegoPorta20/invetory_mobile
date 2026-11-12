import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/data_revision.dart';
import '../../core/data/reference_data.dart';
import '../../core/export/excel_export.dart';
import '../../core/format/formatters.dart';
import '../../core/router/tab_bar_visibility.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/paged_list.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import '../movements/register_movement_sheet.dart';
import 'bulk_action_sheet.dart';
import 'product_filters_sheet.dart';
import 'product_tile.dart';
import 'products_repository.dart';
import '../../core/config/client_config.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key, this.query = const {}, this.queryKey = ''});

  /// Filters carried by a deep link such as `/products?stockStatus=OUT`.
  final Map<String, String> query;
  final String queryKey;

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  late ProductFilters _filters = widget.query.isEmpty
      ? const ProductFilters()
      : ProductFilters.fromQuery(widget.query);
  late final PagedController<Product> _controller = PagedController(
    fetch: (page) => ref.read(productsRepositoryProvider).list(_filters, page),
  );
  final Set<int> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.reset();
  }

  @override
  void didUpdateWidget(ProductsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.queryKey != oldWidget.queryKey && widget.query.isNotEmpty) {
      _setFilters(ProductFilters.fromQuery(widget.query));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setFilters(ProductFilters next) {
    setState(() => _filters = next);
    _clearSelection();
    _controller.reset();
  }

  void _setSelection(Set<int> ids) {
    setState(() {
      _selected
        ..clear()
        ..addAll(ids);
    });
    ref.read(tabBarHiddenProvider.notifier).set(_selecting);
  }

  void _clearSelection() => _setSelection(const {});

  void _toggle(Product product) {
    final next = {..._selected};
    if (!next.remove(product.id)) next.add(product.id);
    _setSelection(next);
  }

  Future<void> _openFilters() async {
    final result = await showProductFiltersSheet(context, _filters);
    if (result != null) _setFilters(result);
  }

  Future<void> _bulk() async {
    final applied = await showBulkSheet(context, _selected.toList());
    if (applied) _clearSelection();
  }

  bool _canImport(ClientConfig? c) =>
      c != null && c.can('products.import') && c.canSeeCosts && c.canSeePrices;

  bool _canExportPrices(ClientConfig? c) => c != null && c.can('products.export') && c.canSeePrices;

  bool _hasExcel(ClientConfig? c) => (c?.can('products.export') ?? false) || _canImport(c);

  Future<void> _openExcelMenu() async {
    final repo = ref.read(productsRepositoryProvider);
    final filtered = _filters.activeCount > 0;
    final config = ref.read(clientConfigProvider);
    final choice = await showAppSheet<String>(
      context,
      builder: (sheetContext) => SheetFrame(
        title: 'Excel',
        subtitle: 'Importa o exporta productos.',
        child: Column(
          children: [
            if (_canImport(config))
              _ExcelOption(
                icon: Icons.upload_file_rounded,
                title: 'Importar desde Excel',
                subtitle: 'Crea o actualiza productos con la plantilla',
                onTap: () => Navigator.of(sheetContext).pop('import'),
              ),
            if (config?.can('products.export') ?? false)
              _ExcelOption(
                icon: Icons.download_rounded,
                title: 'Exportar inventario',
                subtitle: filtered
                    ? 'Con los filtros aplicados (${_filters.activeCount})'
                    : 'Todos los productos activos',
                onTap: () => Navigator.of(sheetContext).pop('inventory'),
              ),
            if (_canExportPrices(config))
              _ExcelOption(
                icon: Icons.sell_outlined,
                title: 'Exportar lista de precios',
                subtitle: 'Productos activos con precio',
                onTap: () => Navigator.of(sheetContext).pop('prices'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'import':
        context.push('/products/import');
      case 'inventory':
        await shareExcel(
          () => repo.exportInventory(_filters),
          filename: datedExcelName('inventario'),
          subject: 'Inventario',
        );
      case 'prices':
        await shareExcel(
          () => repo.exportPriceList(_filters),
          filename: datedExcelName('lista-de-precios'),
          subject: 'Lista de precios',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dataRevisionProvider, (_, _) => _controller.refresh());
    final categories = ref.watch(categoriesProvider).asData?.value ?? const [];
    final costCenters = ref.watch(costCentersProvider).asData?.value ?? const [];
    final equipment = ref.watch(equipmentProvider).asData?.value ?? const [];
    final imports = ref.watch(importsLookupProvider).asData?.value ?? const [];
    final chips = _chips(categories, costCenters, equipment, imports);
    final textTheme = Theme.of(context).textTheme;
    final config = ref.watch(clientConfigProvider);
    final canCreate = config?.can('products.create') ?? false;
    final canUpdate = config?.can('products.update') ?? false;
    final canMove = config?.can('movements.create') ?? false;

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: ScreenScaffold(
        title: 'Productos',
        subtitle: 'Inventario, stock y clasificación.',
        hasTabBar: true,
        onRefresh: _controller.refresh,
        actions: [
          if (_hasExcel(config))
            AppIconButton(
              icon: Icons.table_chart_outlined,
              tooltip: 'Excel: importar y exportar',
              onPressed: _openExcelMenu,
            ),
          if (canMove)
            AppIconButton(
              icon: Icons.swap_horiz_rounded,
              tooltip: 'Registrar movimiento',
              onPressed: () => showRegisterMovementSheet(context),
            ),
        ],
        fab: _selecting || !canCreate
            ? null
            : AppFab(
                label: 'Nuevo producto',
                icon: Icons.add_rounded,
                onPressed: () => context.push('/products/new'),
              ),
        bottomBar: _selecting
            ? Row(
                children: [
                  AppIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Cancelar selección',
                    onPressed: _clearSelection,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('${_selected.length} seleccionado(s)', style: textTheme.titleSmall),
                  ),
                  AppIconButton(
                    icon: Icons.select_all_rounded,
                    tooltip: 'Seleccionar los cargados',
                    onPressed: () => _setSelection({for (final p in _controller.items) p.id}),
                  ),
                  const SizedBox(width: 10),
                  AppButton(label: 'Acciones', icon: Icons.bolt_rounded, onPressed: _bulk),
                ],
              )
            : null,
        slivers: [
          PinnedBar(
            height: 66,
            child: Row(
              children: [
                Expanded(
                  child: SearchPill(
                    hint: 'Código o descripción',
                    initialValue: _filters.search,
                    onChanged: (value) => _setFilters(_filters.copyWith(search: value)),
                  ),
                ),
                const SizedBox(width: 10),
                AppIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Filtros y orden',
                  badge: _filters.activeCount - (_filters.search.isNotEmpty ? 1 : 0) > 0,
                  onPressed: _openFilters,
                ),
              ],
            ),
          ),
          if (chips.isNotEmpty)
            boxSliver(
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  children: [
                    for (final chip in chips)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                        child: PillChip(
                          label: chip.$1,
                          selected: true,
                          onDeleted: () => _setFilters(chip.$2(_filters)),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: PillChip(
                        label: 'Limpiar',
                        onTap: () => _setFilters(const ProductFilters()),
                      ),
                    ),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 0),
            ),
          boxSliver(
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => AnimatedSwitcher(
                duration: AppMotion.fast,
                child: Padding(
                  key: ValueKey(_controller.total),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _controller.initialLoadDone
                        ? '${formatQuantity(_controller.total)} ${_controller.total == 1 ? 'producto' : 'productos'}'
                        : ' ',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                  ),
                ),
              ),
            ),
          ),
          PagedSliver<Product>(
            controller: _controller,
            keyOf: (p) => p.id,
            skeletonHeight: 150,
            empty: EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Sin productos',
              description: _filters.activeCount > 0
                  ? 'Ningún producto coincide con los filtros aplicados.'
                  : 'Aún no hay productos registrados.',
              action: _filters.activeCount > 0
                  ? AppButton(
                      label: 'Limpiar filtros',
                      variant: ButtonVariant.secondary,
                      onPressed: () => _setFilters(const ProductFilters()),
                    )
                  : canCreate
                  ? AppButton(
                      label: 'Nuevo producto',
                      icon: Icons.add_rounded,
                      onPressed: () => context.push('/products/new'),
                    )
                  : null,
            ),
            itemBuilder: (context, product, index) => ProductTile(
              product: product,
              selecting: _selecting,
              selected: _selected.contains(product.id),
              onTap: () => _selecting ? _toggle(product) : context.push('/products/${product.id}'),
              onLongPress: canUpdate ? () => _toggle(product) : null,
            ),
          ),
        ],
      ),
    );
  }

  List<(String, ProductFilters Function(ProductFilters))> _chips(
    List<Category> categories,
    List<CostCenter> costCenters,
    List<EquipmentModel> equipment,
    List<ImportOrderSummary> imports,
  ) {
    final f = _filters;
    String nameOf<T>(
      Iterable<T> items,
      bool Function(T) test,
      String Function(T) name,
      String fallback,
    ) {
      for (final item in items) {
        if (test(item)) return name(item);
      }
      return fallback;
    }

    return [
      if (f.categoryId != null)
        (
          nameOf(categories, (c) => c.id == f.categoryId, (c) => c.name, 'Categoría'),
          (x) => x.copyWith(categoryId: null),
        ),
      if (f.costCenterId != null)
        (
          nameOf(costCenters, (c) => c.id == f.costCenterId, (c) => c.name, 'Centro de costo'),
          (x) => x.copyWith(costCenterId: null),
        ),
      if (f.equipmentId != null)
        (
          nameOf(equipment, (e) => e.id == f.equipmentId, (e) => e.name, 'Equipo'),
          (x) => x.copyWith(equipmentId: null),
        ),
      if (f.importOrderId != null)
        (
          nameOf(
            imports,
            (i) => i.id == f.importOrderId,
            (i) => 'Importación #${i.number}',
            'Importación',
          ),
          (x) => x.copyWith(importOrderId: null),
        ),
      if (f.stockStatus != null) (f.stockStatus!.label, (x) => x.copyWith(stockStatus: null)),
      if (f.unit != null) (f.unit!.label, (x) => x.copyWith(unit: null)),
      if (f.active != ActiveFilter.active)
        (f.active.label, (x) => x.copyWith(active: ActiveFilter.active)),
      if (f.internalCode != null)
        (
          f.internalCode! ? 'Código interno' : 'Código de proveedor',
          (x) => x.copyWith(internalCode: null),
        ),
      if (f.hasPrice != null)
        (f.hasPrice! ? 'Con precio' : 'Sin precio', (x) => x.copyWith(hasPrice: null)),
      if (f.consignment) ('Consignación', (x) => x.copyWith(consignment: false)),
    ];
  }
}

class _ExcelOption extends StatelessWidget {
  const _ExcelOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brand100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: AppColors.brand600),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleSmall),
                  Text(subtitle, style: textTheme.bodySmall?.copyWith(color: AppColors.slate500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
}
