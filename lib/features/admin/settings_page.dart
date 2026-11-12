import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/server_config.dart';
import '../../core/data/data_revision.dart';
import '../../core/data/reference_data.dart';
import '../../core/format/formatters.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/toast.dart';
import '../auth/server_sheet.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _rate = TextEditingController();
  bool _loaded = false;
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  double? get _rateValue {
    final value = double.tryParse(_rate.text.trim().replaceAll(',', '.'));
    return value != null && value >= 0 && value <= 100 ? value : null;
  }

  Future<void> _save() async {
    final percent = _rateValue;
    if (percent == null) {
      setState(() => _error = 'Ingresa un porcentaje entre 0 y 100.');
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .put('/api/settings/pricing', body: {'igvRate': percent / 100});
      ref.invalidate(igvRateProvider);
      ref.read(dataRevisionProvider.notifier).bump();
      Toast.success('IGV actualizado. Los precios con IGV se recalcularon.');
    } catch (error) {
      if (mounted) setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final igv = ref.watch(igvRateProvider);
    final server = ref.watch(serverUrlProvider);
    final textTheme = Theme.of(context).textTheme;

    if (!_loaded && igv.hasValue) {
      _loaded = true;
      final percent = igv.value! * 100;
      _rate.text = percent == percent.roundToDouble()
          ? percent.toStringAsFixed(0)
          : percent.toString();
    }

    return ScreenScaffold(
      title: 'Configuración',
      subtitle: 'Parámetros del sistema.',
      showBack: true,
      slivers: [
        gutterSliver(
          SliverList.list(
            children: [
              Reveal(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Precios', style: textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Todos los montos están en soles. El precio base se guarda sin IGV y el precio con IGV se calcula con esta tasa.',
                          style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
                        ),
                        const SizedBox(height: 18),
                        if (igv.isLoading && !igv.hasValue)
                          const Skeleton(height: 52, radius: 12)
                        else
                          AppTextField(
                            label: 'IGV (%)',
                            controller: _rate,
                            keyboardType: numberKeyboard(decimal: true),
                            inputFormatters: numberFormatters(decimal: true),
                            textInputAction: TextInputAction.done,
                            errorText: _error,
                            helper: _rateValue == null
                                ? null
                                : 'Un precio de ${formatPen(100)} sin IGV pasa a ${formatPen(100 * (1 + _rateValue! / 100))} con IGV.',
                            onChanged: (_) => setState(() => _error = null),
                          ),
                        const SizedBox(height: 18),
                        AppButton(
                          label: 'Guardar',
                          loading: _pending,
                          expand: true,
                          onPressed: igv.hasValue ? _save : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Reveal(
                index: 1,
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Servidor', style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        server,
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.slate600),
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: 'Cambiar servidor',
                        icon: Icons.settings_ethernet_rounded,
                        variant: ButtonVariant.secondary,
                        expand: true,
                        onPressed: () => showServerSheet(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
