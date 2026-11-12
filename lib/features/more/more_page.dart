import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/client_config.dart';
import '../../core/config/server_config.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/enums.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/sheets.dart';

class _Entry {
  const _Entry(this.icon, this.label, this.description, this.path, this.module, [this.needs = const []]);
  final IconData icon;
  final String label;
  final String description;
  final String path;

  /// The module that must be usable, and any extra permissions the entry requires.
  final String module;
  final List<String> needs;

  bool visibleTo(ClientConfig config) => config.allows(module) && needs.every(config.can);
}

const _groups = <(String, List<_Entry>)>[
  (
    'Compras',
    [
      _Entry(Icons.shopping_cart_outlined, 'Reposición', 'Qué pedir y cuánto', '/reorder', 'reorder'),
      _Entry(Icons.local_shipping_outlined, 'Importaciones', 'Pedidos y recepciones', '/imports', 'imports'),
      _Entry(Icons.apartment_rounded, 'Proveedores', 'Contactos y datos', '/suppliers', 'suppliers'),
      _Entry(Icons.precision_manufacturing_outlined, 'Equipos', 'Modelos compatibles', '/equipment', 'equipment'),
    ],
  ),
  (
    'Inventario',
    [
      _Entry(Icons.upload_file_rounded, 'Importar desde Excel', 'Crear o actualizar productos', '/products/import', 'products', ['products.import', 'products.costs.view', 'products.prices.view']),
      _Entry(Icons.layers_outlined, 'Categorías', 'Clasificación en dos niveles', '/categories', 'categories'),
      _Entry(Icons.sell_outlined, 'Centros de costo', 'Líneas de negocio', '/cost-centers', 'cost-centers'),
    ],
  ),
  (
    'Administración',
    [
      _Entry(Icons.group_outlined, 'Usuarios', 'Accesos al sistema', '/users', 'users'),
      _Entry(Icons.tune_rounded, 'Configuración', 'IGV y servidor', '/settings', 'settings'),
    ],
  ),
];

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final config = ref.watch(clientConfigProvider);
    final textTheme = Theme.of(context).textTheme;
    final groups = [
      for (final (title, entries) in _groups)
        (title, [for (final entry in entries) if (config != null && entry.visibleTo(config)) entry]),
    ].where((group) => group.$2.isNotEmpty).toList();

    var index = 0;
    final sections = <Widget>[
      Reveal(
        index: index++,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: AppCard(
            onTap: () => context.push('/account'),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brand100,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initialsOf(user?.name ?? ''),
                    style: textTheme.titleMedium?.copyWith(color: AppColors.brand700),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '', style: textTheme.titleMedium),
                      Text(
                        user?.email ?? '',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                      ),
                      Text(
                        roleLabels[user?.role] ?? '',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
              ],
            ),
          ),
        ),
      ),
      for (final (title, entries) in groups)
        Reveal(
          index: index++,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    title.toUpperCase(),
                    style: textTheme.labelSmall?.copyWith(color: AppColors.slate500),
                  ),
                ),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.only(left: 70),
                            child: Divider(),
                          ),
                        _EntryRow(entry: entries[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      Reveal(
        index: index++,
        child: AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              _ActionRow(
                icon: Icons.lock_outline_rounded,
                label: 'Cambiar contraseña',
                onTap: () => context.push('/account'),
              ),
              const Padding(padding: EdgeInsets.only(left: 70), child: Divider()),
              _ActionRow(
                icon: Icons.logout_rounded,
                label: 'Cerrar sesión',
                color: AppColors.rose600,
                onTap: () async {
                  final ok = await confirmAction(
                    context,
                    title: 'Cerrar sesión',
                    message: '¿Quieres cerrar tu sesión en este dispositivo?',
                    confirmLabel: 'Cerrar sesión',
                    danger: true,
                  );
                  if (ok) await ref.read(authControllerProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Center(
          child: Text(
            '${config?.companyName ?? ''} · ${ref.watch(serverUrlProvider)}',
            style: textTheme.bodySmall?.copyWith(color: AppColors.slate400),
          ),
        ),
      ),
    ];

    return ScreenScaffold(
      title: 'Más',
      subtitle: 'Compras, catálogos y administración.',
      hasTabBar: true,
      slivers: [gutterSliver(SliverList.list(children: sections))],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Pressable(
      onTap: () => context.push(entry.path),
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brand100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(entry.icon, size: 22, color: AppColors.brand600),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.label, style: textTheme.titleSmall),
                  Text(
                    entry.description,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (color ?? AppColors.slate600).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: color ?? AppColors.slate600),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
