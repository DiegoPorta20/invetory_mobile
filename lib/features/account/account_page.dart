import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/toast.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(_current.text, _next.text);
      Toast.success('Contraseña actualizada.');
      if (mounted) context.pop();
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
    final user = ref.watch(authControllerProvider).user;
    final textTheme = Theme.of(context).textTheme;

    return ScreenScaffold(
      title: 'Mi cuenta',
      subtitle: user == null ? null : '${user.name} · ${user.email}',
      showBack: true,
      slivers: [
        gutterSliver(
          SliverToBoxAdapter(
            child: AppCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cambiar contraseña', style: textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Usa al menos 8 caracteres.',
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Contraseña actual',
                      controller: _current,
                      obscure: true,
                      autofillHints: const [AutofillHints.password],
                      validator: (v) => v.isEmpty ? 'Ingresa tu contraseña actual.' : null,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Nueva contraseña',
                      controller: _next,
                      obscure: true,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) => v.length < 8 ? 'Mínimo 8 caracteres.' : null,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Confirmar nueva contraseña',
                      controller: _confirm,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      validator: (v) => v != _next.text ? 'Las contraseñas no coinciden.' : null,
                    ),
                    AnimatedSize(
                      duration: AppMotion.normal,
                      curve: AppMotion.ease,
                      alignment: Alignment.topCenter,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: ErrorBanner(_error!),
                            ),
                    ),
                    const SizedBox(height: 22),
                    AppButton(
                      label: 'Actualizar contraseña',
                      expand: true,
                      loading: _pending,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
