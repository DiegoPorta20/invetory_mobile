/// Error returned by the API (or a transport failure with [statusCode] 0).
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.fieldErrors = const {},
  });

  final int statusCode;
  final String code;
  final String message;

  /// Validation messages keyed by field name (`details[].path`).
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == 0;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';

  factory ApiException.network() => const ApiException(
        statusCode: 0,
        code: 'NETWORK',
        message: 'No hay conexión con el servidor.',
      );

  factory ApiException.fromBody(int statusCode, Object? body) {
    var code = 'UNKNOWN';
    String? serverMessage;
    final fields = <String, String>{};
    if (body is Map<String, dynamic>) {
      code = (body['code'] ?? 'UNKNOWN').toString();
      serverMessage = body['message']?.toString();
      final details = body['details'];
      if (details is List) {
        for (final issue in details) {
          if (issue is Map<String, dynamic> && issue['path'] != null) {
            fields[issue['path'].toString()] = (issue['message'] ?? '').toString();
          }
        }
      }
    }
    if (statusCode == 413) {
      code = 'PAYLOAD_TOO_LARGE';
    }
    return ApiException(
      statusCode: statusCode,
      code: code,
      message: _messages[code] ?? serverMessage ?? 'Ocurrió un error inesperado.',
      fieldErrors: fields,
    );
  }
}

const _messages = <String, String>{
  'UNAUTHORIZED': 'Tu sesión expiró. Inicia sesión nuevamente.',
  'FORBIDDEN': 'No tienes permiso para realizar esta acción.',
  'NOT_FOUND': 'No se encontró el registro solicitado.',
  'CONFLICT': 'Ya existe un registro con esos datos.',
  'VALIDATION_ERROR': 'Revisa los campos marcados.',
  'INSUFFICIENT_STOCK': 'Stock insuficiente para realizar la salida.',
  'INVALID_MOVEMENT_REASON':
      'El motivo no es válido para este tipo de movimiento.',
  'PRODUCT_HAS_HISTORY':
      'El producto tiene historial; desactívalo en lugar de eliminarlo.',
  'CATEGORY_IN_USE': 'La categoría tiene productos o subcategorías.',
  'CATEGORY_DEPTH_EXCEEDED': 'Solo se permiten dos niveles de categorías.',
  'SUPPLIER_IN_USE':
      'El proveedor tiene importaciones; desactívalo en lugar de eliminarlo.',
  'COST_CENTER_IN_USE':
      'El centro de costo tiene productos; reasígnalos antes de eliminarlo.',
  'IMPORT_NOT_EDITABLE': 'La importación ya no se puede modificar.',
  'IMPORT_NOT_RECEIVABLE':
      'La importación no se puede recibir en su estado actual.',
  'INVALID_IMPORT_TRANSITION':
      'No se puede cambiar la importación a ese estado.',
  'STOCK_COUNT_CLOSED': 'El conteo ya fue cerrado.',
  'STOCK_COUNT_EMPTY':
      'Registra al menos una cantidad contada antes de completar.',
  'STOCK_COUNT_EMPTY_SCOPE':
      'No hay productos activos en el alcance seleccionado.',
  'CANNOT_MODIFY_SELF': 'No puedes desactivarte ni cambiar tu propio rol.',
  'INVALID_CURRENT_PASSWORD': 'La contraseña actual es incorrecta.',
  'TOO_MANY_REQUESTS':
      'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
  'PAYLOAD_TOO_LARGE': 'El archivo es demasiado grande (máximo 5 MB).',
  'INVALID_SPREADSHEET': 'El archivo no es un Excel (.xlsx) válido.',
  'PRODUCT_IMPORT_HAS_ERRORS':
      'El archivo tiene errores; corrígelos y vuelve a subirlo.',
  'PRODUCT_IMPORT_EMPTY': 'El archivo no tiene filas de productos.',
};

/// User-facing text for any thrown value.
String errorText(Object? error, [String fallback = 'Ocurrió un error inesperado.']) {
  if (error is ApiException) return error.message;
  return fallback;
}
