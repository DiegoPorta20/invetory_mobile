import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data_revision.dart';
import '../../core/data/reference_data.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/toast.dart';
import 'products_repository.dart';

enum BulkAction {
  category('Asignar categoría', Icons.layers_outlined),
  costCenter('Asignar centro de costo', Icons.sell_outlined),
  stockLevels('Definir stock mínimo y reposición', Icons.inventory_2_outlined),
  activation('Activar o desactivar', Icons.toggle_on_outlined);

  const BulkAction(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Resolves to true when the change was applied.
Future<bool> showBulkSheet(BuildContext context, List<int> ids) async {
  final result = await showAppSheet<bool>(
    context,
    builder: (_) => _BulkSheet(ids: ids),
  );
  return result ?? false;
}

class _BulkSheet extends ConsumerStatefulWidget {
  const _BulkSheet({required this.ids});

  final List<int> ids;

  @override
  ConsumerState<_BulkSheet> createState() => _BulkSheetState();
}

class _BulkSheetState extends ConsumerState<_BulkSheet> {
  BulkAction? _action;
  int? _categoryId;
  int? _costCenterId;
  bool _isActive = true;
  final _min = TextEditingController();
  final _reorder = TextEditingController();
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _min.dispose();
    _reorder.dispose();
    super.dispose();
  }

  Map<String, Object?>? _changes() {
    switch (_action) {
      case BulkAction.category:
        return {'categoryId': _categoryId};
      case BulkAction.costCenter:
        return {'costCenterId': _costCenterId};
      case BulkAction.stockLevels:
        final changes = <String, Object?>{};
        if (_min.text.isNotEmpty) changes['minStock'] = int.parse(_min.text);
        if (_reorder.text.isNotEmpty) changes['reorderQuantity'] = int.parse(_reorder.text);
        return changes.isEmpty ? null : changes;
      case BulkAction.activation:
        return {'isActive': _isActive};
      case null:
        return null;
    }
  }

  Future<void> _apply() async {
    final changes = _changes();
    if (changes == null) {
      setState(() => _error = 'Indica al menos un valor para aplicar.');
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await ref.read(productsRepositoryProvider).bulkUpdate(widget.ids, changes);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      Toast.success('${widget.ids.length} producto(s) actualizados.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pending = false;
        _error = errorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = '${widget.ids.length} producto(s) seleccionado(s)';

    return SheetFrame(
      title: _action?.label ?? 'Acciones en lote',
      subtitle: subtitle,
      footer: _action == null
          ? null
          : SheetActions(
              primaryLabel: 'Aplicar',
              secondaryLabel: 'Atrás',
              loading: _pending,
              onSecondary: () => setState(() {
                _action = null;
                _error = null;
              }),
              onPrimary: _apply,
            ),
      child: AnimatedSwitcher(
        duration: AppMotion.normal,
        switchInCurve: AppMotion.ease,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.04, 0), end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        ),
        child: _action == null
            ? _menu(context)
            : KeyedSubtree(key: ValueKey(_action), child: _form(context)),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final action in BulkAction.values)
          Pressable(
            onTap: () => setState(() => _action = action),
            scale: 0.985,
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.brand100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(action.icon, size: 20, color: AppColors.brand600),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      action.label,
                      style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    final categories = ref.watch(categoriesProvider).asData?.value ?? const [];
    final costCenters = ref.watch(costCentersProvider).asData?.value ?? const [];

    final Widget body = switch (_action!) {
      BulkAction.category => PickerField<int>(
          label: 'Categoría',
          value: _categoryId,
          nullLabel: 'Sin categoría',
          searchable: true,
          options: buildCategoryOptions(categories),
          onChanged: (value) => setState(() => _categoryId = value),
        ),
      BulkAction.costCenter => PickerField<int>(
          label: 'Centro de costo',
          value: _costCenterId,
          nullLabel: 'Sin centro de costo',
          options: [
            for (final c in costCenters) PickerOption(value: c.id, label: c.name),
          ],
          onChanged: (value) => setState(() => _costCenterId = value),
        ),
      BulkAction.stockLevels => Column(
          children: [
            AppTextField(
              label: 'Stock mínimo',
              controller: _min,
              keyboardType: numberKeyboard(),
              inputFormatters: numberFormatters(),
              hint: 'Dejar vacío para no cambiar',
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Cantidad de reposición',
              controller: _reorder,
              keyboardType: numberKeyboard(),
              inputFormatters: numberFormatters(),
              hint: 'Dejar vacío para no cambiar',
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      BulkAction.activation => SegmentedPills<bool>(
          options: const [(true, 'Activar'), (false, 'Desactivar')],
          value: _isActive,
          onChanged: (value) => setState(() => _isActive = value),
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        body,
        if (_error != null) ...[
          const SizedBox(height: 14),
          ErrorBanner(_error!),
        ],
      ],
    );
  }
}
