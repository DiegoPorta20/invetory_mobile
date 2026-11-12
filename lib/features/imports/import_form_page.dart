import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/client_config.dart';
import '../../core/data/data_revision.dart';
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
import '../products/product_picker.dart';
import 'imports_repository.dart';

class ImportFormPage extends ConsumerWidget {
  const ImportFormPage({super.key, this.id, this.prefill});

  final int? id;
  final ImportPrefill? prefill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = id == null ? 'Nueva importación' : 'Editar importación';
    final suppliers = ref.watch(suppliersProvider);
    final order = id == null ? null : ref.watch(importDetailProvider(id!));

    final error = suppliers.error ?? order?.error;
    if (error != null) {
      return ScreenScaffold(
        title: title,
        showBack: true,
        slivers: [
          SliverToBoxAdapter(
            child: ErrorState(
              message: errorText(error),
              onRetry: () {
                ref.invalidate(suppliersProvider);
                if (id != null) ref.invalidate(importDetailProvider(id!));
              },
            ),
          ),
        ],
      );
    }
    if (!suppliers.hasValue || (order != null && !order.hasValue)) {
      return ScreenScaffold(
        title: title,
        showBack: true,
        slivers: const [
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: kGutter),
            sliver: SliverToBoxAdapter(child: SkeletonList(count: 3, height: 130)),
          ),
        ],
      );
    }
    return _ImportForm(
      id: id,
      order: order?.value,
      prefill: prefill,
      suppliers: suppliers.value!.where((s) => s.isActive).toList(),
    );
  }
}

class _Line {
  _Line({
    required this.productId,
    required this.code,
    required this.name,
    required this.unit,
    int quantity = 1,
    double? cost,
  })  : quantity = TextEditingController(text: quantity.toString()),
        cost = TextEditingController(text: cost == null ? '' : _trim(cost));

  final int productId;
  final String code;
  final String name;
  final UnitOfMeasure unit;
  final TextEditingController quantity;
  final TextEditingController cost;

  static String _trim(double v) =>
      v.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  int get qty => int.tryParse(quantity.text.trim()) ?? 0;
  double? get unitCost => double.tryParse(cost.text.trim());

  void dispose() {
    quantity.dispose();
    cost.dispose();
  }
}

class _ImportForm extends ConsumerStatefulWidget {
  const _ImportForm({
    required this.id,
    required this.order,
    required this.prefill,
    required this.suppliers,
  });

  final int? id;
  final ImportOrderDetail? order;
  final ImportPrefill? prefill;
  final List<Supplier> suppliers;

  @override
  ConsumerState<_ImportForm> createState() => _ImportFormState();
}

class _ImportFormState extends ConsumerState<_ImportForm> {
  final _number = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  final List<_Line> _lines = [];
  int? _supplierId;
  String? _orderedAt;
  String? _expectedAt;
  String _status = 'DRAFT';
  bool _pending = false;
  bool _dirty = false;
  bool _submitted = false;
  String? _error;
  Map<String, String> _errors = const {};

  bool get showCost => ref.read(clientConfigProvider)?.canSeeCosts ?? false;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    if (order != null) {
      final s = order.summary;
      _number.text = s.number.toString();
      _reference.text = s.reference ?? '';
      _notes.text = s.notes ?? '';
      _supplierId = s.supplierId;
      _orderedAt = _dayOf(s.orderedAt);
      _expectedAt = _dayOf(s.expectedAt);
      for (final item in order.items) {
        _lines.add(_Line(
          productId: item.productId,
          code: item.productCode,
          name: item.productName,
          unit: item.unit,
          quantity: item.quantityOrdered,
          cost: item.unitCostPen,
        ));
      }
    } else if (widget.prefill != null) {
      for (final line in widget.prefill!.items) {
        _lines.add(_Line(
          productId: line.productId,
          code: line.code,
          name: line.name,
          unit: line.unit,
          quantity: line.quantityOrdered,
          cost: line.unitCostPen,
        ));
      }
      _dirty = true;
    }
    for (final line in _lines) {
      _watch(line);
    }
  }

  void _watch(_Line line) {
    line.quantity.addListener(() => setState(() => _dirty = true));
    line.cost.addListener(() => setState(() => _dirty = true));
  }

  String? _dayOf(String? value) =>
      value == null || value.length < 10 ? null : value.substring(0, 10);

  @override
  void dispose() {
    _number.dispose();
    _reference.dispose();
    _notes.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _total => _lines.fold<double>(
        0,
        (sum, line) => sum + (line.unitCost ?? 0) * line.qty,
      );

  String? get _linesError {
    if (_lines.isEmpty) return 'Agrega al menos un producto.';
    if (_lines.any((l) => l.qty < 1)) return 'Todas las cantidades deben ser 1 o más.';
    return null;
  }

  Future<void> _addProduct() async {
    final product = await showProductPicker(context);
    if (product == null || !mounted) return;
    final existing = _lines.where((l) => l.productId == product.id);
    if (existing.isNotEmpty) {
      Toast.info('Ese producto ya está en la lista.');
      return;
    }
    final line = _Line(
      productId: product.id,
      code: product.code,
      name: product.name,
      unit: product.unit,
      cost: product.costPen,
    );
    _watch(line);
    setState(() {
      _lines.add(line);
      _dirty = true;
    });
  }

  void _removeLine(int index) {
    final line = _lines[index];
    setState(() {
      _lines.removeAt(index);
      _dirty = true;
    });
    // Dispose after the frame so the removed row can finish building.
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    FocusScope.of(context).unfocus();
    if (_linesError != null || _pending) return;

    final number = int.tryParse(_number.text.trim());
    final input = ImportInput(
      supplierId: _supplierId,
      reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
      orderedAt: _orderedAt,
      expectedAt: _expectedAt,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      items: [
        for (final l in _lines)
          ImportItemInput(
            productId: l.productId,
            quantityOrdered: l.qty,
            unitCostPen: showCost ? l.unitCost : null,
          ),
      ],
      status: _isEdit ? null : _status,
    );

    setState(() {
      _pending = true;
      _error = null;
      _errors = const {};
    });
    final repo = ref.read(importsRepositoryProvider);
    try {
      final json = input.toJson();
      if (number != null) json['number'] = number;
      final saved = _isEdit
          ? await repo.updateRaw(widget.id!, json)
          : await repo.createRaw(json);
      ref.read(dataRevisionProvider.notifier).bump();
      Toast.success(_isEdit ? 'Importación actualizada.' : 'Importación creada.');
      if (!mounted) return;
      setState(() => _dirty = false);
      if (_isEdit) {
        context.pop();
      } else {
        context.pushReplacement('/imports/${saved.summary.id}');
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _pending = false;
        _errors = error.fieldErrors;
        _error = error.code == 'CONFLICT'
            ? 'Ya existe una importación con ese número.'
            : error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
      child: ScreenScaffold(
        title: _isEdit ? 'Editar importación' : 'Nueva importación',
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
                label: 'Guardar',
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
                Reveal(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle('Datos del pedido'),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Número',
                            controller: _number,
                            keyboardType: numberKeyboard(),
                            inputFormatters: numberFormatters(),
                            helper: _isEdit ? null : 'Déjalo vacío para asignar el siguiente.',
                            errorText: _errors['number'],
                            onChanged: (_) => setState(() => _dirty = true),
                          ),
                          const SizedBox(height: 16),
                          PickerField<int>(
                            label: 'Proveedor',
                            value: _supplierId,
                            nullLabel: '— Sin proveedor —',
                            searchable: true,
                            error: _errors['supplierId'],
                            options: [
                              for (final s in widget.suppliers)
                                PickerOption(value: s.id, label: s.name, subtitle: s.country),
                            ],
                            onChanged: (value) => setState(() {
                              _supplierId = value;
                              _dirty = true;
                            }),
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Referencia',
                            controller: _reference,
                            maxLength: 120,
                            errorText: _errors['reference'],
                            onChanged: (_) => setState(() => _dirty = true),
                          ),
                          const SizedBox(height: 16),
                          DateField(
                            label: 'Fecha de pedido',
                            value: _orderedAt,
                            error: _errors['orderedAt'],
                            onChanged: (value) => setState(() {
                              _orderedAt = value;
                              _dirty = true;
                            }),
                          ),
                          const SizedBox(height: 16),
                          DateField(
                            label: 'Fecha esperada',
                            value: _expectedAt,
                            error: _errors['expectedAt'],
                            onChanged: (value) => setState(() {
                              _expectedAt = value;
                              _dirty = true;
                            }),
                          ),
                          if (!_isEdit) ...[
                            const SizedBox(height: 16),
                            LabeledField(
                              label: 'Estado inicial',
                              child: SegmentedPills<String>(
                                options: const [('DRAFT', 'Borrador'), ('ORDERED', 'Pedido')],
                                value: _status,
                                onChanged: (value) => setState(() => _status = value),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Notas',
                            controller: _notes,
                            maxLines: 3,
                            minLines: 2,
                            maxLength: 4000,
                            textCapitalization: TextCapitalization.sentences,
                            errorText: _errors['notes'],
                            onChanged: (_) => setState(() => _dirty = true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Reveal(
                  index: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 2),
                    child: SectionTitle(
                      'Productos (${_lines.length})',
                      trailing: AppButton(
                        label: 'Agregar',
                        icon: Icons.add_rounded,
                        small: true,
                        variant: ButtonVariant.secondary,
                        onPressed: _addProduct,
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: AppMotion.normal,
                  curve: AppMotion.ease,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      for (var i = 0; i < _lines.length; i++)
                        Padding(
                          key: ObjectKey(_lines[i]),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _LineCard(
                            line: _lines[i],
                            showCost: showCost,
                            onRemove: () => _removeLine(i),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Center(
                        child: Text(
                          'Agrega los productos del pedido.',
                          style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
                        ),
                      ),
                    ),
                  ),
                if (_submitted && _linesError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ErrorBanner(_linesError!),
                  ),
                if (showCost)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
                    child: Row(
                      children: [
                        Text('Total estimado', style: textTheme.bodyMedium),
                        const Spacer(),
                        Text(formatPen(_total), style: textTheme.titleLarge),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 14),
                AnimatedSize(
                  duration: AppMotion.normal,
                  curve: AppMotion.ease,
                  alignment: Alignment.topCenter,
                  child: _error == null
                      ? const SizedBox(width: double.infinity)
                      : ErrorBanner(_error!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line, required this.showCost, required this.onRemove});

  final _Line line;
  final bool showCost;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.code,
                        style: textTheme.labelLarge?.copyWith(color: AppColors.slate700)),
                    Text(
                      line.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Quitar producto',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, color: AppColors.slate400),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Cantidad (${line.unit.label})',
                    controller: line.quantity,
                    keyboardType: numberKeyboard(),
                    inputFormatters: numberFormatters(),
                  ),
                ),
                if (showCost) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    label: 'Costo unit. (S/)',
                    controller: line.cost,
                    keyboardType: numberKeyboard(decimal: true),
                    inputFormatters: numberFormatters(decimal: true),
                  ),
                ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
