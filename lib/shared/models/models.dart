import 'enums.dart';
import 'json.dart';

class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  factory PagedResult.fromJson(Object? json, T Function(Map<String, dynamic>) parse) {
    final map = asMap(json);
    return PagedResult(
      items: asMapList(map['items']).map(parse).toList(),
      total: asInt(map['total']),
      page: asInt(map['page'], 1),
      pageSize: asInt(map['pageSize'], 25),
    );
  }

  bool get hasMore => page * pageSize < total;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    this.lastLoginAt,
    this.createdAt,
  });

  final int id;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final String? lastLoginAt;
  final String? createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: asInt(json['id']),
        email: asString(json['email']),
        name: asString(json['name']),
        role: asString(json['role'], 'ADMIN'),
        isActive: asBool(json['isActive'], true),
        lastLoginAt: asStringOrNull(json['lastLoginAt']),
        createdAt: asStringOrNull(json['createdAt']),
      );
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.parentId,
    required this.sortOrder,
    required this.productCount,
  });

  final int id;
  final String name;
  final int? parentId;
  final int sortOrder;
  final int productCount;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: asInt(json['id']),
        name: asString(json['name']),
        parentId: asIntOrNull(json['parentId']),
        sortOrder: asInt(json['sortOrder']),
        productCount: asInt(json['productCount']),
      );
}

class CostCenter {
  const CostCenter({
    required this.id,
    required this.name,
    required this.productCount,
  });

  final int id;
  final String name;
  final int productCount;

  factory CostCenter.fromJson(Map<String, dynamic> json) => CostCenter(
        id: asInt(json['id']),
        name: asString(json['name']),
        productCount: asInt(json['productCount']),
      );
}

class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.country,
    this.contactName,
    this.email,
    this.phone,
    this.notes,
    required this.isActive,
  });

  final int id;
  final String name;
  final String? country;
  final String? contactName;
  final String? email;
  final String? phone;
  final String? notes;
  final bool isActive;

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: asInt(json['id']),
        name: asString(json['name']),
        country: asStringOrNull(json['country']),
        contactName: asStringOrNull(json['contactName']),
        email: asStringOrNull(json['email']),
        phone: asStringOrNull(json['phone']),
        notes: asStringOrNull(json['notes']),
        isActive: asBool(json['isActive'], true),
      );
}

class EquipmentModel {
  const EquipmentModel({
    required this.id,
    required this.name,
    this.brand,
    this.description,
    this.productCount,
  });

  final int id;
  final String name;
  final String? brand;
  final String? description;
  final int? productCount;

  factory EquipmentModel.fromJson(Map<String, dynamic> json) => EquipmentModel(
        id: asInt(json['id']),
        name: asString(json['name']),
        brand: asStringOrNull(json['brand']),
        description: asStringOrNull(json['description']),
        productCount: asIntOrNull(json['productCount']),
      );
}

class PriceBreakdown {
  const PriceBreakdown({
    required this.pricePen,
    required this.igvPen,
    required this.priceWithIgvPen,
    this.minQty,
  });

  final double pricePen;
  final double igvPen;
  final double priceWithIgvPen;
  final int? minQty;

  static PriceBreakdown? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return PriceBreakdown(
      pricePen: asDouble(json['pricePen']),
      igvPen: asDouble(json['igvPen']),
      priceWithIgvPen: asDouble(json['priceWithIgvPen']),
      minQty: asIntOrNull(json['minQty']),
    );
  }
}

class ProductPricing {
  const ProductPricing({this.retail, this.wholesale, this.marginPercent});

  final PriceBreakdown? retail;
  final PriceBreakdown? wholesale;
  final double? marginPercent;

  static const empty = ProductPricing();

  factory ProductPricing.fromJson(Object? json) {
    final map = asMap(json);
    return ProductPricing(
      retail: PriceBreakdown.tryParse(map['retail']),
      wholesale: PriceBreakdown.tryParse(map['wholesale']),
      marginPercent: asDoubleOrNull(map['marginPercent']),
    );
  }
}

/// One class for every product shape the API returns (base, list item, priced, detail).
class Product {
  const Product({
    required this.id,
    required this.code,
    required this.isInternalCode,
    required this.name,
    this.description,
    this.specification,
    this.categoryId,
    this.costCenterId,
    required this.unit,
    required this.stock,
    required this.minStock,
    required this.reorderQuantity,
    this.location,
    this.costPen,
    this.pricePen,
    this.wholesalePricePen,
    this.wholesaleMinQty,
    required this.isConsignment,
    this.notes,
    required this.isActive,
    required this.stockStatus,
    this.categoryName,
    this.costCenterName,
    this.categoryPath,
    required this.incomingQty,
    this.pricing = ProductPricing.empty,
    this.equipment = const [],
  });

  final int id;
  final String code;
  final bool isInternalCode;
  final String name;
  final String? description;
  final String? specification;
  final int? categoryId;
  final int? costCenterId;
  final UnitOfMeasure unit;
  final int stock;
  final int minStock;
  final int reorderQuantity;
  final String? location;
  final double? costPen;

  /// Sale price in soles without IGV.
  final double? pricePen;
  final double? wholesalePricePen;
  final int? wholesaleMinQty;
  final bool isConsignment;
  final String? notes;
  final bool isActive;
  final StockStatus stockStatus;
  final String? categoryName;
  final String? costCenterName;
  final String? categoryPath;
  final int incomingQty;
  final ProductPricing pricing;
  final List<EquipmentModel> equipment;

  factory Product.fromJson(Map<String, dynamic> json) {
    final stock = asInt(json['stock']);
    final minStock = asInt(json['minStock']);
    final StockStatus fallbackStatus = stock == 0
        ? StockStatus.out
        : (minStock > 0 && stock <= minStock ? StockStatus.low : StockStatus.ok);
    return Product(
      id: asInt(json['id']),
      code: asString(json['code']),
      isInternalCode: asBool(json['isInternalCode']),
      name: asString(json['name']),
      description: asStringOrNull(json['description']),
      specification: asStringOrNull(json['specification']),
      categoryId: asIntOrNull(json['categoryId']),
      costCenterId: asIntOrNull(json['costCenterId']),
      unit: UnitOfMeasure.parse(json['unit']),
      stock: stock,
      minStock: minStock,
      reorderQuantity: asInt(json['reorderQuantity']),
      location: asStringOrNull(json['location']),
      costPen: asDoubleOrNull(json['costPen']),
      pricePen: asDoubleOrNull(json['pricePen']),
      wholesalePricePen: asDoubleOrNull(json['wholesalePricePen']),
      wholesaleMinQty: asIntOrNull(json['wholesaleMinQty']),
      isConsignment: asBool(json['isConsignment']),
      notes: asStringOrNull(json['notes']),
      isActive: asBool(json['isActive'], true),
      stockStatus: json['stockStatus'] == null
          ? fallbackStatus
          : StockStatus.parse(json['stockStatus']),
      categoryName: asStringOrNull(json['categoryName']),
      costCenterName: asStringOrNull(json['costCenterName']),
      categoryPath: asStringOrNull(json['categoryPath']),
      incomingQty: asInt(json['incomingQty']),
      pricing: json['pricing'] == null
          ? ProductPricing.empty
          : ProductPricing.fromJson(json['pricing']),
      equipment:
          asMapList(json['equipment']).map(EquipmentModel.fromJson).toList(),
    );
  }
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.type,
    required this.reason,
    required this.quantity,
    required this.stockAfter,
    this.unitPricePen,
    this.counterparty,
    this.referenceType,
    this.referenceId,
    this.note,
    this.userName,
    required this.occurredAt,
  });

  final int id;
  final int productId;
  final String productCode;
  final String productName;
  final UnitOfMeasure unit;
  final MovementType type;
  final MovementReason reason;
  final int quantity;
  final int stockAfter;
  final double? unitPricePen;
  final String? counterparty;
  final String? referenceType;
  final int? referenceId;
  final String? note;
  final String? userName;
  final String occurredAt;

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: asInt(json['id']),
        productId: asInt(json['productId']),
        productCode: asString(json['productCode']),
        productName: asString(json['productName']),
        unit: UnitOfMeasure.parse(json['unit']),
        type: MovementType.parse(json['type']),
        reason: MovementReason.parse(json['reason']),
        quantity: asInt(json['quantity']),
        stockAfter: asInt(json['stockAfter']),
        unitPricePen: asDoubleOrNull(json['unitPricePen']),
        counterparty: asStringOrNull(json['counterparty']),
        referenceType: asStringOrNull(json['referenceType']),
        referenceId: asIntOrNull(json['referenceId']),
        note: asStringOrNull(json['note']),
        userName: asStringOrNull(json['userName']),
        occurredAt: asString(json['occurredAt']),
      );
}

class ImportOrderSummary {
  const ImportOrderSummary({
    required this.id,
    required this.number,
    this.supplierId,
    this.supplierName,
    required this.status,
    this.reference,
    this.orderedAt,
    this.expectedAt,
    this.receivedAt,
    this.notes,
    required this.itemCount,
    required this.totalOrdered,
    required this.totalReceived,
    required this.totalCostPen,
  });

  final int id;
  final int number;
  final int? supplierId;
  final String? supplierName;
  final ImportStatus status;
  final String? reference;
  final String? orderedAt;
  final String? expectedAt;
  final String? receivedAt;
  final String? notes;
  final int itemCount;
  final int totalOrdered;
  final int totalReceived;
  final double totalCostPen;

  factory ImportOrderSummary.fromJson(Map<String, dynamic> json) =>
      ImportOrderSummary(
        id: asInt(json['id']),
        number: asInt(json['number']),
        supplierId: asIntOrNull(json['supplierId']),
        supplierName: asStringOrNull(json['supplierName']),
        status: ImportStatus.parse(json['status']),
        reference: asStringOrNull(json['reference']),
        orderedAt: asStringOrNull(json['orderedAt']),
        expectedAt: asStringOrNull(json['expectedAt']),
        receivedAt: asStringOrNull(json['receivedAt']),
        notes: asStringOrNull(json['notes']),
        itemCount: asInt(json['itemCount']),
        totalOrdered: asInt(json['totalOrdered']),
        totalReceived: asInt(json['totalReceived']),
        totalCostPen: asDouble(json['totalCostPen']),
      );
}

class ImportOrderItem {
  const ImportOrderItem({
    required this.id,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.quantityOrdered,
    required this.quantityReceived,
    this.unitCostPen,
    this.notes,
  });

  final int id;
  final int productId;
  final String productCode;
  final String productName;
  final UnitOfMeasure unit;
  final int quantityOrdered;
  final int quantityReceived;
  final double? unitCostPen;
  final String? notes;

  factory ImportOrderItem.fromJson(Map<String, dynamic> json) =>
      ImportOrderItem(
        id: asInt(json['id']),
        productId: asInt(json['productId']),
        productCode: asString(json['productCode']),
        productName: asString(json['productName']),
        unit: UnitOfMeasure.parse(json['unit']),
        quantityOrdered: asInt(json['quantityOrdered']),
        quantityReceived: asInt(json['quantityReceived']),
        unitCostPen: asDoubleOrNull(json['unitCostPen']),
        notes: asStringOrNull(json['notes']),
      );
}

class ImportOrderDetail {
  const ImportOrderDetail({required this.summary, required this.items});

  final ImportOrderSummary summary;
  final List<ImportOrderItem> items;

  factory ImportOrderDetail.fromJson(Map<String, dynamic> json) =>
      ImportOrderDetail(
        summary: ImportOrderSummary.fromJson(json),
        items: asMapList(json['items']).map(ImportOrderItem.fromJson).toList(),
      );
}

class StockCountSummary {
  const StockCountSummary({
    required this.itemsTotal,
    required this.itemsCounted,
    required this.itemsWithDifference,
    required this.netDifference,
  });

  final int itemsTotal;
  final int itemsCounted;
  final int itemsWithDifference;
  final int netDifference;

  factory StockCountSummary.fromJson(Object? json) {
    final map = asMap(json);
    return StockCountSummary(
      itemsTotal: asInt(map['itemsTotal']),
      itemsCounted: asInt(map['itemsCounted']),
      itemsWithDifference: asInt(map['itemsWithDifference']),
      netDifference: asInt(map['netDifference']),
    );
  }

  double get progress => itemsTotal == 0 ? 0 : itemsCounted / itemsTotal;
}

class StockCount {
  const StockCount({
    required this.id,
    required this.name,
    required this.status,
    this.categoryId,
    this.categoryName,
    this.note,
    this.completedAt,
    required this.createdAt,
    required this.summary,
  });

  final int id;
  final String name;
  final StockCountStatus status;
  final int? categoryId;
  final String? categoryName;
  final String? note;
  final String? completedAt;
  final String createdAt;
  final StockCountSummary summary;

  factory StockCount.fromJson(Map<String, dynamic> json) => StockCount(
        id: asInt(json['id']),
        name: asString(json['name']),
        status: StockCountStatus.parse(json['status']),
        categoryId: asIntOrNull(json['categoryId']),
        categoryName: asStringOrNull(json['categoryName']),
        note: asStringOrNull(json['note']),
        completedAt: asStringOrNull(json['completedAt']),
        createdAt: asString(json['createdAt']),
        summary: StockCountSummary.fromJson(json['summary']),
      );
}

class StockCountItem {
  const StockCountItem({
    required this.id,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    this.categoryName,
    required this.systemQty,
    this.countedQty,
    this.difference,
    this.note,
  });

  final int id;
  final int productId;
  final String productCode;
  final String productName;
  final UnitOfMeasure unit;
  final String? categoryName;
  final int systemQty;
  final int? countedQty;
  final int? difference;
  final String? note;

  factory StockCountItem.fromJson(Map<String, dynamic> json) => StockCountItem(
        id: asInt(json['id']),
        productId: asInt(json['productId']),
        productCode: asString(json['productCode']),
        productName: asString(json['productName']),
        unit: UnitOfMeasure.parse(json['unit']),
        categoryName: asStringOrNull(json['categoryName']),
        systemQty: asInt(json['systemQty']),
        countedQty: asIntOrNull(json['countedQty']),
        difference: asIntOrNull(json['difference']),
        note: asStringOrNull(json['note']),
      );
}

class ReorderSuggestion {
  const ReorderSuggestion({
    required this.product,
    required this.suggestedQty,
    this.estimatedCostPen,
  });

  final Product product;
  final int suggestedQty;
  final double? estimatedCostPen;

  factory ReorderSuggestion.fromJson(Map<String, dynamic> json) =>
      ReorderSuggestion(
        product: Product.fromJson(asMap(json['product'])),
        suggestedQty: asInt(json['suggestedQty']),
        estimatedCostPen: asDoubleOrNull(json['estimatedCostPen']),
      );
}

class ReorderReport {
  const ReorderReport({
    required this.items,
    required this.total,
    required this.outOfStock,
    required this.estimatedCostPen,
  });

  final List<ReorderSuggestion> items;
  final int total;
  final int outOfStock;
  final double estimatedCostPen;

  factory ReorderReport.fromJson(Object? json) {
    final map = asMap(json);
    final summary = asMap(map['summary']);
    return ReorderReport(
      items: asMapList(map['items']).map(ReorderSuggestion.fromJson).toList(),
      total: asInt(summary['total']),
      outOfStock: asInt(summary['outOfStock']),
      estimatedCostPen: asDouble(summary['estimatedCostPen']),
    );
  }
}

class DashboardTotals {
  const DashboardTotals({
    required this.activeProducts,
    required this.totalUnits,
    required this.inventoryValuePen,
    required this.inventoryValueAtPricePen,
    required this.withoutPrice,
    required this.consignmentUnits,
    required this.outOfStock,
    required this.lowStock,
    required this.unconfiguredMinStock,
    required this.incomingUnits,
    required this.openImports,
  });

  final int activeProducts;
  final int totalUnits;
  final double inventoryValuePen;
  final double inventoryValueAtPricePen;
  final int withoutPrice;
  final int consignmentUnits;
  final int outOfStock;
  final int lowStock;
  final int unconfiguredMinStock;
  final int incomingUnits;
  final int openImports;

  factory DashboardTotals.fromJson(Object? json) {
    final map = asMap(json);
    return DashboardTotals(
      activeProducts: asInt(map['activeProducts']),
      totalUnits: asInt(map['totalUnits']),
      inventoryValuePen: asDouble(map['inventoryValuePen']),
      inventoryValueAtPricePen: asDouble(map['inventoryValueAtPricePen']),
      withoutPrice: asInt(map['withoutPrice']),
      consignmentUnits: asInt(map['consignmentUnits']),
      outOfStock: asInt(map['outOfStock']),
      lowStock: asInt(map['lowStock']),
      unconfiguredMinStock: asInt(map['unconfiguredMinStock']),
      incomingUnits: asInt(map['incomingUnits']),
      openImports: asInt(map['openImports']),
    );
  }
}

class CategoryStock {
  const CategoryStock({
    required this.name,
    required this.products,
    required this.units,
  });

  final String name;
  final int products;
  final int units;

  factory CategoryStock.fromJson(Map<String, dynamic> json) => CategoryStock(
        name: asString(json['name']),
        products: asInt(json['products']),
        units: asInt(json['units']),
      );
}

class DailyMovement {
  const DailyMovement({
    required this.date,
    required this.inQty,
    required this.outQty,
  });

  final String date;
  final int inQty;
  final int outQty;

  factory DailyMovement.fromJson(Map<String, dynamic> json) => DailyMovement(
        date: asString(json['date']),
        inQty: asInt(json['inQty']),
        outQty: asInt(json['outQty']),
      );
}

class TopSoldItem {
  const TopSoldItem({
    required this.productId,
    required this.code,
    required this.name,
    required this.quantity,
  });

  final int productId;
  final String code;
  final String name;
  final int quantity;

  factory TopSoldItem.fromJson(Map<String, dynamic> json) => TopSoldItem(
        productId: asInt(json['productId']),
        code: asString(json['code']),
        name: asString(json['name']),
        quantity: asInt(json['quantity']),
      );
}

class AttentionItem {
  const AttentionItem({required this.product, required this.suggestedQty});

  final Product product;
  final int suggestedQty;

  factory AttentionItem.fromJson(Map<String, dynamic> json) => AttentionItem(
        product: Product.fromJson(json),
        suggestedQty: asInt(json['suggestedQty']),
      );
}

class DashboardSummary {
  const DashboardSummary({
    required this.totals,
    required this.stockByCategory,
    required this.dailyMovements,
    required this.topSold,
    required this.recentMovements,
    required this.attention,
  });

  final DashboardTotals totals;
  final List<CategoryStock> stockByCategory;
  final List<DailyMovement> dailyMovements;
  final List<TopSoldItem> topSold;
  final List<StockMovement> recentMovements;
  final List<AttentionItem> attention;

  factory DashboardSummary.fromJson(Object? json) {
    final map = asMap(json);
    return DashboardSummary(
      totals: DashboardTotals.fromJson(map['totals']),
      stockByCategory:
          asMapList(map['stockByCategory']).map(CategoryStock.fromJson).toList(),
      dailyMovements:
          asMapList(map['dailyMovements']).map(DailyMovement.fromJson).toList(),
      topSold: asMapList(map['topSold']).map(TopSoldItem.fromJson).toList(),
      recentMovements: asMapList(map['recentMovements'])
          .map(StockMovement.fromJson)
          .toList(),
      attention: asMapList(map['attention']).map(AttentionItem.fromJson).toList(),
    );
  }
}

class ProductImportIssue {
  const ProductImportIssue({required this.column, required this.message});

  final String column;
  final String message;

  factory ProductImportIssue.fromJson(Map<String, dynamic> json) =>
      ProductImportIssue(
        column: asString(json['column']),
        message: asString(json['message']),
      );
}

class ProductImportRow {
  const ProductImportRow({
    required this.rowNumber,
    required this.isCreate,
    this.code,
    this.name,
    required this.errors,
    required this.warnings,
  });

  final int rowNumber;

  /// `CREATE` or `UPDATE` in the API.
  final bool isCreate;

  /// Null when the system assigns an internal code.
  final String? code;
  final String? name;
  final List<ProductImportIssue> errors;
  final List<ProductImportIssue> warnings;

  factory ProductImportRow.fromJson(Map<String, dynamic> json) => ProductImportRow(
        rowNumber: asInt(json['rowNumber']),
        isCreate: json['action'] == 'CREATE',
        code: asStringOrNull(json['code']),
        name: asStringOrNull(json['name']),
        errors: asMapList(json['errors']).map(ProductImportIssue.fromJson).toList(),
        warnings: asMapList(json['warnings']).map(ProductImportIssue.fromJson).toList(),
      );
}

class ProductImportPreview {
  const ProductImportPreview({
    required this.fileErrors,
    required this.fileWarnings,
    required this.totalRows,
    required this.toCreate,
    required this.toUpdate,
    required this.withErrors,
    required this.withWarnings,
    required this.rows,
  });

  final List<String> fileErrors;
  final List<String> fileWarnings;
  final int totalRows;
  final int toCreate;
  final int toUpdate;
  final int withErrors;
  final int withWarnings;
  final List<ProductImportRow> rows;

  /// Same rule as the web: nothing is imported while the file or any row has errors.
  bool get canImport => fileErrors.isEmpty && withErrors == 0 && totalRows > 0;

  factory ProductImportPreview.fromJson(Object? json) {
    final map = asMap(json);
    final summary = asMap(map['summary']);
    List<String> strings(Object? value) =>
        value is List ? value.map((e) => e.toString()).toList() : const [];
    return ProductImportPreview(
      fileErrors: strings(map['fileErrors']),
      fileWarnings: strings(map['fileWarnings']),
      totalRows: asInt(summary['totalRows']),
      toCreate: asInt(summary['toCreate']),
      toUpdate: asInt(summary['toUpdate']),
      withErrors: asInt(summary['withErrors']),
      withWarnings: asInt(summary['withWarnings']),
      rows: asMapList(map['rows']).map(ProductImportRow.fromJson).toList(),
    );
  }
}

class ProductImportResult {
  const ProductImportResult({
    required this.created,
    required this.updated,
    required this.initialStockMovements,
  });

  final int created;
  final int updated;
  final int initialStockMovements;

  factory ProductImportResult.fromJson(Object? json) {
    final map = asMap(json);
    return ProductImportResult(
      created: asInt(map['created']),
      updated: asInt(map['updated']),
      initialStockMovements: asInt(map['initialStockMovements']),
    );
  }
}
