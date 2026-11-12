import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
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
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/toast.dart';
import '../products/product_picker.dart';

/// Opens the "register movement" sheet. Resolves to true when a movement was saved.
Future<bool> showRegisterMovementSheet(
  BuildContext context, {
  Product? product,
  MovementType? type,
}) async {
  final result = await showAppSheet<bool>(
    context,
    builder: (_) => _RegisterMovementSheet(product: product, type: type),
  );
  return result ?? false;
}

class _RegisterMovementSheet extends ConsumerStatefulWidget {
  const _RegisterMovementSheet({this.product, this.type});

  final Product? product;
  final MovementType? type;

  @override
  ConsumerState<_RegisterMovementSheet> createState() =>
      _RegisterMovementSheetState();
}

class _RegisterMovementSheetState extends ConsumerState<_RegisterMovementSheet> {
  final _quantity = TextEditingController();
  final _counterparty = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();

  late Product? _product = widget.product;
  late MovementType _type = widget.type ?? MovementType.outbound;
  late MovementReason _reason = _type.manualReasons.first;
  bool _priceTouched = false;
  bool _pending = false;
  bool _submitted = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _quantity.addListener(() => setState(() {}));
    _price.addListener(() => setState(() {}));
    _applyDefaultPrice();
  }

  @override
  void dispose() {
    _quantity.dispose();
    _counterparty.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _isSale => _type == MovementType.outbound && _reason == MovementReason.sale;

  bool get _canPrices => ref.read(clientConfigProvider)?.canSeePrices ?? false;

  void _applyDefaultPrice() {
    final price = _product?.pricePen;
    if (_isSale && _canPrices && price != null && !_priceTouched && _price.text.isEmpty) {
      _price.text = price.toString();
    }
  }

  int? get _quantityValue => int.tryParse(_quantity.text.trim());

  int? get _resultingStock {
    final product = _product;
    final quantity = _quantityValue;
    if (product == null || quantity == null || quantity == 0) return null;
    return switch (_type) {
      MovementType.inbound => product.stock + quantity,
      MovementType.outbound => product.stock - quantity,
      MovementType.adjustment => product.stock + quantity,
    };
  }

  String? get _quantityError {
    if (!_submitted && _quantity.text.isEmpty) return null;
    final quantity = _quantityValue;
    if (quantity == null || quantity == 0) {
      return 'Ingresa una cantidad entera distinta de cero.';
    }
    if (_type != MovementType.adjustment && quantity < 0) {
      return 'La cantidad debe ser positiva.';
    }
    return _fieldErrors['quantity'];
  }

  Future<void> _pickProduct() async {
    final picked = await showProductPicker(context);
    if (picked == null || !mounted) return;
    setState(() {
      _product = picked;
      _priceTouched = false;
      _price.clear();
      _applyDefaultPrice();
    });
  }

  void _changeType(MovementType type) {
    setState(() {
      _type = type;
      if (!type.manualReasons.contains(_reason)) _reason = type.manualReasons.first;
      if (type == MovementType.adjustment) _counterparty.clear();
      _applyDefaultPrice();
    });
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final product = _product;
    if (product == null || _quantityError != null || _pending) return;

    setState(() {
      _pending = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await ref.read(apiClientProvider).post('/api/stock-movements', body: {
        'productId': product.id,
        'type': _type.wire,
        'reason': _reason.wire,
        'quantity': _quantityValue,
        'counterparty':
            _counterparty.text.trim().isEmpty ? null : _counterparty.text.trim(),
        if (_canPrices)
          'unitPricePen': _isSale ? double.tryParse(_price.text.trim()) : null,
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      });
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      Toast.success('Movimiento registrado.');
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _pending = false;
        _fieldErrors = error.fieldErrors;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final resulting = _resultingStock;
    final insufficient = resulting != null && resulting < 0;
    final igv = ref.watch(igvRateProvider).asData?.value ?? defaultIgvRate;
    final price = double.tryParse(_price.text.trim());

    return SheetFrame(
      title: 'Registrar movimiento',
      subtitle: 'Entradas, salidas y ajustes de stock.',
      footer: SheetActions(
        primaryLabel: 'Registrar',
        loading: _pending,
        onPrimary: _submit,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_product != null)
            SelectedProductCard(
              name: _product!.name,
              code: _product!.code,
              stock: _product!.stock,
              unit: _product!.unit,
              onChange: widget.product == null ? _pickProduct : null,
            )
          else
            LabeledField(
              label: 'Producto',
              required: true,
              error: _submitted ? 'Selecciona un producto.' : null,
              child: AppButton(
                label: 'Buscar producto',
                icon: Icons.search_rounded,
                variant: ButtonVariant.secondary,
                expand: true,
                onPressed: _pickProduct,
              ),
            ),
          const SizedBox(height: 18),
          LabeledField(
            label: 'Tipo de movimiento',
            child: SegmentedPills<MovementType>(
              options: [for (final t in MovementType.values) (t, t.label)],
              value: _type,
              onChanged: _changeType,
              toneOf: (t) => switch (t) {
                MovementType.inbound => AppColors.emerald700,
                MovementType.outbound => AppColors.rose600,
                MovementType.adjustment => AppColors.sky700,
              },
            ),
          ),
          const SizedBox(height: 16),
          PickerField<MovementReason>(
            label: 'Motivo',
            required: true,
            value: _reason,
            options: [
              for (final r in _type.manualReasons)
                PickerOption(value: r, label: r.label),
            ],
            onChanged: (value) => setState(() {
              if (value != null) _reason = value;
              _applyDefaultPrice();
            }),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: _type == MovementType.adjustment
                ? 'Cantidad (+ suma, − resta)'
                : 'Cantidad',
            required: true,
            controller: _quantity,
            keyboardType:
                numberKeyboard(signed: _type == MovementType.adjustment),
            inputFormatters:
                numberFormatters(signed: _type == MovementType.adjustment),
            errorText: _quantityError,
            textInputAction: TextInputAction.next,
          ),
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.ease,
            alignment: Alignment.topCenter,
            child: resulting == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: insufficient ? AppColors.rose50 : AppColors.slate50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text.rich(
                        TextSpan(
                          text: 'Stock resultante: ',
                          children: [
                            TextSpan(
                              text: formatQuantity(resulting),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            if (insufficient) const TextSpan(text: ' · Stock insuficiente'),
                          ],
                        ),
                        style: textTheme.bodyMedium?.copyWith(
                          color: insufficient ? AppColors.rose700 : AppColors.slate600,
                        ),
                      ),
                    ),
                  ),
          ),
          if (_isSale) ...[
            const SizedBox(height: 16),
            AppTextField(
              label: 'Cliente',
              controller: _counterparty,
              maxLength: 160,
              textCapitalization: TextCapitalization.words,
            ),
            if (_canPrices) ...[
            const SizedBox(height: 16),
            AppTextField(
              label: 'Precio unitario (S/ sin IGV)',
              controller: _price,
              keyboardType: numberKeyboard(decimal: true),
              inputFormatters: numberFormatters(decimal: true),
              onChanged: (_) => _priceTouched = true,
              prefixText: 'S/ ',
              helper: price != null && price > 0
                  ? 'Equivale a ${formatPen(Pricing(igv).breakdown(price).priceWithIgvPen)} con IGV.'
                  : null,
            ),
            ],
          ] else if (_type != MovementType.adjustment) ...[
            const SizedBox(height: 16),
            AppTextField(
              label: _type == MovementType.inbound ? 'Origen' : 'Destino',
              controller: _counterparty,
              maxLength: 160,
              textCapitalization: TextCapitalization.words,
            ),
          ],
          const SizedBox(height: 16),
          AppTextField(
            label: 'Nota',
            controller: _note,
            maxLines: 3,
            minLines: 2,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            ErrorBanner(_error!),
          ],
        ],
      ),
    );
  }
}
