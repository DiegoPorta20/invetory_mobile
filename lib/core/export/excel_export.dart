import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../../shared/widgets/toast.dart';
import '../format/formatters.dart';
import '../network/api_exception.dart';

const xlsxMimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// `inventario` -> `inventario-2026-11-08.xlsx`, so repeated exports do not overwrite each other.
String datedExcelName(String base) => '$base-${toIsoDay(DateTime.now())}.xlsx';

/// Downloads an Excel file from the API and opens the system share sheet, where the user can
/// save it to Files/Drive, open it in Excel, or send it by WhatsApp or email.
Future<void> shareExcel(
  Future<Uint8List> Function() fetch, {
  required String filename,
  String? subject,
}) async {
  Toast.info('Generando Excel…');
  try {
    final bytes = await fetch();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: xlsxMimeType)],
        fileNameOverrides: [filename],
        subject: subject ?? filename,
      ),
    );
  } catch (error) {
    Toast.error(errorText(error, 'No se pudo generar el archivo.'));
  }
}
