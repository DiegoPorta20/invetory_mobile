import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/client_config.dart';
import '../../core/data/data_revision.dart';
import '../../core/format/formatters.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/data_widgets.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/paged_list.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/toast.dart';
import 'counts_repository.dart';

class CountDetailPage extends ConsumerStatefulWidget {
  const CountDetailPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<CountDetailPage> createState() => _CountDetailPageState();
}

class _CountDetailPageState extends ConsumerState<CountDetailPage> {
  CountItemFilters _filters = const CountItemFilters();
  bool _busy = false;
  late final PagedController<StockCountItem> _controller = PagedController(
    fetch: (page) => ref.read(countsRepositoryProvider).items(widget.id, _filters, page),
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

  void _setFilters(CountItemFilters next) {
    setState(() => _filters = next);
    _controller.reset();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      Toast.error(errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmPending(StockCount count) async {
    final ok = await confirmAction(
      context,
      title: 'Confirmar pendientes',
      message:
          'Los productos sin contar se marcarán con la cantidad del sistema (${count.summary.itemsTotal - count.summary.itemsCounted} pendientes). No generarán ajuste.',
      confirmLabel: 'Confirmar',
    );
    if (!ok) return;
    await _run(() async {
      final confirmed = await ref.read(countsRepositoryProvider).confirmPending(widget.id);
      ref.read(dataRevisionProvider.notifier).bump();
      Toast.success('$confirmed producto(s) confirmados con el stock del sistema.');
    });
  }

  Future<void> _complete(StockCount count) async {
    final s = count.summary;
    final ok = await confirmAction(
      context,
      title: 'Completar conteo',
      message:
          'Se generarán ajustes de stock para los productos con diferencia (${s.itemsWithDifference}). Un conteo completado no se puede editar.',
      confirmLabel: 'Completar',
    );
    if (!ok) return;
    await _run(() async {
      final adjustments = await ref.read(countsRepositoryProvider).complete(widget.id);
      ref.read(dataRevisionProvider.notifier).bump();
      Toast.success('Conteo completado. $adjustments ajuste(s) generados.');
    });
  }

  Future<void> _cancel() async {
    final ok = await confirmAction(
      context,
      title: 'Cancelar conteo',
      message: '¿Seguro que deseas cancelar este conteo? No se aplicará ningún ajuste.',
      confirmLabel: 'Cancelar conteo',
      cancelLabel: 'Volver',
      danger: true,
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(countsRepositoryProvider).cancel(widget.id);
      ref.read(dataRevisionProvider.notifier).bump();
      Toast.success('Conteo cancelado.');
    });
  }

  Future<void> _record(StockCount count, StockCountItem item) async {
    final updated = await showAppSheet<StockCountItem>(
      context,
      builder: (_) => _RecordSheet(countId: count.id, item: item),
    );
    if (updated == null) return;
    // Counted items may stop matching the active filter (e.g. "pending only").
    _controller.replaceWhere((x) => x.id == updated.id, updated);
    ref.invalidate(countProvider(widget.id));
  }

  bool _can(String permission) =>
      ref.read(clientConfigProvider)?.can(permission) ?? false;

  void _openMenu(StockCount count) {
    final canRecord = _can('counts.record');
    final canComplete = _can('counts.complete');
    showAppSheet<void>(
      context,
      builder: (sheetContext) => SheetFrame(
        title: 'Acciones del conteo',
        child: Column(
          children: [
            if (canRecord)
            _SheetAction(
              icon: Icons.done_all_rounded,
              label: 'Confirmar pendientes con stock del sistema',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmPending(count);
              },
            ),
            if (canRecord && canComplete) const Divider(),
            if (canComplete)
            _SheetAction(
              icon: Icons.cancel_outlined,
              label: 'Cancelar conteo',
              color: AppColors.rose600,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _cancel();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final countAsync = ref.watch(countProvider(widget.id));
    ref.listen(dataRevisionProvider, (_, _) => _controller.refresh());

    final count = countAsync.asData?.value;
    if (count == null) {
      return ScreenScaffold(
        title: 'Conteo',
        showBack: true,
        slivers: [
          countAsync.hasError
              ? SliverToBoxAdapter(
                  child: ErrorState(
                    message: errorText(countAsync.error),
                    onRetry: () => ref.invalidate(countProvider(widget.id)),
                  ),
                )
              : const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: kGutter),
                  sliver: SliverToBoxAdapter(child: SkeletonList(count: 3)),
                ),
        ],
      );
    }

    final isOpen = count.status == StockCountStatus.open;
    final config = ref.watch(clientConfigProvider);
    final canRecord = config?.can('counts.record') ?? false;
    final canComplete = config?.can('counts.complete') ?? false;
    final canSeeMovements = config?.can('movements.view') ?? false;
    final s = count.summary;
    final netTone = s.netDifference == 0
        ? AppColors.slate900
        : (s.netDifference > 0 ? AppColors.emerald700 : AppColors.rose600);

    return ScreenScaffold(
      title: count.name,
      subtitle: count.categoryName != null
          ? 'Alcance: ${count.categoryName}'
          : 'Alcance: todas las categorías',
      showBack: true,
      onRefresh: () async {
        ref.invalidate(countProvider(widget.id));
        await _controller.refresh();
      },
      actions: [
        if (isOpen && (canRecord || canComplete))
          AppIconButton(
            icon: Icons.more_horiz_rounded,
            tooltip: 'Más acciones',
            onPressed: () => _openMenu(count),
          ),
      ],
      bottomBar: isOpen
          ? (!canComplete ? null : AppButton(
              label: 'Completar conteo',
              icon: Icons.check_rounded,
              expand: true,
              loading: _busy,
              onPressed: () => _complete(count),
            ))
          : !canSeeMovements ? null : AppButton(
              label: 'Ver ajustes generados',
              icon: Icons.swap_horiz_rounded,
              variant: ButtonVariant.secondary,
              expand: true,
              onPressed: () => context.push(
                '/history?referenceType=STOCK_COUNT&referenceId=${count.id}',
              ),
            ),
      slivers: [
        boxSliver(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppBadge(count.status.label, tone: count.status.tone),
                  if (count.completedAt != null)
                    Text(
                      'Completado el ${formatDateTime(count.completedAt)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.slate500),
                    ),
                  if (count.note != null && count.note!.isNotEmpty)
                    Text(
                      '· ${count.note}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.slate500),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            'Contados',
                            '${formatQuantity(s.itemsCounted)} / ${formatQuantity(s.itemsTotal)}',
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            'Con diferencia',
                            formatQuantity(s.itemsWithDifference),
                            color: s.itemsWithDifference > 0 ? AppColors.amber700 : null,
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            'Diferencia neta',
                            formatSignedQuantity(s.netDifference),
                            color: netTone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    MeterBar(fraction: s.progress),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
        PinnedBar(
          height: 66,
          child: SearchPill(
            hint: 'Código o descripción',
            initialValue: _filters.search,
            onChanged: (value) => _setFilters(_filters.copyWith(search: value)),
          ),
        ),
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
                    label: 'Solo con diferencias',
                    selected: _filters.onlyDifferences,
                    onTap: () => _setFilters(
                      _filters.copyWith(onlyDifferences: !_filters.onlyDifferences),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
                  child: PillChip(
                    label: 'Pendientes de contar',
                    selected: _filters.onlyPending,
                    onTap: () => _setFilters(
                      _filters.copyWith(onlyPending: !_filters.onlyPending),
                    ),
                  ),
                ),
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 8),
        ),
        PagedSliver<StockCountItem>(
          controller: _controller,
          keyOf: (i) => i.id,
          skeletonHeight: 100,
          gap: 10,
          empty: const EmptyState(
            icon: Icons.checklist_rounded,
            title: 'Sin productos',
            description: 'Ningún producto coincide con los filtros.',
          ),
          itemBuilder: (context, item, index) => _ItemTile(
            item: item,
            enabled: isOpen && canRecord,
            onTap: () => _record(count, item),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.bodySmall?.copyWith(color: AppColors.slate500)),
        const SizedBox(height: 3),
        Text(value, style: textTheme.titleMedium?.copyWith(color: color)),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.enabled, required this.onTap});

  final StockCountItem item;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final counted = item.countedQty != null;
    final diff = item.difference ?? 0;

    return AppCard(
      onTap: enabled ? onTap : null,
      padding: const EdgeInsets.all(14),
      accent: counted && diff != 0 ? AppColors.amber400 : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productCode,
                    style: textTheme.labelLarge?.copyWith(color: AppColors.slate700)),
                const SizedBox(height: 3),
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                if (item.categoryName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.categoryName!,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                  ),
                ],
                if (item.note != null && item.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.slate500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Sistema ${formatQuantity(item.systemQty)} ${item.unit.label}',
                style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: AppMotion.normal,
                child: counted
                    ? Row(
                        key: ValueKey(item.countedQty),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatQuantity(item.countedQty),
                              style: textTheme.titleLarge),
                          if (diff != 0) ...[
                            const SizedBox(width: 6),
                            AppBadge(
                              formatSignedQuantity(diff),
                              tone: diff > 0 ? Tone.success : Tone.danger,
                            ),
                          ],
                        ],
                      )
                    : const AppBadge('Pendiente', key: ValueKey('p')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color ?? AppColors.slate600),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: color ?? AppColors.slate800,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Count entry: big numeric field with +/- steppers and a shortcut to the system quantity.
class _RecordSheet extends ConsumerStatefulWidget {
  const _RecordSheet({required this.countId, required this.item});

  final int countId;
  final StockCountItem item;

  @override
  ConsumerState<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<_RecordSheet> {
  late final TextEditingController _qty = TextEditingController(
    text: widget.item.countedQty?.toString() ?? '',
  );
  late final TextEditingController _note =
      TextEditingController(text: widget.item.note ?? '');
  bool _pending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _qty.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_qty.text.trim());

  void _step(int delta) {
    HapticFeedback.selectionClick();
    final next = ((_value ?? widget.item.systemQty) + delta).clamp(0, 10000000);
    _qty.text = next.toString();
    _qty.selection = TextSelection.collapsed(offset: _qty.text.length);
  }

  Future<void> _save({required int? value}) async {
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final updated = await ref.read(countsRepositoryProvider).recordItem(
            widget.countId,
            widget.item.id,
            countedQty: value,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(updated);
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
    final textTheme = Theme.of(context).textTheme;
    final item = widget.item;
    final value = _value;
    final diff = value == null ? null : value - item.systemQty;

    return SheetFrame(
      title: item.productName,
      subtitle: '${item.productCode} · Sistema: ${formatQuantity(item.systemQty)} ${item.unit.label}',
      footer: SheetActions(
        primaryLabel: 'Guardar conteo',
        loading: _pending,
        onPrimary: value == null ? null : () => _save(value: value),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundStep(icon: Icons.remove_rounded, onTap: () => _step(-1)),
              Expanded(
                child: TextField(
                  controller: _qty,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: numberKeyboard(),
                  inputFormatters: numberFormatters(),
                  style: textTheme.displaySmall,
                  decoration: const InputDecoration(
                    hintText: '—',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              _RoundStep(icon: Icons.add_rounded, onTap: () => _step(1)),
            ],
          ),
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.ease,
            alignment: Alignment.topCenter,
            child: diff == null
                ? const SizedBox(width: double.infinity)
                : Center(
                    child: AppBadge(
                      diff == 0
                          ? 'Sin diferencia'
                          : 'Diferencia ${formatSignedQuantity(diff)}',
                      tone: diff == 0
                          ? Tone.success
                          : (diff > 0 ? Tone.info : Tone.danger),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Usar stock del sistema',
                  variant: ButtonVariant.secondary,
                  small: true,
                  onPressed: _pending
                      ? null
                      : () {
                          _qty.text = item.systemQty.toString();
                        },
                ),
              ),
              if (item.countedQty != null) ...[
                const SizedBox(width: 10),
                AppButton(
                  label: 'Borrar',
                  variant: ButtonVariant.ghost,
                  small: true,
                  onPressed: _pending ? null : () => _save(value: null),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Nota',
            controller: _note,
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(_error!),
          ],
        ],
      ),
    );
  }
}

class _RoundStep extends StatelessWidget {
  const _RoundStep({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.brand100,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.brand200),
        ),
        child: Icon(icon, color: AppColors.brand700, size: 26),
      ),
    );
  }
}
