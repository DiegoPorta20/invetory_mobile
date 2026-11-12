import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/data/data_revision.dart';
import '../../core/network/api_client.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';

class CountItemFilters {
  const CountItemFilters({
    this.search = '',
    this.onlyDifferences = false,
    this.onlyPending = false,
  });

  final String search;
  final bool onlyDifferences;
  final bool onlyPending;

  CountItemFilters copyWith({
    String? search,
    bool? onlyDifferences,
    bool? onlyPending,
  }) =>
      CountItemFilters(
        search: search ?? this.search,
        onlyDifferences: onlyDifferences ?? this.onlyDifferences,
        onlyPending: onlyPending ?? this.onlyPending,
      );

  QueryParams toQuery(int page, int pageSize) => {
        'search': search.isEmpty ? null : search,
        'onlyDifferences': onlyDifferences ? true : null,
        'onlyPending': onlyPending ? true : null,
        'page': page,
        'pageSize': pageSize,
      };
}

class CountsRepository {
  CountsRepository(this._api);

  final ApiClient _api;

  Future<PagedResult<StockCount>> list(StockCountStatus? status, int page,
      {int pageSize = 25}) async {
    final json = await _api.get('/api/stock-counts', query: {
      'status': status?.wire,
      'page': page,
      'pageSize': pageSize,
    });
    return PagedResult.fromJson(json, StockCount.fromJson);
  }

  Future<StockCount> get(int id) async =>
      StockCount.fromJson(await _api.get('/api/stock-counts/$id') as Map<String, dynamic>);

  Future<PagedResult<StockCountItem>> items(int id, CountItemFilters filters, int page,
      {int pageSize = 50}) async {
    final json = await _api.get(
      '/api/stock-counts/$id/items',
      query: filters.toQuery(page, pageSize),
    );
    return PagedResult.fromJson(json, StockCountItem.fromJson);
  }

  Future<StockCount> create({
    required String name,
    int? categoryId,
    String? note,
  }) async =>
      StockCount.fromJson(
        await _api.post('/api/stock-counts', body: {
          'name': name,
          'categoryId': categoryId,
          'note': note,
        }) as Map<String, dynamic>,
      );

  Future<StockCountItem> recordItem(
    int countId,
    int itemId, {
    required int? countedQty,
    String? note,
  }) async =>
      StockCountItem.fromJson(
        await _api.patch('/api/stock-counts/$countId/items/$itemId', body: {
          'countedQty': countedQty,
          'note': note,
        }) as Map<String, dynamic>,
      );

  Future<int> confirmPending(int id) async {
    final json = await _api.post('/api/stock-counts/$id/confirm-pending');
    return (json as Map<String, dynamic>)['confirmed'] as int? ?? 0;
  }

  Future<int> complete(int id) async {
    final json = await _api.post('/api/stock-counts/$id/complete');
    return (json as Map<String, dynamic>)['adjustments'] as int? ?? 0;
  }

  Future<void> cancel(int id) => _api.post('/api/stock-counts/$id/cancel');
}

final countsRepositoryProvider = Provider<CountsRepository>(
  (ref) => CountsRepository(ref.watch(apiClientProvider)),
);

final countProvider = FutureProvider.autoDispose.family<StockCount, int>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(countsRepositoryProvider).get(id);
});
