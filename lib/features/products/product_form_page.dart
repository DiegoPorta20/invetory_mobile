import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/data_revision.dart';
import '../../core/config/client_config.dart';
import '../../core/data/reference_data.dart';
import '../../core/format/formatters.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/toast.dart';
import 'products_repository.dart';

class ProductFormPage extends ConsumerWidget {
  const ProductFormPage({super.key, this.id});

  /// Null when creating.
  final int? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = id == null ? 'Nuevo producto' : 'Editar producto';
    final categories = ref.watch(categoriesProvider);
    final costCenters = ref.watch(costCentersProvider);
    final equipment = ref.watch(equipmentProvider);
    final igv = ref.watch(igvRateProvider);
    final product = id == null ? null : ref.watch(productDetailProvider(id!));

    final error = categories.error ?? costCenters.error ?? equipment.error ?? product?.error;
    if (error != null) {
      return ScreenScaffold(
        title: title,
        showBack: true,
        slivers: [
          SliverToBoxAdapter(
            child: ErrorState(
              message: errorText(error),
              onRetry: () {
                ref.invalidate(categoriesProvider);
                ref.invalidate(costCentersProvider);
                ref.invalidate(equipmentProvider);
                if (id != null) ref.invalidate(productDetailProvider(id!));
              },
            ),
          ),
        ],
      );
    }

    final ready =
        categories.hasValue &&
        costCenters.hasValue &&
        equipment.hasValue &&
        igv.hasValue &&
        (product == null || product.hasValue);
    if (!ready) {
      return ScreenScaffold(
        title: title,
        showBack: true,
        slivers: const [
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: kGutter),
            sliver: SliverToBoxAdapter(child: SkeletonList(count: 4, height: 150)),
          ),
        ],
      );
    }

    return _ProductForm(
      id: id,
      product: product?.value,
      categories: categories.value!,
      costCenters: costCenters.value!,
      equipment: equipment.value!,
      igvRate: igv.value!,
    );
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({
    required this.id,
    required this.product,
    required this.categories,
    required this.costCenters,
    required this.equipment,
    required this.igvRate,
  });

  final int? id;
  final Product? product;
  final List<Category> categories;
  final List<CostCenter> costCenters;
  final List<EquipmentModel> equipment;
  final double igvRate;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final Pricing _pricing = Pricing(widget.igvRate);

  final _code = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _specification = TextEditingController();
  final _location = TextEditingController();
  final _minStock = TextEditingController(text: '0');
  final _reorder = TextEditingController(text: '0');
  final _cost = TextEditingController();
  final _price = TextEditingController();
  final _priceGross = TextEditingController();
  final _wholesaleGross = TextEditingController();
  final _wholesaleMinQty = TextEditingController();
  final _notes = TextEditingController();

  UnitOfMeasure _unit = UnitOfMeasure.pcs;
  int? _categoryId;
  int? _costCenterId;
  bool _isActive = true;
  bool _isConsignment = false;
  final Set<int> _equipmentIds = {};

  double? _wholesaleBase;
  bool _syncing = false;
  bool _dirty = false;
  bool _pending = false;
  bool _submitted = false;
  String? _serverError;
  Map<String, String> _errors = const {};

  bool get _isEdit => widget.id != null;

  bool get _canCosts => ref.read(clientConfigProvider)?.canSeeCosts ?? false;
  bool get _canPrices => ref.read(clientConfigProvider)?.canSeePrices ?? false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _code.text = p.code;
      _name.text = p.name;
      _description.text = p.description ?? '';
      _specification.text = p.specification ?? '';
      _location.text = p.location ?? '';
      _minStock.text = p.minStock.toString();
      _reorder.text = p.reorderQuantity.toString();
      _cost.text = _moneyText(p.costPen);
      _price.text = _moneyText(p.pricePen);
      if (p.pricePen != null) {
        _priceGross.text = _moneyText(_pricing.breakdown(p.pricePen!).priceWithIgvPen);
      }
      _wholesaleBase = p.wholesalePricePen;
      if (p.wholesalePricePen != null) {
        _wholesaleGross.text = _moneyText(_pricing.breakdown(p.wholesalePricePen!).priceWithIgvPen);
      }
      _wholesaleMinQty.text = p.wholesaleMinQty?.toString() ?? '';
      _notes.text = p.notes ?? '';
      _unit = p.unit;
      _categoryId = p.categoryId;
      _costCenterId = p.costCenterId;
      _isActive = p.isActive;
      _isConsignment = p.isConsignment;
      _equipmentIds.addAll(p.equipment.map((e) => e.id));
    }
    for (final controller in [_cost, _price, _priceGross, _wholesaleGross]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _code,
      _name,
      _description,
      _specification,
      _location,
      _minStock,
      _reorder,
      _cost,
      _price,
      _priceGross,
      _wholesaleGross,
      _wholesaleMinQty,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _moneyText(double? value) {
    if (value == null) return '';
    final text = value.toStringAsFixed(4);
    return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  double? _parseMoney(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    return value != null && value >= 0 ? value : null;
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _onPriceChanged(String raw) {
    _markDirty();
    if (_syncing) return;
    _syncing = true;
    final base = _parseMoney(raw);
    _priceGross.text = base == null ? '' : _moneyText(_pricing.breakdown(base).priceWithIgvPen);
    _syncing = false;
  }

  void _onPriceGrossChanged(String raw) {
    _markDirty();
    if (_syncing) return;
    _syncing = true;
    final gross = _parseMoney(raw);
    _price.text = gross == null ? '' : _moneyText(_pricing.priceFromWithIgv(gross));
    _syncing = false;
  }

  void _onWholesaleGrossChanged(String raw) {
    _markDirty();
    final gross = _parseMoney(raw);
    setState(() => _wholesaleBase = gross == null ? null : _pricing.priceFromWithIgv(gross));
  }

  double? get _margin {
    final price = _parseMoney(_price.text);
    final cost = _parseMoney(_cost.text);
    if (price == null || cost == null || price <= 0) return null;
    return ((price - cost) / price) * 100;
  }

  String? get _wholesaleQtyError {
    if (_wholesaleBase != null && _wholesaleMinQty.text.trim().isEmpty) {
      return 'Indica la cantidad mínima para el precio por mayor.';
    }
    return _errors['wholesaleMinQty'];
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _pending) return;
    if (_wholesaleQtyError != null) return;

    final code = _code.text.trim();
    final input = ProductInput(
      code: code.isEmpty ? null : code,
      name: _name.text.trim(),
      description: _blankToNull(_description.text),
      specification: _blankToNull(_specification.text),
      categoryId: _categoryId,
      costCenterId: _costCenterId,
      unit: _unit,
      minStock: int.tryParse(_minStock.text.trim()) ?? 0,
      reorderQuantity: int.tryParse(_reorder.text.trim()) ?? 0,
      location: _blankToNull(_location.text),
      costPen: _parseMoney(_cost.text),
      pricePen: _parseMoney(_price.text),
      wholesalePricePen: _wholesaleBase,
      wholesaleMinQty: _wholesaleBase == null ? null : int.tryParse(_wholesaleMinQty.text.trim()),
      isConsignment: _isConsignment,
      notes: _blankToNull(_notes.text),
      isActive: _isActive,
      equipmentIds: _equipmentIds.toList(),
    );

    setState(() {
      _pending = true;
      _serverError = null;
      _errors = const {};
    });
    final repo = ref.read(productsRepositoryProvider);
    try {
      final withCosts = _canCosts;
      final withPrices = _canPrices;
      final saved = _isEdit
          ? await repo.update(
              widget.id!,
              input.toJson(withCosts: withCosts, withPrices: withPrices),
            )
          : await repo.create(input, withCosts: withCosts, withPrices: withPrices);
      ref.read(dataRevisionProvider.notifier).bump();
      Toast.success(_isEdit ? 'Producto actualizado.' : 'Producto creado.');
      if (!mounted) return;
      setState(() => _dirty = false);
      if (_isEdit) {
        context.pop();
      } else {
        context.pushReplacement('/products/${saved.id}');
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _pending = false;
        _errors = {
          ...error.fieldErrors,
          if (error.code == 'CONFLICT') 'code': 'Ya existe un producto con este código.',
        };
        _serverError = error.message;
      });
    }
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final retail = _parseMoney(_price.text) == null
        ? null
        : _pricing.breakdown(_parseMoney(_price.text)!);
    final margin = _margin;
    final igvPercent = (widget.igvRate * 100).round();

    Widget card(int index, String title, List<Widget> children) => Reveal(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [SectionTitle(title), const SizedBox(height: 16), ...children],
          ),
        ),
      ),
    );

    const gap = SizedBox(height: 16);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirmAction(
          context,
          title: 'Descartar cambios',
          message: 'Tienes cambios sin guardar. ¿Quieres salir sin guardarlos?',
          confirmLabel: 'Descartar',
          danger: true,
        );
        if (discard && mounted) {
          setState(() => _dirty = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.pop();
          });
        }
      },
      child: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        onChanged: _markDirty,
        child: ScreenScaffold(
          title: _isEdit ? 'Editar producto' : 'Nuevo producto',
          showBack: true,
          bottomBar: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancelar',
                  variant: ButtonVariant.secondary,
                  onPressed: _pending ? null : () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: _pending ? 'Guardando…' : 'Guardar',
                  loading: _pending,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
          slivers: [
            gutterSliver(
              SliverList.list(
                children: [
                  card(0, 'Información general', [
                    AppTextField(
                      label: 'Código',
                      controller: _code,
                      maxLength: 60,
                      textCapitalization: TextCapitalization.characters,
                      errorText: _errors['code'],
                      helper: _isEdit
                          ? null
                          : 'Déjalo vacío para generar un código interno (INT-####).',
                    ),
                    gap,
                    PickerField<UnitOfMeasure>(
                      label: 'Unidad',
                      required: true,
                      value: _unit,
                      options: [
                        for (final u in UnitOfMeasure.values)
                          PickerOption(value: u, label: u.label),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _unit = value);
                        _markDirty();
                      },
                    ),
                    gap,
                    AppTextField(
                      label: 'Nombre / descripción corta',
                      required: true,
                      controller: _name,
                      maxLength: 255,
                      textCapitalization: TextCapitalization.sentences,
                      errorText: _errors['name'],
                      validator: (value) =>
                          value.trim().isEmpty ? 'Ingresa el nombre del producto.' : null,
                    ),
                    gap,
                    AppTextField(
                      label: 'Descripción detallada',
                      controller: _description,
                      maxLines: 4,
                      minLines: 2,
                      maxLength: 4000,
                      textCapitalization: TextCapitalization.sentences,
                      errorText: _errors['description'],
                    ),
                    gap,
                    PickerField<int>(
                      label: 'Categoría',
                      value: _categoryId,
                      nullLabel: '— Sin categoría —',
                      searchable: true,
                      options: buildCategoryOptions(widget.categories),
                      error: _errors['categoryId'],
                      onChanged: (value) {
                        setState(() => _categoryId = value);
                        _markDirty();
                      },
                    ),
                    gap,
                    PickerField<int>(
                      label: 'Centro de costo',
                      value: _costCenterId,
                      nullLabel: '— Sin centro de costo —',
                      options: [
                        for (final c in widget.costCenters)
                          PickerOption(value: c.id, label: c.name),
                      ],
                      error: _errors['costCenterId'],
                      onChanged: (value) {
                        setState(() => _costCenterId = value);
                        _markDirty();
                      },
                    ),
                    gap,
                    AppTextField(
                      label: 'Ubicación',
                      controller: _location,
                      maxLength: 60,
                      errorText: _errors['location'],
                    ),
                    gap,
                    AppTextField(
                      label: 'Especificación',
                      controller: _specification,
                      maxLength: 500,
                      errorText: _errors['specification'],
                    ),
                  ]),
                  card(1, _canCosts || _canPrices ? 'Stock y precios' : 'Stock', [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Stock mínimo',
                            controller: _minStock,
                            keyboardType: numberKeyboard(),
                            inputFormatters: numberFormatters(),
                            errorText: _errors['minStock'],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Reposición',
                            controller: _reorder,
                            keyboardType: numberKeyboard(),
                            inputFormatters: numberFormatters(),
                            errorText: _errors['reorderQuantity'],
                          ),
                        ),
                      ],
                    ),
                    if (_canCosts) ...[
                      gap,
                      AppTextField(
                        label: 'Costo (S/)',
                        controller: _cost,
                        prefixText: 'S/ ',
                        keyboardType: numberKeyboard(decimal: true),
                        inputFormatters: numberFormatters(decimal: true),
                        errorText: _errors['costPen'],
                      ),
                    ],
                    if (_canPrices) ...[
                      gap,
                      AppTextField(
                        label: 'Precio de venta (S/ sin IGV)',
                        controller: _price,
                        prefixText: 'S/ ',
                        keyboardType: numberKeyboard(decimal: true),
                        inputFormatters: numberFormatters(decimal: true),
                        onChanged: _onPriceChanged,
                        errorText: _errors['pricePen'],
                      ),
                      gap,
                      AppTextField(
                        label: 'Precio de venta (S/ con IGV)',
                        controller: _priceGross,
                        prefixText: 'S/ ',
                        keyboardType: numberKeyboard(decimal: true),
                        inputFormatters: numberFormatters(decimal: true),
                        onChanged: _onPriceGrossChanged,
                        helper: 'Incluye IGV $igvPercent%',
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.slate50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          children: [
                            _Summary('Precio sin IGV', formatPen(retail?.pricePen)),
                            _Summary('IGV', formatPen(retail?.igvPen)),
                            _Summary('Precio con IGV', formatPen(retail?.priceWithIgvPen)),
                            if (_canCosts)
                              _Summary(
                                'Margen estimado',
                                margin == null ? '—' : formatPercent(margin),
                                color: margin == null
                                    ? AppColors.slate400
                                    : margin >= 0
                                    ? AppColors.emerald700
                                    : AppColors.rose600,
                              ),
                          ],
                        ),
                      ),
                      gap,
                      AppTextField(
                        label: 'Precio por mayor (S/ con IGV)',
                        controller: _wholesaleGross,
                        prefixText: 'S/ ',
                        keyboardType: numberKeyboard(decimal: true),
                        inputFormatters: numberFormatters(decimal: true),
                        onChanged: _onWholesaleGrossChanged,
                        errorText: _errors['wholesalePricePen'],
                        helper: _wholesaleBase == null
                            ? 'Incluye IGV.'
                            : 'Sin IGV: ${formatPen(_wholesaleBase)}',
                      ),
                      gap,
                      AppTextField(
                        label: 'Cantidad mínima por mayor',
                        controller: _wholesaleMinQty,
                        keyboardType: numberKeyboard(),
                        inputFormatters: numberFormatters(),
                        errorText: _submitted ? _wholesaleQtyError : _errors['wholesaleMinQty'],
                      ),
                    ],
                  ]),
                  card(2, 'Equipos compatibles', [
                    if (widget.equipment.isEmpty)
                      Text(
                        'No hay equipos registrados.',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final model in widget.equipment)
                            PillChip(
                              label: model.name,
                              selected: _equipmentIds.contains(model.id),
                              onTap: () {
                                setState(() {
                                  if (!_equipmentIds.remove(model.id)) {
                                    _equipmentIds.add(model.id);
                                  }
                                });
                                _markDirty();
                              },
                            ),
                        ],
                      ),
                  ]),
                  card(3, 'Otros', [
                    AppTextField(
                      label: 'Notas',
                      controller: _notes,
                      maxLines: 4,
                      minLines: 3,
                      maxLength: 4000,
                      textCapitalization: TextCapitalization.sentences,
                      errorText: _errors['notes'],
                    ),
                    gap,
                    SwitchTile(
                      title: 'Producto activo',
                      value: _isActive,
                      onChanged: (value) {
                        setState(() => _isActive = value);
                        _markDirty();
                      },
                    ),
                    const SizedBox(height: 10),
                    SwitchTile(
                      title: 'En consignación',
                      value: _isConsignment,
                      onChanged: (value) {
                        setState(() => _isConsignment = value);
                        _markDirty();
                      },
                    ),
                  ]),
                  AnimatedSize(
                    duration: AppMotion.normal,
                    curve: AppMotion.ease,
                    alignment: Alignment.topCenter,
                    child: _serverError == null
                        ? const SizedBox(width: double.infinity)
                        : ErrorBanner(_serverError!),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: textTheme.bodySmall?.copyWith(color: AppColors.slate500)),
        const SizedBox(height: 2),
        Text(value, style: textTheme.titleSmall?.copyWith(color: color)),
      ],
    );
  }
}
