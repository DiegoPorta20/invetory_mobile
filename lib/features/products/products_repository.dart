import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/data/data_revision.dart';
import '../../core/network/api_client.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';

enum ActiveFilter {
  active('Activos'),
  inactive('Inactivos'),
  all('Todos');

  const ActiveFilter(this.label);
  final String label;
}

enum ProductSort {
  code('code', 'Código'),
  name('name', 'Descripción'),
  stock('stock', 'Stock'),
  updatedAt('updatedAt', 'Última actualización'),
  cost('cost', 'Costo'),
  price('price', 'Precio');

  const ProductSort(this.wire, this.label);
  final String wire;
  final String label;
}

const _unset = Object();

/// Immutable product list filters; maps 1:1 to the `/api/products` query.
class ProductFilters {
  const ProductFilters({
    this.search = '',
    this.categoryId,
    this.costCenterId,
    this.unit,
    this.stockStatus,
    this.equipmentId,
    this.importOrderId,
    this.active = ActiveFilter.active,
    this.internalCode,
    this.hasPrice,
    this.consignment = false,
    this.sortBy = ProductSort.code,
    this.descending = false,
  });

  final String search;
  final int? categoryId;
  final int? costCenterId;
  final UnitOfMeasure? unit;
  final StockFilter? stockStatus;
  final int? equipmentId;
  final int? importOrderId;
  final ActiveFilter active;

  /// `true` = internal codes only, `false` = supplier codes only.
  final bool? internalCode;
  final bool? hasPrice;
  final bool consignment;
  final ProductSort sortBy;
  final bool descending;

  ProductFilters copyWith({
    String? search,
    Object? categoryId = _unset,
    Object? costCenterId = _unset,
    Object? unit = _unset,
    Object? stockStatus = _unset,
    Object? equipmentId = _unset,
    Object? importOrderId = _unset,
    ActiveFilter? active,
    Object? internalCode = _unset,
    Object? hasPrice = _unset,
    bool? consignment,
    ProductSort? sortBy,
    bool? descending,
  }) {
    return ProductFilters(
      search: search ?? this.search,
      categoryId: identical(categoryId, _unset) ? this.categoryId : categoryId as int?,
      costCenterId:
          identical(costCenterId, _unset) ? this.costCenterId : costCenterId as int?,
      unit: identical(unit, _unset) ? this.unit : unit as UnitOfMeasure?,
      stockStatus:
          identical(stockStatus, _unset) ? this.stockStatus : stockStatus as StockFilter?,
      equipmentId:
          identical(equipmentId, _unset) ? this.equipmentId : equipmentId as int?,
      importOrderId:
          identical(importOrderId, _unset) ? this.importOrderId : importOrderId as int?,
      active: active ?? this.active,
      internalCode:
          identical(internalCode, _unset) ? this.internalCode : internalCode as bool?,
      hasPrice: identical(hasPrice, _unset) ? this.hasPrice : hasPrice as bool?,
      consignment: consignment ?? this.consignment,
      sortBy: sortBy ?? this.sortBy,
      descending: descending ?? this.descending,
    );
  }

  /// Number of filters that differ from the defaults (sorting is not a filter).
  int get activeCount => [
        search.isNotEmpty,
        categoryId != null,
        costCenterId != null,
        unit != null,
        stockStatus != null,
        equipmentId != null,
        importOrderId != null,
        active != ActiveFilter.active,
        internalCode != null,
        hasPrice != null,
        consignment,
      ].where((on) => on).length;

  QueryParams toQuery({int? page, int? pageSize}) => {
        'search': search.isEmpty ? null : search,
        'categoryId': categoryId,
        'costCenterId': costCenterId,
        'unit': unit?.wire,
        'stockStatus': stockStatus?.wire,
        'equipmentId': equipmentId,
        'importOrderId': importOrderId,
        'isActive': switch (active) {
          ActiveFilter.active => true,
          ActiveFilter.inactive => false,
          ActiveFilter.all => null,
        },
        'isInternalCode': internalCode,
        'isConsignment': consignment ? true : null,
        'hasPrice': hasPrice,
        'sortBy': sortBy.wire,
        'sortDirection': descending ? 'desc' : 'asc',
        'page': page,
        'pageSize': pageSize,
      };

  /// Filters coming from dashboard shortcuts (`/products?stockStatus=OUT`).
  factory ProductFilters.fromQuery(Map<String, String> query) {
    return ProductFilters(
      search: query['search'] ?? '',
      categoryId: int.tryParse(query['categoryId'] ?? ''),
      costCenterId: int.tryParse(query['costCenterId'] ?? ''),
      equipmentId: int.tryParse(query['equipmentId'] ?? ''),
      stockStatus: StockFilter.tryParse(query['stockStatus']),
      hasPrice: switch (query['hasPrice']) {
        'true' => true,
        'false' => false,
        _ => null,
      },
    );
  }
}

class ProductInput {
  ProductInput({
    this.code,
    required this.name,
    this.description,
    this.specification,
    this.categoryId,
    this.costCenterId,
    required this.unit,
    this.minStock = 0,
    this.reorderQuantity = 0,
    this.location,
    this.costPen,
    this.pricePen,
    this.wholesalePricePen,
    this.wholesaleMinQty,
    this.isConsignment = false,
    this.notes,
    this.isActive = true,
    this.equipmentIds = const [],
  });

  final String? code;
  final String name;
  final String? description;
  final String? specification;
  final int? categoryId;
  final int? costCenterId;
  final UnitOfMeasure unit;
  final int minStock;
  final int reorderQuantity;
  final String? location;
  final double? costPen;
  final double? pricePen;
  final double? wholesalePricePen;
  final int? wholesaleMinQty;
  final bool isConsignment;
  final String? notes;
  final bool isActive;
  final List<int> equipmentIds;

  /// Cost and price keys are only sent when the user may see them; the API rejects writes to
  /// fields the caller cannot read, and an omitted key leaves the stored value untouched.
  Map<String, Object?> toJson({bool withCosts = true, bool withPrices = true}) => {
        if (code != null) 'code': code,
        'name': name,
        'description': description,
        'specification': specification,
        'categoryId': categoryId,
        'costCenterId': costCenterId,
        'unit': unit.wire,
        'minStock': minStock,
        'reorderQuantity': reorderQuantity,
        'location': location,
        if (withCosts) 'costPen': costPen,
        if (withPrices) ...{
          'pricePen': pricePen,
          'wholesalePricePen': wholesalePricePen,
          'wholesaleMinQty': wholesaleMinQty,
        },
        'isConsignment': isConsignment,
        'notes': notes,
        'isActive': isActive,
        'equipmentIds': equipmentIds,
      };
}

class ProductsRepository {
  ProductsRepository(this._api);

  final ApiClient _api;

  Future<PagedResult<Product>> list(ProductFilters filters, int page, {int pageSize = 25}) async {
    final json = await _api.get(
      '/api/products',
      query: filters.toQuery(page: page, pageSize: pageSize),
    );
    return PagedResult.fromJson(json, Product.fromJson);
  }

  /// Lightweight search used by pickers (active products only).
  Future<List<Product>> search(String term, {int pageSize = 20}) async {
    final json = await _api.get('/api/products', query: {
      'search': term.isEmpty ? null : term,
      'isActive': true,
      'sortBy': 'name',
      'sortDirection': 'asc',
      'pageSize': pageSize,
    });
    return PagedResult.fromJson(json, Product.fromJson).items;
  }

  Future<Product> get(int id) async =>
      Product.fromJson(await _api.get('/api/products/$id') as Map<String, dynamic>);

  Future<Product> create(
    ProductInput input, {
    bool withCosts = true,
    bool withPrices = true,
  }) async =>
      Product.fromJson(
        await _api.post(
          '/api/products',
          body: input.toJson(withCosts: withCosts, withPrices: withPrices),
        ) as Map<String, dynamic>,
      );

  Future<Product> update(int id, Map<String, Object?> changes) async => Product.fromJson(
        await _api.patch('/api/products/$id', body: changes) as Map<String, dynamic>,
      );

  Future<void> remove(int id) => _api.delete('/api/products/$id');

  Future<void> bulkUpdate(List<int> ids, Map<String, Object?> changes) =>
      _api.patch('/api/products/bulk', body: {'ids': ids, 'changes': changes});

  /// Excel template with dropdowns for categories, cost centers and units.
  Future<Uint8List> downloadImportTemplate() =>
      _api.getBytes('/api/products/import/template');

  /// Inventory spreadsheet for the current filters (same rules as the list).
  Future<Uint8List> exportInventory(ProductFilters filters) =>
      _api.getBytes('/api/products/export', query: filters.toQuery());

  /// Price list: only active products with a price, per the API.
  Future<Uint8List> exportPriceList(ProductFilters filters) =>
      _api.getBytes('/api/products/price-list/export', query: filters.toQuery());

  /// Validates the workbook without saving anything.
  Future<ProductImportPreview> previewImport(List<int> bytes, String filename) async =>
      ProductImportPreview.fromJson(
        await _api.postFile(
          '/api/products/import/preview',
          field: 'file',
          bytes: bytes,
          filename: filename,
        ),
      );

  /// All-or-nothing import; the API rejects it if any row has errors.
  Future<ProductImportResult> importProducts(List<int> bytes, String filename) async =>
      ProductImportResult.fromJson(
        await _api.postFile(
          '/api/products/import',
          field: 'file',
          bytes: bytes,
          filename: filename,
        ),
      );

  Future<PagedResult<StockMovement>> movements(int productId) async {
    final json = await _api.get('/api/stock-movements', query: {
      'productId': productId,
      'pageSize': 10,
    });
    return PagedResult.fromJson(json, StockMovement.fromJson);
  }

  Future<PagedResult<ImportOrderSummary>> imports(int productId) async {
    final json = await _api.get('/api/imports', query: {
      'productId': productId,
      'pageSize': 50,
    });
    return PagedResult.fromJson(json, ImportOrderSummary.fromJson);
  }
}

final productsRepositoryProvider = Provider<ProductsRepository>(
  (ref) => ProductsRepository(ref.watch(apiClientProvider)),
);

/// Open and recent imports, for the "Importación" filter.
final importsLookupProvider = FutureProvider<List<ImportOrderSummary>>((ref) async {
  final json = await ref.watch(apiClientProvider).get('/api/imports', query: {'pageSize': 100});
  return PagedResult.fromJson(json, ImportOrderSummary.fromJson).items;
});

final productDetailProvider =
    FutureProvider.autoDispose.family<Product, int>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(productsRepositoryProvider).get(id);
});

final productMovementsProvider =
    FutureProvider.autoDispose.family<PagedResult<StockMovement>, int>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(productsRepositoryProvider).movements(id);
});

final productImportsProvider =
    FutureProvider.autoDispose.family<PagedResult<ImportOrderSummary>, int>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(productsRepositoryProvider).imports(id);
});
