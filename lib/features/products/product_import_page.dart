import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data/data_revision.dart';
import '../../core/format/formatters.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/toast.dart';
import 'products_repository.dart';

const _maxBytes = 5 * 1024 * 1024;
const _rowStep = 50;
const _xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

enum _RowFilter { all, errors, warnings }

class ProductImportPage extends ConsumerStatefulWidget {
  const ProductImportPage({super.key});

  @override
  ConsumerState<ProductImportPage> createState() => _ProductImportPageState();
}

class _ProductImportPageState extends ConsumerState<ProductImportPage> {
  List<int>? _bytes;
  String? _fileName;
  ProductImportPreview? _preview;
  _RowFilter _filter = _RowFilter.all;
  int _shown = _rowStep;
  bool _downloading = false;
  bool _validating = false;
  bool _importing = false;
  String? _error;

  Future<void> _downloadTemplate() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final bytes = await ref.read(productsRepositoryProvider).downloadImportTemplate();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: _xlsxMime)],
          fileNameOverrides: const ['plantilla-productos.xlsx'],
          subject: 'Plantilla de productos',
        ),
      );
    } catch (error) {
      Toast.error(errorText(error, 'No se pudo descargar la plantilla.'));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _pickFile() async {
    if (_validating || _importing) return;
    final PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        dialogTitle: 'Selecciona el archivo Excel',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
    } catch (_) {
      Toast.error('No se pudo abrir el selector de archivos.');
      return;
    }
    if (picked == null || !mounted) return;

    // The API only accepts .xlsx up to 5 MB; fail fast instead of uploading in vain.
    if (!picked.name.toLowerCase().endsWith('.xlsx')) {
      setState(() => _error = 'Solo se admiten archivos Excel con extensión .xlsx.');
      return;
    }
    final size = await picked.length();
    if (size != null && size > _maxBytes) {
      if (mounted) setState(() => _error = 'El archivo es demasiado grande (máximo 5 MB).');
      return;
    }

    setState(() {
      _validating = true;
      _error = null;
      _preview = null;
      _filter = _RowFilter.all;
      _shown = _rowStep;
    });
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.length > _maxBytes) {
        throw const ApiException(
          statusCode: 413,
          code: 'PAYLOAD_TOO_LARGE',
          message: 'El archivo es demasiado grande (máximo 5 MB).',
        );
      }
      final preview =
          await ref.read(productsRepositoryProvider).previewImport(bytes, picked.name);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _fileName = picked!.name;
        _preview = preview;
        _validating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _fileName = null;
        _validating = false;
        _error = errorText(error, 'No se pudo validar el archivo.');
      });
    }
  }

  Future<void> _confirmImport() async {
    final preview = _preview;
    final bytes = _bytes;
    final name = _fileName;
    if (preview == null || bytes == null || name == null || !preview.canImport || _importing) {
      return;
    }
    final ok = await confirmAction(
      context,
      title: 'Importar productos',
      message:
          'Se crearán ${preview.toCreate} y se actualizarán ${preview.toUpdate} productos. '
          'La importación es todo o nada y no se puede deshacer.',
      confirmLabel: 'Importar',
    );
    if (!ok || !mounted) return;

    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final result =
          await ref.read(productsRepositoryProvider).importProducts(bytes, name);
      ref.read(dataRevisionProvider.notifier).bump();
      final parts = [
        if (result.created > 0) '${result.created} creados',
        if (result.updated > 0) '${result.updated} actualizados',
      ];
      Toast.success('Importación completa: ${parts.join(' y ')}.');
      if (mounted) context.go('/products');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = errorText(error, 'No se pudo importar el archivo.');
      });
    }
  }

  List<ProductImportRow> get _filteredRows {
    final rows = _preview?.rows ?? const <ProductImportRow>[];
    return switch (_filter) {
      _RowFilter.all => rows,
      _RowFilter.errors => rows.where((r) => r.errors.isNotEmpty).toList(),
      _RowFilter.warnings => rows.where((r) => r.warnings.isNotEmpty).toList(),
    };
  }

  String _sizeText(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).ceil()} KB'
      : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final preview = _preview;
    final valid = (preview?.toCreate ?? 0) + (preview?.toUpdate ?? 0);

    return ScreenScaffold(
      title: 'Importar productos',
      subtitle: 'Crea o actualiza productos desde un Excel.',
      showBack: true,
      bottomBar: preview == null
          ? null
          : AppButton(
              label: _importing
                  ? 'Importando…'
                  : 'Importar $valid ${valid == 1 ? 'producto' : 'productos'}',
              icon: Icons.upload_rounded,
              expand: true,
              loading: _importing,
              onPressed: preview.canImport ? _confirmImport : null,
            ),
      slivers: [
        gutterSliver(
          SliverList.list(
            children: [
              Reveal(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('1. Descarga la plantilla'),
                        const SizedBox(height: 10),
                        Text(
                          'Una fila por producto. Trae listas desplegables, una hoja de instrucciones y notas en cada encabezado.',
                          style: textTheme.bodyMedium?.copyWith(color: AppColors.slate600),
                        ),
                        const SizedBox(height: 12),
                        for (final rule in const [
                          'Si el código ya existe, se actualiza ese producto.',
                          'Si el código no existe o va vacío, se crea uno nuevo.',
                          'Las celdas vacías no modifican los productos existentes.',
                          'Costo sin IGV; precios de venta con IGV, en soles.',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 6, right: 10),
                                  child: Icon(Icons.circle, size: 5, color: AppColors.slate400),
                                ),
                                Expanded(
                                  child: Text(
                                    rule,
                                    style: textTheme.bodyMedium
                                        ?.copyWith(color: AppColors.slate600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        AppButton(
                          label: _downloading ? 'Descargando…' : 'Descargar plantilla',
                          icon: Icons.download_rounded,
                          variant: ButtonVariant.secondary,
                          loading: _downloading,
                          expand: true,
                          onPressed: _downloadTemplate,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Reveal(
                index: 1,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('2. Sube tu archivo'),
                        const SizedBox(height: 10),
                        Text(
                          'Excel (.xlsx), máximo 5 MB y 2000 filas. Se valida antes de guardar nada.',
                          style: textTheme.bodyMedium?.copyWith(color: AppColors.slate600),
                        ),
                        const SizedBox(height: 14),
                        if (_fileName != null && _bytes != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.slate50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.lineStrong),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.table_chart_outlined,
                                    color: AppColors.emerald700),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fileName!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.titleSmall,
                                      ),
                                      Text(
                                        _sizeText(_bytes!.length),
                                        style: textTheme.bodySmall
                                            ?.copyWith(color: AppColors.slate500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        AppButton(
                          label: _validating
                              ? 'Validando…'
                              : (_fileName == null ? 'Elegir archivo' : 'Elegir otro archivo'),
                          icon: Icons.folder_open_rounded,
                          loading: _validating,
                          expand: true,
                          onPressed: _importing ? null : _pickFile,
                        ),
                        AnimatedSize(
                          duration: AppMotion.normal,
                          curve: AppMotion.ease,
                          alignment: Alignment.topCenter,
                          child: _error == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: ErrorBanner(_error!),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (preview != null) ..._previewSection(context, preview),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _previewSection(BuildContext context, ProductImportPreview p) {
    final textTheme = Theme.of(context).textTheme;
    final rows = _filteredRows;
    final visible = rows.take(_shown).toList();
    final hidden = rows.length - visible.length;

    Widget stat(String label, int value, {Color? color, String? hint}) => AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.slate500)),
              const SizedBox(height: 4),
              Text(
                formatQuantity(value),
                style: textTheme.headlineSmall?.copyWith(color: color),
              ),
              if (hint != null)
                Text(hint,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.slate400)),
            ],
          ),
        );

    return [
      Reveal(
        index: 2,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 2),
          child: const SectionTitle('3. Revisa y confirma'),
        ),
      ),
      for (final error in p.fileErrors)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ErrorBanner(error),
        ),
      for (final warning in p.fileWarnings)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _WarningBanner(warning),
        ),
      if (p.fileErrors.isEmpty) ...[
        Reveal(
          index: 3,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                for (final pair in [
                  [
                    stat('Filas con datos', p.totalRows),
                    stat('Se crearán', p.toCreate,
                        color: p.toCreate > 0 ? AppColors.emerald700 : null),
                  ],
                  [
                    stat('Se actualizarán', p.toUpdate),
                    stat('Con errores', p.withErrors,
                        color: p.withErrors > 0 ? AppColors.rose600 : null),
                  ],
                  [
                    stat('Con avisos', p.withWarnings,
                        color: p.withWarnings > 0 ? AppColors.amber700 : null,
                        hint: 'No bloquean'),
                    const SizedBox.shrink(),
                  ],
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: pair[0]),
                          const SizedBox(width: 12),
                          Expanded(child: pair[1]),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!p.canImport && p.withErrors > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: const ErrorBanner(
              'Corrige los errores en tu archivo y vuelve a subirlo. No se importa nada mientras haya errores.',
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                for (final (filter, label) in const [
                  (_RowFilter.all, 'Todas'),
                  (_RowFilter.errors, 'Con errores'),
                  (_RowFilter.warnings, 'Con avisos'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PillChip(
                      label: label,
                      selected: _filter == filter,
                      onTap: () => setState(() {
                        _filter = filter;
                        _shown = _rowStep;
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (rows.isEmpty)
          const AppCard(
            child: Center(child: Text('No hay filas para este filtro.')),
          ),
        for (var i = 0; i < visible.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RowCard(row: visible[i]),
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppButton(
              label: 'Mostrar ${hidden < _rowStep ? hidden : _rowStep} más ($hidden sin mostrar)',
              variant: ButtonVariant.secondary,
              small: true,
              onPressed: () => setState(() => _shown += _rowStep),
            ),
          ),
      ],
    ];
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.row});

  final ProductImportRow row;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasError = row.errors.isNotEmpty;
    final (label, tone) = hasError
        ? ('Con error', Tone.danger)
        : (row.isCreate ? ('Nuevo', Tone.success) : ('Actualiza', Tone.brand));

    return AppCard(
      padding: const EdgeInsets.all(14),
      accent: hasError ? AppColors.rose400 : (row.warnings.isNotEmpty ? AppColors.amber400 : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Fila ${row.rowNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(color: AppColors.slate500),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: AppBadge(label, tone: tone)),
            ],
          ),
          const SizedBox(height: 6),
          Text(row.code ?? 'Código automático', style: textTheme.titleSmall),
          if (row.name != null)
            Text(
              row.name!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.slate600),
            ),
          for (final issue in row.errors)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text.rich(
                TextSpan(
                  text: '${issue.column}: ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                  children: [
                    TextSpan(
                      text: issue.message,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                style: textTheme.bodySmall?.copyWith(color: AppColors.rose700),
              ),
            ),
          for (final issue in row.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text.rich(
                TextSpan(
                  text: 'Aviso · ${issue.column}: ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                  children: [
                    TextSpan(
                      text: issue.message,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                style: textTheme.bodySmall?.copyWith(color: AppColors.amber700),
              ),
            ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.amber700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.amber700),
            ),
          ),
        ],
      ),
    );
  }
}
