import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/client_config.dart';
import '../../core/data/reference_data.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
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
import 'entity_sheet.dart';

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  String _search = '';

  Future<void> _edit([Supplier? supplier]) async {
    final saved = await showAppSheet<bool>(
      context,
      builder: (_) => _SupplierSheet(supplier: supplier),
    );
    if (saved == true) ref.invalidate(suppliersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider);
    final canManage = ref.watch(clientConfigProvider)?.can('suppliers.manage') ?? false;
    final textTheme = Theme.of(context).textTheme;
    final q = _search.toLowerCase();

    return ScreenScaffold(
      title: 'Proveedores',
      subtitle: 'Quién te vende y cómo contactarlo.',
      showBack: true,
      onRefresh: () async {
        ref.invalidate(suppliersProvider);
        try {
          await ref.read(suppliersProvider.future);
        } catch (_) {}
      },
      fab: canManage
          ? AppFab(
              label: 'Nuevo proveedor',
              icon: Icons.add_rounded,
              onPressed: _edit,
            )
          : null,
      slivers: [
        PinnedBar(
          height: 66,
          child: SearchPill(
            hint: 'Buscar proveedor',
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 6)),
        suppliers.when(
          loading: () => boxSliver(const SkeletonList(count: 4, height: 90)),
          error: (error, _) => SliverToBoxAdapter(
            child: ErrorState(
              message: errorText(error),
              onRetry: () => ref.invalidate(suppliersProvider),
            ),
          ),
          data: (all) {
            final items = all
                .where((s) =>
                    q.isEmpty ||
                    s.name.toLowerCase().contains(q) ||
                    (s.contactName?.toLowerCase().contains(q) ?? false) ||
                    (s.country?.toLowerCase().contains(q) ?? false))
                .toList();
            if (items.isEmpty) {
              return SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.apartment_rounded,
                  title: 'Sin proveedores',
                  description: all.isEmpty
                      ? 'Registra a quién le compras para asociarlo a tus importaciones.'
                      : 'Ningún proveedor coincide con la búsqueda.',
                  action: all.isEmpty && canManage
                      ? AppButton(
                          label: 'Nuevo proveedor',
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
                  final s = items[index];
                  return Reveal(
                    key: ValueKey(s.id),
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        onTap: canManage ? () => _edit(s) : null,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const IconTile(Icons.apartment_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name, style: textTheme.titleSmall),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (s.country != null) s.country!,
                                      if (s.contactName != null) s.contactName!,
                                      if (s.phone != null) s.phone!,
                                    ].join(' · ').ifEmpty('Sin datos de contacto'),
                                    style: textTheme.bodySmall
                                        ?.copyWith(color: AppColors.slate500),
                                  ),
                                  if (s.email != null)
                                    Text(
                                      s.email!,
                                      style: textTheme.bodySmall
                                          ?.copyWith(color: AppColors.slate500),
                                    ),
                                ],
                              ),
                            ),
                            if (!s.isActive) const AppBadge('Inactivo'),
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

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _SupplierSheet extends ConsumerStatefulWidget {
  const _SupplierSheet({this.supplier});

  final Supplier? supplier;

  @override
  ConsumerState<_SupplierSheet> createState() => _SupplierSheetState();
}

class _SupplierSheetState extends ConsumerState<_SupplierSheet> {
  late final _name = TextEditingController(text: widget.supplier?.name);
  late final _country = TextEditingController(text: widget.supplier?.country);
  late final _contact = TextEditingController(text: widget.supplier?.contactName);
  late final _email = TextEditingController(text: widget.supplier?.email);
  late final _phone = TextEditingController(text: widget.supplier?.phone);
  late final _notes = TextEditingController(text: widget.supplier?.notes);
  late bool _isActive = widget.supplier?.isActive ?? true;
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [_name, _country, _contact, _email, _phone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nullIfBlank(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  String? get _nameError =>
      _submitted && _name.text.trim().isEmpty ? 'Ingresa el nombre del proveedor.' : null;

  String? get _emailError {
    final text = _email.text.trim();
    if (!_submitted || text.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
        ? null
        : 'Ingresa un correo válido.';
  }

  bool _validate() {
    setState(() => _submitted = true);
    return _nameError == null && _emailError == null;
  }

  Future<void> _save() async {
    final body = {
      'name': _name.text.trim(),
      'country': _nullIfBlank(_country),
      'contactName': _nullIfBlank(_contact),
      'email': _nullIfBlank(_email),
      'phone': _nullIfBlank(_phone),
      'notes': _nullIfBlank(_notes),
      'isActive': _isActive,
    };
    final api = ref.read(apiClientProvider);
    if (widget.supplier == null) {
      await api.post('/api/suppliers', body: body);
    } else {
      await api.patch('/api/suppliers/${widget.supplier!.id}', body: body);
    }
    Toast.success(widget.supplier == null ? 'Proveedor creado.' : 'Proveedor actualizado.');
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.supplier != null;
    return EntitySheet(
      title: editing ? 'Editar proveedor' : 'Nuevo proveedor',
      validate: _validate,
      onSave: _save,
      onDelete: editing
          ? () async {
              await ref.read(apiClientProvider).delete('/api/suppliers/${widget.supplier!.id}');
              Toast.success('Proveedor eliminado.');
            }
          : null,
      deleteTitle: 'Eliminar proveedor',
      deleteMessage:
          '¿Eliminar a "${widget.supplier?.name}"? Si tiene importaciones, desactívalo en su lugar.',
      child: Column(
        children: [
          AppTextField(
            label: 'Nombre',
            required: true,
            controller: _name,
            maxLength: 160,
            textCapitalization: TextCapitalization.words,
            errorText: _nameError,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'País',
            controller: _country,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Contacto',
            controller: _contact,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Correo',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            maxLength: 190,
            errorText: _emailError,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Teléfono',
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 40,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Notas',
            controller: _notes,
            maxLines: 3,
            minLines: 2,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 14),
          SwitchTile(
            title: 'Proveedor activo',
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
          ),
        ],
      ),
    );
  }
}
