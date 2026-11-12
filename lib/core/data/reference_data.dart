import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/models.dart';
import '../../shared/widgets/fields.dart';
import '../auth/auth_controller.dart';
import '../network/api_exception.dart';

/// Lookup lists reused by filters and forms. Invalidate them after editing.

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final json = await ref.watch(apiClientProvider).get('/api/categories');
  return (json as List).whereType<Map<String, dynamic>>().map(Category.fromJson).toList();
});

final costCentersProvider = FutureProvider<List<CostCenter>>((ref) async {
  final json = await ref.watch(apiClientProvider).get('/api/cost-centers');
  return (json as List).whereType<Map<String, dynamic>>().map(CostCenter.fromJson).toList();
});

final equipmentProvider = FutureProvider<List<EquipmentModel>>((ref) async {
  final json = await ref.watch(apiClientProvider).get('/api/equipment-models');
  return (json as List)
      .whereType<Map<String, dynamic>>()
      .map(EquipmentModel.fromJson)
      .toList();
});

final suppliersProvider = FutureProvider<List<Supplier>>((ref) async {
  final json = await ref.watch(apiClientProvider).get('/api/suppliers');
  return (json as List).whereType<Map<String, dynamic>>().map(Supplier.fromJson).toList();
});

/// IGV rate (0.18 by default). Falls back to the default if settings cannot be read.
final igvRateProvider = FutureProvider<double>((ref) async {
  try {
    final json = await ref.watch(apiClientProvider).get('/api/settings/pricing');
    final rate = (json as Map<String, dynamic>)['igvRate'];
    return rate is num ? rate.toDouble() : double.tryParse('$rate') ?? defaultIgvRate;
  } on ApiException {
    return defaultIgvRate;
  }
});

const defaultIgvRate = 0.18;

double _round(double value, int decimals) {
  var factor = 1.0;
  for (var i = 0; i < decimals; i++) {
    factor *= 10;
  }
  return (value * factor).round() / factor;
}

/// Mirrors the API's pricing rules (all amounts in soles).
class Pricing {
  const Pricing(this.igvRate);

  final double igvRate;

  PriceBreakdown breakdown(double pricePen) => PriceBreakdown(
        pricePen: _round(pricePen, 4),
        igvPen: _round(pricePen * igvRate, 4),
        priceWithIgvPen: _round(pricePen * (1 + igvRate), 2),
      );

  /// Converts a price with IGV into the base price without IGV that is stored.
  double priceFromWithIgv(double withIgv) => _round(withIgv / (1 + igvRate), 4);
}

/// Flattens categories into roots followed by their children, for indented pickers.
List<PickerOption<int>> buildCategoryOptions(List<Category> categories) {
  int compare(Category a, Category b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    return byOrder != 0 ? byOrder : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  final roots = categories.where((c) => c.parentId == null).toList()..sort(compare);
  final options = <PickerOption<int>>[];
  for (final root in roots) {
    options.add(PickerOption(value: root.id, label: root.name));
    final children = categories.where((c) => c.parentId == root.id).toList()
      ..sort(compare);
    for (final child in children) {
      options.add(PickerOption(value: child.id, label: child.name, depth: 1));
    }
  }
  return options;
}

/// Shared helper for repositories: decode a JSON list of maps.
List<T> parseList<T>(Object? json, T Function(Map<String, dynamic>) parse) =>
    (json is List ? json : const [])
        .whereType<Map<String, dynamic>>()
        .map(parse)
        .toList();
