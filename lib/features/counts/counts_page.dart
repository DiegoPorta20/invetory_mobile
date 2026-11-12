import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/client_config.dart';
import '../../core/data/data_revision.dart';
import '../../core/data/reference_data.dart';
import '../../core/format/formatters.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/data_widgets.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/paged_list.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/toast.dart';
import 'counts_repository.dart';

class CountsPage extends ConsumerStatefulWidget {
  const CountsPage({super.key});

  @override
  ConsumerState<CountsPage> createState() => _CountsPageState();
}

class _CountsPageState extends ConsumerState<CountsPage> {
  StockCountStatus? _status;
  late final PagedController<StockCount> _controller = PagedController(
    fetch: (page) => ref.read(countsRepositoryProvider).list(_status, page),
  );

  @override
  void initState() {
    super.initState();
    _controller.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setStatus(StockCountStatus? status) {
    setState(() => _status = status);
    _controller.reset();
  }

  Future<void> _create() async {
    final id = await showAppSheet<int>(context, builder: (_) => const _NewCountSheet());
    if (id != null && mounted) context.push('/counts/$id');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dataRevisionProvider, (_, _) => _controller.refresh());
    final canCreate = ref.watch(clientConfigProvider)?.can('counts.create') ?? false;

    return ScreenScaffold(
      title: 'Conteos físicos',
      subtitle: 'Toma de inventario y ajustes.',
      hasTabBar: true,
      onRefresh: _controller.refresh,
      fab: canCreate
          ? AppFab(label: 'Nuevo conteo', icon: Icons.add_rounded, onPressed: _create)
          : null,
      slivers: [
        boxSliver(
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
                  child: PillChip(
                    label: 'Todos',
                    selected: _status == null,
                    onTap: () => _setStatus(null),
                  ),
                ),
                for (final status in StockCountStatus.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
                    child: PillChip(
                      label: status.label,
                      selected: _status == status,
                      onTap: () => _setStatus(status),
                    ),
                  ),
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 10),
        ),
        PagedSliver<StockCount>(
          controller: _controller,
          keyOf: (c) => c.id,
          skeletonHeight: 120,
          empty: EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'Sin conteos',
            description:
                'Un conteo congela el stock del sistema para que registres lo que hay en el almacén.',
            action: canCreate
                ? AppButton(
                    label: 'Nuevo conteo',
                    icon: Icons.add_rounded,
                    onPressed: _create,
                  )
                : null,
          ),
          itemBuilder: (context, count, index) => CountCard(
            count: count,
            onTap: () => context.push('/counts/${count.id}'),
          ),
        ),
      ],
    );
  }
}

class CountCard extends StatelessWidget {
  const CountCard({super.key, required this.count, required this.onTap});

  final StockCount count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final s = count.summary;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(count.name, style: textTheme.titleMedium),
              ),
              const SizedBox(width: 8),
              AppBadge(count.status.label, tone: count.status.tone),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            [
              count.categoryName ?? 'Todas las categorías',
              formatDate(count.completedAt ?? count.createdAt),
            ].join(' · '),
            style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
          ),
          const SizedBox(height: 14),
          MeterBar(
            fraction: s.progress,
            color: count.status == StockCountStatus.cancelled
                ? AppColors.slate300
                : AppColors.brand500,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Text(
                  '${formatQuantity(s.itemsCounted)} / ${formatQuantity(s.itemsTotal)} contados',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(color: AppColors.slate700),
                ),
              ),
              const SizedBox(width: 8),
              if (s.itemsWithDifference > 0)
                Flexible(
                  child: AppBadge(
                    '${s.itemsWithDifference} con diferencia',
                    tone: Tone.warning,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewCountSheet extends ConsumerStatefulWidget {
  const _NewCountSheet();

  @override
  ConsumerState<_NewCountSheet> createState() => _NewCountSheetState();
}

class _NewCountSheetState extends ConsumerState<_NewCountSheet> {
  final _name = TextEditingController();
  final _note = TextEditingController();
  int? _categoryId;
  bool _pending = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (_name.text.trim().isEmpty || _pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final count = await ref.read(countsRepositoryProvider).create(
            name: _name.text.trim(),
            categoryId: _categoryId,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      ref.read(dataRevisionProvider.notifier).bump();
      Toast.success('Conteo creado.');
      if (mounted) Navigator.of(context).pop(count.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pending = false;
        _error = errorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).asData?.value ?? const [];
    return SheetFrame(
      title: 'Nuevo conteo',
      subtitle: 'Se congela el stock actual de los productos activos del alcance.',
      footer: SheetActions(
        primaryLabel: 'Crear conteo',
        loading: _pending,
        onPrimary: _submit,
      ),
      child: Column(
        children: [
          AppTextField(
            label: 'Nombre',
            required: true,
            controller: _name,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            hint: 'Ej. Inventario de octubre',
            errorText: _submitted && _name.text.trim().isEmpty
                ? 'Ingresa un nombre para el conteo.'
                : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          PickerField<int>(
            label: 'Alcance',
            value: _categoryId,
            nullLabel: 'Todas las categorías',
            searchable: true,
            options: buildCategoryOptions(categories),
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Nota',
            controller: _note,
            maxLines: 3,
            minLines: 2,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            ErrorBanner(_error!),
          ],
        ],
      ),
    );
  }
}
