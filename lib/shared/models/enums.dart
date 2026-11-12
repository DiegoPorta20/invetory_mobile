import '../../core/theme/app_colors.dart';

/// Enums mirror the API string values (`wire`) and carry their Spanish UI label.

enum UnitOfMeasure {
  unit('UNIT', 'Unid.'),
  pcs('PCS', 'Pzas.'),
  set('SET', 'Set');

  const UnitOfMeasure(this.wire, this.label);
  final String wire;
  final String label;

  static UnitOfMeasure parse(Object? value) => values.firstWhere(
        (item) => item.wire == value,
        orElse: () => UnitOfMeasure.pcs,
      );
}

enum StockStatus {
  out('OUT', 'Sin stock', Tone.danger),
  low('LOW', 'Stock bajo', Tone.warning),
  ok('OK', 'Stock OK', Tone.success);

  const StockStatus(this.wire, this.label, this.tone);
  final String wire;
  final String label;
  final Tone tone;

  static StockStatus parse(Object? value) => values.firstWhere(
        (item) => item.wire == value,
        orElse: () => StockStatus.ok,
      );
}

/// Stock filter values accepted by the products endpoint.
enum StockFilter {
  out('OUT', 'Sin stock'),
  low('LOW', 'Stock bajo'),
  ok('OK', 'Stock OK'),
  unconfigured('UNCONFIGURED', 'Sin mínimo configurado');

  const StockFilter(this.wire, this.label);
  final String wire;
  final String label;

  static StockFilter? tryParse(String? value) {
    for (final item in values) {
      if (item.wire == value) return item;
    }
    return null;
  }
}

enum MovementType {
  inbound('IN', 'Entrada', Tone.success),
  outbound('OUT', 'Salida', Tone.danger),
  adjustment('ADJUSTMENT', 'Ajuste', Tone.info);

  const MovementType(this.wire, this.label, this.tone);
  final String wire;
  final String label;
  final Tone tone;

  static MovementType parse(Object? value) => values.firstWhere(
        (item) => item.wire == value,
        orElse: () => MovementType.adjustment,
      );

  /// Reasons a user may pick by hand; the rest are system-only.
  List<MovementReason> get manualReasons => switch (this) {
        MovementType.inbound => const [
            MovementReason.customerReturn,
            MovementReason.initialLoad,
            MovementReason.other,
          ],
        MovementType.outbound => const [
            MovementReason.sale,
            MovementReason.supplierReturn,
            MovementReason.damage,
            MovementReason.internalUse,
            MovementReason.other,
          ],
        MovementType.adjustment => const [MovementReason.correction],
      };
}

enum MovementReason {
  importReceipt('IMPORT_RECEIPT', 'Recepción de importación'),
  customerReturn('CUSTOMER_RETURN', 'Devolución de cliente'),
  initialLoad('INITIAL_LOAD', 'Carga inicial'),
  sale('SALE', 'Venta'),
  supplierReturn('SUPPLIER_RETURN', 'Devolución a proveedor'),
  damage('DAMAGE', 'Merma / daño'),
  internalUse('INTERNAL_USE', 'Uso interno'),
  countAdjustment('COUNT_ADJUSTMENT', 'Ajuste por conteo'),
  correction('CORRECTION', 'Corrección'),
  other('OTHER', 'Otro');

  const MovementReason(this.wire, this.label);
  final String wire;
  final String label;

  static MovementReason parse(Object? value) => values.firstWhere(
        (item) => item.wire == value,
        orElse: () => MovementReason.other,
      );
}

enum ImportStatus {
  draft('DRAFT', 'Borrador', Tone.neutral),
  ordered('ORDERED', 'Pedido', Tone.info),
  inTransit('IN_TRANSIT', 'En tránsito', Tone.warning),
  received('RECEIVED', 'Recibido', Tone.success),
  cancelled('CANCELLED', 'Cancelado', Tone.danger);

  const ImportStatus(this.wire, this.label, this.tone);
  final String wire;
  final String label;
  final Tone tone;

  static ImportStatus parse(Object? value) => values.firstWhere(
        (item) => item.wire == value,
        orElse: () => ImportStatus.draft,
      );

  bool get isEditable =>
      this == draft || this == ordered || this == inTransit;
  bool get canReceive => this == ordered || this == inTransit;
}

enum StockCountStatus {
  open('OPEN', 'En curso', Tone.info),
  completed('COMPLETED', 'Completado', Tone.success),
  cancelled('CANCELLED', 'Cancelado', Tone.neutral);

  const StockCountStatus(this.wire, this.label, this.tone);
  final String wire;
  final String label;
  final Tone tone;

  static StockCountStatus parse(Object? value) => values.firstWhere(
        (item) => item.wire == value,
        orElse: () => StockCountStatus.open,
      );
}

const roleLabels = {'ADMIN': 'Administrador', 'PERSONAL': 'Personal'};
