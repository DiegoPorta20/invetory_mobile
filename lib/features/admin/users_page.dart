import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/format/formatters.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/toast.dart';
import 'entity_sheet.dart';

final usersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final json = await ref.watch(apiClientProvider).get('/api/users');
  return (json as List).whereType<Map<String, dynamic>>().map(AppUser.fromJson).toList();
});

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [AppUser? user]) async {
    final saved = await showAppSheet<bool>(
      context,
      builder: (_) => _UserSheet(user: user),
    );
    if (saved == true) ref.invalidate(usersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider);
    final me = ref.watch(authControllerProvider).user;
    final textTheme = Theme.of(context).textTheme;

    return ScreenScaffold(
      title: 'Usuarios',
      subtitle: 'Quién puede entrar al sistema.',
      showBack: true,
      onRefresh: () async {
        ref.invalidate(usersProvider);
        try {
          await ref.read(usersProvider.future);
        } catch (_) {}
      },
      fab: AppFab(
        label: 'Nuevo usuario',
        icon: Icons.person_add_alt_1_rounded,
        onPressed: () => _edit(context, ref),
      ),
      slivers: [
        users.when(
          loading: () => boxSliver(const SkeletonList(count: 4, height: 84)),
          error: (error, _) => SliverToBoxAdapter(
            child: ErrorState(
              message: errorText(error),
              onRetry: () => ref.invalidate(usersProvider),
            ),
          ),
          data: (items) => gutterSliver(
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final u = items[index];
                return Reveal(
                  key: ValueKey(u.id),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      onTap: () => _edit(context, ref, u),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.brand100,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              initialsOf(u.name),
                              style: textTheme.titleSmall?.copyWith(color: AppColors.brand700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.id == me?.id ? '${u.name} (tú)' : u.name,
                                  style: textTheme.titleSmall,
                                ),
                                Text(
                                  u.email,
                                  style: textTheme.bodySmall
                                      ?.copyWith(color: AppColors.slate500),
                                ),
                                Text(
                                  u.lastLoginAt == null
                                      ? 'Aún no ha ingresado'
                                      : 'Último acceso ${formatDateTime(u.lastLoginAt)}',
                                  style: textTheme.bodySmall
                                      ?.copyWith(color: AppColors.slate400),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AppBadge(roleLabels[u.role] ?? u.role, tone: Tone.brand),
                              if (!u.isActive) ...[
                                const SizedBox(height: 4),
                                const AppBadge('Inactivo'),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _UserSheet extends ConsumerStatefulWidget {
  const _UserSheet({this.user});

  final AppUser? user;

  @override
  ConsumerState<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends ConsumerState<_UserSheet> {
  late final _name = TextEditingController(text: widget.user?.name);
  late final _email = TextEditingController(text: widget.user?.email);
  final _password = TextEditingController();
  late bool _isActive = widget.user?.isActive ?? true;
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _editing => widget.user != null;

  String? get _nameError =>
      _submitted && _name.text.trim().isEmpty ? 'Ingresa el nombre.' : null;

  String? get _emailError {
    if (_editing || !_submitted) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())
        ? null
        : 'Ingresa un correo válido.';
  }

  String? get _passwordError {
    if (!_submitted) return null;
    final length = _password.text.length;
    if (_editing && length == 0) return null;
    return length >= 8 ? null : 'Mínimo 8 caracteres.';
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).user;
    final isSelf = widget.user?.id == me?.id;

    return EntitySheet(
      title: _editing ? 'Editar usuario' : 'Nuevo usuario',
      subtitle: _editing ? widget.user!.email : null,
      validate: () {
        setState(() => _submitted = true);
        return _nameError == null && _emailError == null && _passwordError == null;
      },
      onSave: () async {
        final api = ref.read(apiClientProvider);
        if (_editing) {
          await api.patch('/api/users/${widget.user!.id}', body: {
            'name': _name.text.trim(),
            if (!isSelf) 'isActive': _isActive,
            if (_password.text.isNotEmpty) 'password': _password.text,
          });
        } else {
          await api.post('/api/users', body: {
            'email': _email.text.trim(),
            'name': _name.text.trim(),
            'password': _password.text,
            'role': 'ADMIN',
          });
        }
        Toast.success(_editing ? 'Usuario actualizado.' : 'Usuario creado.');
      },
      child: Column(
        children: [
          AppTextField(
            label: 'Nombre',
            required: true,
            controller: _name,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            errorText: _nameError,
            onChanged: (_) => setState(() {}),
          ),
          if (!_editing) ...[
            const SizedBox(height: 14),
            AppTextField(
              label: 'Correo electrónico',
              required: true,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              maxLength: 190,
              errorText: _emailError,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 14),
          AppTextField(
            label: _editing ? 'Nueva contraseña' : 'Contraseña',
            required: !_editing,
            controller: _password,
            obscure: true,
            errorText: _passwordError,
            helper: _editing ? 'Déjala vacía para no cambiarla.' : 'Mínimo 8 caracteres.',
            onChanged: (_) => setState(() {}),
          ),
          if (_editing && !isSelf) ...[
            const SizedBox(height: 14),
            SwitchTile(
              title: 'Usuario activo',
              subtitle: 'Un usuario inactivo no puede iniciar sesión.',
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
          ],
          if (_editing && isSelf) ...[
            const SizedBox(height: 14),
            const InfoBanner('No puedes desactivarte ni cambiar tu propio rol.'),
          ],
        ],
      ),
    );
  }
}
