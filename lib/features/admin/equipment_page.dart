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

class EquipmentPage extends ConsumerStatefulWidget {
  const EquipmentPage({super.key});

  @override
  ConsumerState<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends ConsumerState<EquipmentPage> {
  String _search = '';

  Future<void> _edit([EquipmentModel? model]) async {
    final saved = await showAppSheet<bool>(
      context,
      builder: (_) => _EquipmentSheet(model: model),
    );
    if (saved == true) ref.invalidate(equipmentProvider);
  }

  @override
  Widget build(BuildContext context) {
    final equipment = ref.watch(equipmentProvider);
    final canManage = ref.watch(clientConfigProvider)?.can('equipment.manage') ?? false;
    final textTheme = Theme.of(context).textTheme;
    final q = _search.toLowerCase();

    return ScreenScaffold(
      title: 'Equipos',
      subtitle: 'Modelos a los que pertenecen los repuestos.',
      showBack: true,
      onRefresh: () async {
        ref.invalidate(equipmentProvider);
        try {
          await ref.read(equipmentProvider.future);
        } catch (_) {}
      },
      fab: canManage
          ? AppFab(label: 'Nuevo equipo', icon: Icons.add_rounded, onPressed: _edit)
          : null,
      slivers: [
        PinnedBar(
          height: 66,
          child: SearchPill(
            hint: 'Buscar equipo',
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 6)),
        equipment.when(
          loading: () => boxSliver(const SkeletonList(count: 4, height: 84)),
          error: (error, _) => SliverToBoxAdapter(
            child: ErrorState(
              message: errorText(error),
              onRetry: () => ref.invalidate(equipmentProvider),
            ),
          ),
          data: (all) {
            final items = all
                .where((e) =>
                    q.isEmpty ||
                    e.name.toLowerCase().contains(q) ||
                    (e.brand?.toLowerCase().contains(q) ?? false))
                .toList();
            if (items.isEmpty) {
              return SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.precision_manufacturing_outlined,
                  title: 'Sin equipos',
                  description: all.isEmpty
                      ? 'Registra los equipos para vincular repuestos compatibles.'
                      : 'Ningún equipo coincide con la búsqueda.',
                  action: all.isEmpty && canManage
                      ? AppButton(
                          label: 'Nuevo equipo',
                          icon: Icons.add_rounded,
                          onPressed: _edit,
                        )
                      : null,
                ),
              );
            }
            return gutterSliver(
              SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final e = items[index];
                  return Reveal(
                    key: ValueKey(e.id),
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        onTap: canManage ? () => _edit(e) : null,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const IconTile(Icons.precision_manufacturing_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.name, style: textTheme.titleSmall),
                                  if (e.brand != null || e.description != null)
                                    Text(
                                      e.brand ?? e.description!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall
                                          ?.copyWith(color: AppColors.slate500),
                                    ),
                                ],
                              ),
                            ),
                            if (e.productCount != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(formatQuantity(e.productCount),
                                      style: textTheme.titleMedium),
                                  Text(
                                    'repuestos',
                                    style: textTheme.bodySmall
                                        ?.copyWith(color: AppColors.slate400),
                                  ),
                                ],
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

class _EquipmentSheet extends ConsumerStatefulWidget {
  const _EquipmentSheet({this.model});

  final EquipmentModel? model;

  @override
  ConsumerState<_EquipmentSheet> createState() => _EquipmentSheetState();
}

class _EquipmentSheetState extends ConsumerState<_EquipmentSheet> {
  late final _name = TextEditingController(text: widget.model?.name);
  late final _brand = TextEditingController(text: widget.model?.brand);
  late final _description = TextEditingController(text: widget.model?.description);
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _blankToNull(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  String? get _nameError =>
      _submitted && _name.text.trim().isEmpty ? 'Ingresa el nombre del equipo.' : null;

  @override
  Widget build(BuildContext context) {
    final editing = widget.model != null;
    return EntitySheet(
      title: editing ? 'Editar equipo' : 'Nuevo equipo',
      validate: () {
        setState(() => _submitted = true);
        return _nameError == null;
      },
      onSave: () async {
        final body = {
          'name': _name.text.trim(),
          'brand': _blankToNull(_brand),
          'description': _blankToNull(_description),
        };
        final api = ref.read(apiClientProvider);
        if (editing) {
          await api.patch('/api/equipment-models/${widget.model!.id}', body: body);
        } else {
          await api.post('/api/equipment-models', body: body);
        }
        Toast.success(editing ? 'Equipo actualizado.' : 'Equipo creado.');
      },
      onDelete: editing
          ? () async {
              await ref
                  .read(apiClientProvider)
                  .delete('/api/equipment-models/${widget.model!.id}');
              Toast.success('Equipo eliminado.');
            }
          : null,
      deleteTitle: 'Eliminar equipo',
      deleteMessage: '¿Eliminar "${widget.model?.name}"? Se quitará de los repuestos vinculados.',
      child: Column(
        children: [
          AppTextField(
            label: 'Nombre',
            required: true,
            controller: _name,
            maxLength: 160,
            errorText: _nameError,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Marca',
            controller: _brand,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Descripción',
            controller: _description,
            maxLines: 3,
            minLines: 2,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (editing && (widget.model!.productCount ?? 0) > 0) ...[
            const SizedBox(height: 14),
            AppButton(
              label: 'Ver ${formatQuantity(widget.model!.productCount)} repuestos',
              icon: Icons.inventory_2_outlined,
              variant: ButtonVariant.secondary,
              expand: true,
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/products?equipmentId=${widget.model!.id}');
              },
            ),
          ],
        ],
      ),
    );
  }
}
