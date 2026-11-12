import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';

const _unset = Object();

class MovementFilters {
  const MovementFilters({
    this.search = '',
    this.productId,
    this.type,
    this.reason,
    this.from,
    this.to,
    this.referenceType,
    this.referenceId,
  });

  final String search;
  final int? productId;
  final MovementType? type;
  final MovementReason? reason;
  final String? from;
  final String? to;
  final String? referenceType;
  final int? referenceId;

  MovementFilters copyWith({
    String? search,
    Object? productId = _unset,
    Object? type = _unset,
    Object? reason = _unset,
    Object? from = _unset,
    Object? to = _unset,
    Object? referenceType = _unset,
    Object? referenceId = _unset,
  }) {
    return MovementFilters(
      search: search ?? this.search,
      productId: identical(productId, _unset) ? this.productId : productId as int?,
      type: identical(type, _unset) ? this.type : type as MovementType?,
      reason: identical(reason, _unset) ? this.reason : reason as MovementReason?,
      from: identical(from, _unset) ? this.from : from as String?,
      to: identical(to, _unset) ? this.to : to as String?,
      referenceType:
          identical(referenceType, _unset) ? this.referenceType : referenceType as String?,
      referenceId:
          identical(referenceId, _unset) ? this.referenceId : referenceId as int?,
    );
  }

  int get activeCount => [
        search.isNotEmpty,
        productId != null,
        type != null,
        reason != null,
        from != null,
        to != null,
        referenceType != null,
      ].where((on) => on).length;

  QueryParams toQuery({int? page, int? pageSize}) => {
        'search': search.isEmpty ? null : search,
        'productId': productId,
        'type': type?.wire,
        'reason': reason?.wire,
        'from': from,
        'to': to,
        'referenceType': referenceType,
        'referenceId': referenceId,
        'page': page,
        'pageSize': pageSize,
      };

  factory MovementFilters.fromQuery(Map<String, String> query) => MovementFilters(
        productId: int.tryParse(query['productId'] ?? ''),
        referenceType: query['referenceType'],
        referenceId: int.tryParse(query['referenceId'] ?? ''),
      );
}

class MovementsRepository {
  MovementsRepository(this._api);

  final ApiClient _api;

  Future<PagedResult<StockMovement>> list(MovementFilters filters, int page,
      {int pageSize = 25}) async {
    final json = await _api.get(
      '/api/stock-movements',
      query: filters.toQuery(page: page, pageSize: pageSize),
    );
    return PagedResult.fromJson(json, StockMovement.fromJson);
  }

  Future<Uint8List> export(MovementFilters filters) =>
      _api.getBytes('/api/stock-movements/export', query: filters.toQuery());
}

final movementsRepositoryProvider = Provider<MovementsRepository>(
  (ref) => MovementsRepository(ref.watch(apiClientProvider)),
);
