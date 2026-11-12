import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/client_config.dart';
import '../../core/data/reference_data.dart';
import '../../core/format/formatters.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/toast.dart';
import 'entity_sheet.dart';

class CostCentersPage extends ConsumerWidget {
  const CostCentersPage({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [CostCenter? center]) async {
    final saved = await showAppSheet<bool>(
      context,
      builder: (_) => _CostCenterSheet(center: center),
    );
    if (saved == true) ref.invalidate(costCentersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centers = ref.watch(costCentersProvider);
    final canManage = ref.watch(clientConfigProvider)?.can('cost-centers.manage') ?? false;
    final textTheme = Theme.of(context).textTheme;

    return ScreenScaffold(
      title: 'Centros de costo',
      subtitle: 'Líneas de negocio, independientes de las categorías.',
      showBack: true,
      onRefresh: () async {
        ref.invalidate(costCentersProvider);
        try {
          await ref.read(costCentersProvider.future);
        } catch (_) {}
      },
      fab: canManage
          ? AppFab(
              label: 'Nuevo centro',
              icon: Icons.add_rounded,
              onPressed: () => _edit(context, ref),
            )
          : null,
      slivers: [
        centers.when(
          loading: () => boxSliver(const SkeletonList(count: 4, height: 76)),
          error: (error, _) => SliverToBoxAdapter(
            child: ErrorState(
              message: errorText(error),
              onRetry: () => ref.invalidate(costCentersProvider),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.sell_outlined,
                  title: 'Sin centros de costo',
                  description: 'Crea las líneas de negocio para agrupar tus precios.',
                  action: canManage
                      ? AppButton(
                          label: 'Nuevo centro',
                          icon: Icons.add_rounded,
                          onPressed: () => _edit(context, ref),
                        )
                      : null,
                ),
              );
            }
            return gutterSliver(
              SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final c = items[index];
                  return Reveal(
                    key: ValueKey(c.id),
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        onTap: canManage ? () => _edit(context, ref, c) : null,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const IconTile(Icons.sell_outlined),
                            const SizedBox(width: 12),
                            Expanded(child: Text(c.name, style: textTheme.titleSmall)),
                            Text(formatQuantity(c.productCount), style: textTheme.titleSmall),
                            const SizedBox(width: 4),
                            Text(
                              'prod.',
                              style: textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CostCenterSheet extends ConsumerStatefulWidget {
  const _CostCenterSheet({this.center});

  final CostCenter? center;

  @override
  ConsumerState<_CostCenterSheet> createState() => _CostCenterSheetState();
}

class _CostCenterSheetState extends ConsumerState<_CostCenterSheet> {
  late final _name = TextEditingController(text: widget.center?.name);
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _nameError =>
      _submitted && _name.text.trim().isEmpty ? 'Ingresa el nombre del centro de costo.' : null;

  @override
  Widget build(BuildContext context) {
    final editing = widget.center != null;
    return EntitySheet(
      title: editing ? 'Editar centro de costo' : 'Nuevo centro de costo',
      validate: () {
        setState(() => _submitted = true);
        return _nameError == null;
      },
      onSave: () async {
        final body = {'name': _name.text.trim()};
        final api = ref.read(apiClientProvider);
        if (editing) {
          await api.patch('/api/cost-centers/${widget.center!.id}', body: body);
        } else {
          await api.post('/api/cost-centers', body: body);
        }
        Toast.success(editing ? 'Centro de costo actualizado.' : 'Centro de costo creado.');
      },
      onDelete: editing
          ? () async {
              await ref.read(apiClientProvider).delete('/api/cost-centers/${widget.center!.id}');
              Toast.success('Centro de costo eliminado.');
            }
          : null,
      deleteTitle: 'Eliminar centro de costo',
      deleteMessage: '¿Eliminar "${widget.center?.name}"? No debe tener productos asignados.',
      child: Column(
        children: [
          AppTextField(
            label: 'Nombre',
            required: true,
            controller: _name,
            maxLength: 120,
            errorText: _nameError,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
          if (editing && widget.center!.productCount > 0) ...[
            const SizedBox(height: 14),
            AppButton(
              label: 'Ver ${formatQuantity(widget.center!.productCount)} productos',
              icon: Icons.inventory_2_outlined,
              variant: ButtonVariant.secondary,
              expand: true,
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/products?costCenterId=${widget.center!.id}');
              },
            ),
          ],
        ],
      ),
    );
  }
}
