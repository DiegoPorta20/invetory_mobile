import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import 'products_repository.dart';

/// Search sheet that resolves to the chosen product (code or description search).
Future<Product?> showProductPicker(BuildContext context) {
  return showAppSheet<Product>(context, builder: (_) => const _ProductPickerSheet());
}

class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet();

  @override
  ConsumerState<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  List<Product> _results = const [];
  bool _loading = true;
  Object? _error;
  String _term = '';
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String term) async {
    final request = ++_request;
    setState(() {
      _term = term;
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(productsRepositoryProvider).search(term);
      if (!mounted || request != _request) return;
      setState(() {
        _results = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final height = MediaQuery.sizeOf(context).height;

    Widget body;
    if (_loading && _results.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    } else if (_error != null) {
      body = ErrorState(message: errorText(_error), onRetry: () => _search(_term));
    } else if (_results.isEmpty) {
      body = const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Sin resultados',
        description: 'Prueba con otro código o descripción.',
      );
    } else {
      body = ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final p = _results[index];
          return Pressable(
            onTap: () => Navigator.of(context).pop(p),
            scale: 0.985,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.code,
                          style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${formatQuantity(p.stock)} ${p.unit.label}',
                        style: textTheme.labelLarge,
                      ),
                      const SizedBox(height: 3),
                      StockBadge(p.stockStatus),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return SheetFrame(
      title: 'Seleccionar producto',
      padBody: false,
      child: SizedBox(
        height: height * 0.66,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
              child: SearchPill(
                hint: 'Código o descripción',
                autofocus: true,
                onChanged: _search,
              ),
            ),
            Expanded(child: SingleChildScrollView(child: body)),
          ],
        ),
      ),
    );
  }
}

/// Compact card showing the chosen product with a "change" action.
class SelectedProductCard extends StatelessWidget {
  const SelectedProductCard({
    super.key,
    required this.name,
    required this.code,
    required this.stock,
    required this.unit,
    this.onChange,
  });

  final String name;
  final String code;
  final int stock;
  final UnitOfMeasure unit;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lineStrong),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '$code · Stock actual: ${formatQuantity(stock)} ${unit.label}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                ),
              ],
            ),
          ),
          if (onChange != null)
            TextButton(onPressed: onChange, child: const Text('Cambiar')),
        ],
      ),
    );
  }
}
