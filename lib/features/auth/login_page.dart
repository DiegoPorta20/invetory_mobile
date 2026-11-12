import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/client_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/states.dart';
import 'server_sheet.dart';

enum _CompanyState { idle, checking, found, missing }

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  Timer? _debounce;
  bool _pending = false;
  String? _error;
  _CompanyState _companyState = _CompanyState.idle;
  String _companyName = '';

  /// Only the header previews a company's colors here; repainting the whole app would throw
  /// away what the user is typing. The full theme applies once they are signed in.
  Branding _preview = Branding.neutral;

  @override
  void initState() {
    super.initState();
    final config = ref.read(clientConfigProvider.notifier);
    final last = config.lastCompany;
    _preview = ref.read(brandingProvider);
    if (last != null) {
      _company.text = last;
      final cached = config.cachedBranding(last);
      if (cached != null) _preview = cached;
      _lookup();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _company.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _onCompanyChanged(String _) {
    _debounce?.cancel();
    setState(() => _companyState = _CompanyState.idle);
    _debounce = Timer(const Duration(milliseconds: 500), _lookup);
  }

  Future<void> _lookup() async {
    final code = _company.text.trim();
    if (code.length < 3) return;
    setState(() => _companyState = _CompanyState.checking);
    final result = await ref.read(authControllerProvider.notifier).lookupCompany(code);
    if (!mounted || code != _company.text.trim()) return;
    setState(() {
      if (result == null) {
        _companyState = _CompanyState.missing;
      } else {
        _companyState = _CompanyState.found;
        _companyName = result.name;
        _preview = result.branding;
      }
    });
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
          .login(_company.text, _email.text.trim(), _password.text);
      // The router redirects to the first available screen once the session is authenticated.
    } catch (error) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _pending = false;
        _error = errorText(error, 'No se pudo iniciar sesión.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hero(top: top, branding: _preview),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Reveal(
                      index: 3,
                      child: Text('Iniciar sesión', style: textTheme.headlineSmall),
                    ),
                    const SizedBox(height: 4),
                    Reveal(
                      index: 4,
                      child: Text(
                        'Ingresa con tu cuenta para continuar.',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
                      ),
                    ),
                    AnimatedSize(
                      duration: AppMotion.normal,
                      curve: AppMotion.ease,
                      alignment: Alignment.topCenter,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: ErrorBanner(_error!),
                            ),
                    ),
                    const SizedBox(height: 22),
                    Reveal(
                      index: 5,
                      child: AppTextField(
                        label: 'Código de la empresa',
                        controller: _company,
                        textInputAction: TextInputAction.next,
                        onChanged: _onCompanyChanged,
                        helper: switch (_companyState) {
                          _CompanyState.checking => 'Buscando empresa…',
                          _CompanyState.found => _companyName,
                          _ => 'El código que te dio tu proveedor, por ejemplo «mi-empresa».',
                        },
                        errorText: _companyState == _CompanyState.missing
                            ? 'No encontramos esa empresa. Revisa el código.'
                            : null,
                        validator: (value) =>
                            RegExp(r'^[A-Za-z0-9-]{3,60}$').hasMatch(value.trim())
                                ? null
                                : 'Ingresa el código de tu empresa.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Reveal(
                      index: 6,
                      child: AppTextField(
                        label: 'Correo electrónico',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        validator: (value) =>
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
                                ? null
                                : 'Ingresa un correo válido.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Reveal(
                      index: 7,
                      child: AppTextField(
                        label: 'Contraseña',
                        controller: _password,
                        obscure: true,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        validator: (value) => value.isEmpty ? 'Ingresa tu contraseña.' : null,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Reveal(
                      index: 8,
                      child: AppButton(
                        label: _pending ? 'Ingresando…' : 'Ingresar',
                        expand: true,
                        loading: _pending,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.top, required this.branding});

  final double top;
  final Branding branding;

  Color _shade(int shade) =>
      branding.palette.primary[shade] ?? BrandPalette.defaults.primary[shade]!;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final logo = branding.logoBytes;
    return Container(
      padding: EdgeInsets.fromLTRB(24, top + 18, 24, 34),
      decoration: BoxDecoration(
        color: _shade(900),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              right: -70,
              bottom: -90,
              child: _Orb(size: 220, color: _shade(700).withValues(alpha: 0.5)),
            ),
            Positioned(
              right: 40,
              top: -50,
              child: _Orb(size: 130, color: _shade(800).withValues(alpha: 0.8)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Reveal(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: _shade(100),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: logo != null
                            ? Image.memory(logo, fit: BoxFit.contain)
                            : Icon(Icons.inventory_2_rounded, color: _shade(900), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          branding.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge?.copyWith(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Servidor',
                        onPressed: () => showServerSheet(context),
                        icon: Icon(Icons.settings_ethernet_rounded, color: _shade(200)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 44),
                Reveal(
                  index: 1,
                  child: Text(
                    'Sabe qué tienes, qué falta y qué pedir.',
                    style: textTheme.headlineMedium?.copyWith(color: Colors.white, height: 1.12),
                  ),
                ),
                const SizedBox(height: 12),
                Reveal(
                  index: 2,
                  child: Text(
                    'Repuestos, importaciones, movimientos y reposición en un solo lugar.',
                    style: textTheme.bodyLarge?.copyWith(color: _shade(200)),
                  ),
                ),
                if (branding.tagline != null) ...[
                  const SizedBox(height: 22),
                  Reveal(
                    index: 3,
                    child: Text(
                      branding.tagline!,
                      style: textTheme.bodySmall?.copyWith(color: _shade(300)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: AppMotion.ease,
      builder: (context, scale, _) => Transform.scale(
        scale: scale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}