import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data_revision.dart';
import '../../core/format/formatters.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/toast.dart';
import 'imports_repository.dart';

/// Resolves to true when the shipment was received.
Future<bool> showReceiveImportSheet(BuildContext context, ImportOrderDetail order) async {
  final result = await showAppSheet<bool>(
    context,
    builder: (_) => _ReceiveSheet(order: order),
  );
  return result ?? false;
}

class _ReceiveSheet extends ConsumerStatefulWidget {
  const _ReceiveSheet({required this.order});

  final ImportOrderDetail order;

  @override
  ConsumerState<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends ConsumerState<_ReceiveSheet> {
  late final List<TextEditingController> _controllers = [
    for (final item in widget.order.items)
      TextEditingController(text: item.quantityOrdered.toString()),
  ];
  String _receivedAt = toIsoDay(DateTime.now());
  bool _pending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  int get _total => _controllers.fold<int>(0, (sum, c) => sum + (int.tryParse(c.text) ?? 0));

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final items = widget.order.items;
      await ref.read(importsRepositoryProvider).receive(
        widget.order.summary.id,
        receivedAt: _receivedAt,
        lines: [
          for (var i = 0; i < items.length; i++)
            (itemId: items[i].id, quantityReceived: int.tryParse(_controllers[i].text) ?? 0),
        ],
      );
      ref.read(dataRevisionProvider.notifier).bump();
      Toast.success('Importación recibida. El stock fue actualizado.');
      if (mounted) Navigator.of(context).pop(true);
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
    final textTheme = Theme.of(context).textTheme;
    final items = widget.order.items;

    return SheetFrame(
      title: 'Recibir importación #${widget.order.summary.number}',
      subtitle: 'Confirma las cantidades recibidas por línea.',
      footer: SheetActions(
        primaryLabel: 'Confirmar recepción',
        loading: _pending,
        onPrimary: _submit,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateField(
            label: 'Fecha de recepción',
            value: _receivedAt,
            onChanged: (value) => setState(() => _receivedAt = value ?? toIsoDay(DateTime.now())),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall,
                        ),
                        Text(
                          '${items[i].productCode} · Pedido ${formatQuantity(items[i].quantityOrdered)}',
                          style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: _controllers[i],
                      textAlign: TextAlign.center,
                      keyboardType: numberKeyboard(),
                      inputFormatters: numberFormatters(),
                      style: textTheme.titleMedium,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 24),
          Row(
            children: [
              Text('Total a recibir', style: textTheme.bodyMedium),
              const Spacer(),
              Text(formatQuantity(_total), style: textTheme.titleLarge),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(_error!),
          ],
        ],
      ),
    );
  }
}
