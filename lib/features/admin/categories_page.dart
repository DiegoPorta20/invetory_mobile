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

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    List<Category> all, [
    Category? category,
  ]) async {
    final saved = await showAppSheet<bool>(
      context,
      builder: (_) => _CategorySheet(category: category, all: all),
    );
    if (saved == true) {
      ref.invalidate(categoriesProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final canManage = ref.watch(clientConfigProvider)?.can('categories.manage') ?? false;
    final textTheme = Theme.of(context).textTheme;
    final all = categories.asData?.value ?? const <Category>[];

    return ScreenScaffold(
      title: 'Categorías',
      subtitle: 'Clasificación de productos en dos niveles.',
      showBack: true,
      onRefresh: () async {
        ref.invalidate(categoriesProvider);
        try {
          await ref.read(categoriesProvider.future);
        } catch (_) {}
      },
      fab: categories.hasValue && canManage
          ? AppFab(
              label: 'Nueva categoría',
              icon: Icons.add_rounded,
              onPressed: () => _edit(context, ref, all),
            )
          : null,
      slivers: [
        categories.when(
          loading: () => boxSliver(const SkeletonList(count: 5, height: 76)),
          error: (error, _) => SliverToBoxAdapter(
            child: ErrorState(
              message: errorText(error),
              onRetry: () => ref.invalidate(categoriesProvider),
            ),
          ),
          data: (list) {
            final options = buildCategoryOptions(list);
            if (options.isEmpty) {
              return SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.layers_outlined,
                  title: 'Sin categorías',
                  description: 'Crea categorías para clasificar tus productos.',
                  action: canManage
                      ? AppButton(
                          label: 'Nueva categoría',
                          icon: Icons.add_rounded,
                          onPressed: () => _edit(context, ref, list),
                        )
                      : null,
                ),
              );
            }
            final byId = {for (final c in list) c.id: c};
            return gutterSliver(
              SliverList.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final category = byId[option.value]!;
                  final isRoot = option.depth == 0;
                  return Reveal(
                    key: ValueKey(category.id),
                    index: index,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 10, left: isRoot ? 0 : 22),
                      child: AppCard(
                        onTap: canManage ? () => _edit(context, ref, list, category) : null,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            IconTile(
                              isRoot ? Icons.folder_outlined : Icons.subdirectory_arrow_right_rounded,
                              color: isRoot ? AppColors.brand600 : AppColors.slate500,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                category.name,
                                style: isRoot ? textTheme.titleSmall : textTheme.bodyLarge,
                              ),
                            ),
                            Text(
                              formatQuantity(category.productCount),
                              style: textTheme.titleSmall,
                            ),
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

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({required this.category, required this.all});

  final Category? category;
  final List<Category> all;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final _name = TextEditingController(text: widget.category?.name);
  late final _order = TextEditingController(
    text: (widget.category?.sortOrder ?? 0).toString(),
  );
  late int? _parentId = widget.category?.parentId;
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _order.dispose();
    super.dispose();
  }

  String? get _nameError =>
      _submitted && _name.text.trim().isEmpty ? 'Ingresa el nombre de la categoría.' : null;

  @override
  Widget build(BuildContext context) {
    final editing = widget.category != null;
    final hasChildren =
        editing && widget.all.any((c) => c.parentId == widget.category!.id);
    // Only two levels exist: the parent must be a root, and a category with children stays a root.
    final parentOptions = [
      for (final c in widget.all)
        if (c.parentId == null && c.id != widget.category?.id)
          PickerOption(value: c.id, label: c.name),
    ];

    return EntitySheet(
      title: editing ? 'Editar categoría' : 'Nueva categoría',
      validate: () {
        setState(() => _submitted = true);
        return _nameError == null;
      },
      onSave: () async {
        final body = {
          'name': _name.text.trim(),
          'parentId': _parentId,
          'sortOrder': int.tryParse(_order.text.trim()) ?? 0,
        };
        final api = ref.read(apiClientProvider);
        if (editing) {
          await api.patch('/api/categories/${widget.category!.id}', body: body);
        } else {
          await api.post('/api/categories', body: body);
        }
        Toast.success(editing ? 'Categoría actualizada.' : 'Categoría creada.');
      },
      onDelete: editing
          ? () async {
              await ref.read(apiClientProvider).delete('/api/categories/${widget.category!.id}');
              Toast.success('Categoría eliminada.');
            }
          : null,
      deleteTitle: 'Eliminar categoría',
      deleteMessage: '¿Eliminar "${widget.category?.name}"? Debe estar vacía.',
      child: Column(
        children: [
          AppTextField(
            label: 'Nombre',
            required: true,
            controller: _name,
            maxLength: 120,
            errorText: _nameError,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          PickerField<int>(
            label: 'Categoría padre',
            value: _parentId,
            nullLabel: '— Categoría principal —',
            enabled: !hasChildren,
            helper: hasChildren ? 'Tiene subcategorías, por eso es principal.' : null,
            options: parentOptions,
            onChanged: (value) => setState(() => _parentId = value),
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Orden',
            controller: _order,
            keyboardType: numberKeyboard(),
            inputFormatters: numberFormatters(),
            helper: 'Las categorías con menor número aparecen primero.',
          ),
          if (editing && widget.category!.productCount > 0) ...[
            const SizedBox(height: 14),
            AppButton(
              label: 'Ver ${formatQuantity(widget.category!.productCount)} productos',
              icon: Icons.inventory_2_outlined,
              variant: ButtonVariant.secondary,
              expand: true,
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/products?categoryId=${widget.category!.id}');
              },
            ),
          ],
        ],
      ),
    );
  }
}
