import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/server_config.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/toast.dart';

Future<void> showServerSheet(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const _ServerSheet());

class _ServerSheet extends ConsumerStatefulWidget {
  const _ServerSheet();

  @override
  ConsumerState<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends ConsumerState<_ServerSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(serverUrlProvider));
  bool _testing = false;
  bool? _reachable;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    if (!isValidServerUrl(_controller.text)) {
      setState(() => _error = 'Ingresa una dirección válida, por ejemplo http://192.168.1.2:3000');
      return;
    }
    setState(() {
      _testing = true;
      _reachable = null;
      _error = null;
    });
    final base = normalizeServerUrl(_controller.text);
    var ok = false;
    try {
      final response = await http
          .get(Uri.parse('$base/api/health'))
          .timeout(const Duration(seconds: 7));
      ok = response.statusCode == 200;
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _reachable = ok;
    });
  }

  Future<void> _save() async {
    if (!isValidServerUrl(_controller.text)) {
      setState(() => _error = 'Ingresa una dirección válida, por ejemplo http://192.168.1.2:3000');
      return;
    }
    await ref.read(serverUrlProvider.notifier).update(_controller.text);
    if (!mounted) return;
    Navigator.of(context).pop();
    Toast.success('Servidor actualizado.');
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Servidor',
      subtitle: 'Dirección de la API del inventario.',
      footer: SheetActions(primaryLabel: 'Guardar', onPrimary: _save),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: 'URL del servidor',
            controller: _controller,
            hint: 'http://192.168.1.2:3000',
            keyboardType: TextInputType.url,
            errorText: _error,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {
              _error = null;
              _reachable = null;
            }),
            helper:
                'En el emulador de Android usa http://10.0.2.2:3000. En un teléfono físico usa la IP de tu computadora en la red.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              AppButton(
                label: 'Probar conexión',
                icon: Icons.wifi_tethering_rounded,
                variant: ButtonVariant.secondary,
                small: true,
                loading: _testing,
                onPressed: _test,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: switch (_reachable) {
                    true => const Row(
                        key: ValueKey('ok'),
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 19, color: AppColors.emerald500),
                          SizedBox(width: 6),
                          Text('Conectado'),
                        ],
                      ),
                    false => const Row(
                        key: ValueKey('fail'),
                        children: [
                          Icon(Icons.error_rounded,
                              size: 19, color: AppColors.rose500),
                          SizedBox(width: 6),
                          Flexible(child: Text('Sin respuesta')),
                        ],
                      ),
                    null => const SizedBox(key: ValueKey('none')),
                  },
                ),
              ),
            ],
          ),
          if (_reachable == false) ...[
            const SizedBox(height: 12),
            const InfoBanner(
              'Verifica que el API esté en marcha y que el teléfono y la computadora estén en la misma red.',
            ),
          ],
        ],
      ),
    );
  }
}
