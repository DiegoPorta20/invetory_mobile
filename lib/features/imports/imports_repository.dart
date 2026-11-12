import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/data/data_revision.dart';
import '../../core/network/api_client.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';

/// Lines passed from the reorder screen to the import form (go_router `extra`).
class ImportPrefillLine {
  const ImportPrefillLine({
    required this.productId,
    required this.code,
    required this.name,
    required this.unit,
    required this.quantityOrdered,
    this.unitCostPen,
  });

  final int productId;
  final String code;
  final String name;
  final UnitOfMeasure unit;
  final int quantityOrdered;
  final double? unitCostPen;
}

class ImportPrefill {
  const ImportPrefill(this.items);
  final List<ImportPrefillLine> items;
}

const _unset = Object();

class ImportFilters {
  const ImportFilters({
    this.status,
    this.supplierId,
    this.search = '',
    this.from,
    this.to,
  });

  final ImportStatus? status;
  final int? supplierId;
  final String search;
  final String? from;
  final String? to;

  ImportFilters copyWith({
    Object? status = _unset,
    Object? supplierId = _unset,
    String? search,
    Object? from = _unset,
    Object? to = _unset,
  }) =>
      ImportFilters(
        status: identical(status, _unset) ? this.status : status as ImportStatus?,
        supplierId: identical(supplierId, _unset) ? this.supplierId : supplierId as int?,
        search: search ?? this.search,
        from: identical(from, _unset) ? this.from : from as String?,
        to: identical(to, _unset) ? this.to : to as String?,
      );

  int get activeCount => [
        status != null,
        supplierId != null,
        search.isNotEmpty,
        from != null,
        to != null,
      ].where((on) => on).length;
}

class ImportItemInput {
  const ImportItemInput({
    required this.productId,
    required this.quantityOrdered,
    this.unitCostPen,
  });

  final int productId;
  final int quantityOrdered;
  final double? unitCostPen;

  Map<String, Object?> toJson() => {
        'productId': productId,
        'quantityOrdered': quantityOrdered,
        'unitCostPen': unitCostPen,
      };
}

class ImportInput {
  const ImportInput({
    this.supplierId,
    this.reference,
    this.orderedAt,
    this.expectedAt,
    this.notes,
    required this.items,
    this.status,
  });

  final int? supplierId;
  final String? reference;
  final String? orderedAt;
  final String? expectedAt;
  final String? notes;
  final List<ImportItemInput> items;

  /// `DRAFT` or `ORDERED`; only sent when creating.
  final String? status;

  Map<String, Object?> toJson() => {
        'supplierId': supplierId,
        'reference': reference,
        'orderedAt': orderedAt,
        'expectedAt': expectedAt,
        'notes': notes,
        'items': [for (final i in items) i.toJson()],
        if (status != null) 'status': status,
      };
}

class ImportsRepository {
  ImportsRepository(this._api);

  final ApiClient _api;

  Future<PagedResult<ImportOrderSummary>> list(ImportFilters filters, int page,
      {int pageSize = 25}) async {
    final json = await _api.get('/api/imports', query: {
      'status': filters.status?.wire,
      'supplierId': filters.supplierId,
      'search': filters.search.isEmpty ? null : filters.search,
      'from': filters.from,
      'to': filters.to,
      'page': page,
      'pageSize': pageSize,
    });
    return PagedResult.fromJson(json, ImportOrderSummary.fromJson);
  }

  Future<ImportOrderDetail> get(int id) async => ImportOrderDetail.fromJson(
        await _api.get('/api/imports/$id') as Map<String, dynamic>,
      );

  Future<ImportOrderDetail> create(ImportInput input) => createRaw(input.toJson());

  Future<ImportOrderDetail> createRaw(Map<String, Object?> body) async =>
      ImportOrderDetail.fromJson(
        await _api.post('/api/imports', body: body) as Map<String, dynamic>,
      );

  Future<ImportOrderDetail> update(int id, ImportInput input) =>
      updateRaw(id, input.toJson());

  Future<ImportOrderDetail> updateRaw(int id, Map<String, Object?> body) async {
    final changes = {...body}..remove('status');
    return ImportOrderDetail.fromJson(
      await _api.patch('/api/imports/$id', body: changes) as Map<String, dynamic>,
    );
  }

  Future<ImportOrderDetail> changeStatus(int id, ImportStatus status) async =>
      ImportOrderDetail.fromJson(
        await _api.post('/api/imports/$id/status', body: {'status': status.wire})
            as Map<String, dynamic>,
      );

  Future<ImportOrderDetail> receive(
    int id, {
    String? receivedAt,
    List<({int itemId, int quantityReceived})>? lines,
  }) async =>
      ImportOrderDetail.fromJson(
        await _api.post('/api/imports/$id/receive', body: {
          'receivedAt': ?receivedAt,
          if (lines != null)
            'lines': [
              for (final l in lines)
                {'itemId': l.itemId, 'quantityReceived': l.quantityReceived},
            ],
        }) as Map<String, dynamic>,
      );

  Future<void> remove(int id) => _api.delete('/api/imports/$id');
}

final importsRepositoryProvider = Provider<ImportsRepository>(
  (ref) => ImportsRepository(ref.watch(apiClientProvider)),
);

final importDetailProvider =
    FutureProvider.autoDispose.family<ImportOrderDetail, int>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(importsRepositoryProvider).get(id);
});
