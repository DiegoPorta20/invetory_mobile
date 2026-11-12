import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_page.dart';
import '../../features/admin/categories_page.dart';
import '../../features/admin/cost_centers_page.dart';
import '../../features/admin/equipment_page.dart';
import '../../features/admin/settings_page.dart';
import '../../features/admin/suppliers_page.dart';
import '../../features/admin/users_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/splash_page.dart';
import '../../features/counts/count_detail_page.dart';
import '../../features/counts/counts_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/imports/import_detail_page.dart';
import '../../features/imports/import_form_page.dart';
import '../../features/imports/imports_page.dart';
import '../../features/imports/imports_repository.dart';
import '../../features/more/more_page.dart';
import '../../features/movements/movements_page.dart';
import '../../features/products/product_detail_page.dart';
import '../../features/products/product_form_page.dart';
import '../../features/products/product_import_page.dart';
import '../../features/products/products_page.dart';
import '../../features/reorder/reorder_page.dart';
import '../auth/auth_controller.dart';
import '../config/client_config.dart';
import '../theme/app_motion.dart';
import 'app_shell.dart';
import 'module_access.dart';
import 'navigator_keys.dart';

enum _Motion { slide, rise }

/// Pushed pages slide in from the right (or rise from below for create forms) while the page
/// underneath eases back. iOS keeps the native page so the edge-swipe back gesture works.
Page<void> _page(GoRouterState state, Widget child, {_Motion motion = _Motion.slide}) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return CupertinoPage<void>(key: state.pageKey, child: child);
  }
  final begin = motion == _Motion.slide ? const Offset(0.12, 0) : const Offset(0, 0.08);
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final incoming = CurvedAnimation(
        parent: animation,
        curve: AppMotion.ease,
        reverseCurve: Curves.easeInCubic,
      );
      final outgoing = CurvedAnimation(parent: secondaryAnimation, curve: AppMotion.ease);
      return SlideTransition(
        position: Tween<Offset>(begin: Offset.zero, end: const Offset(-0.05, 0))
            .animate(outgoing),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.82).animate(outgoing),
          child: SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero).animate(incoming),
            child: FadeTransition(opacity: incoming, child: child),
          ),
        ),
      );
    },
  );
}

Page<void> _tab(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

int _id(GoRouterState state) => int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.listen(clientConfigProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  GoRoute pushed(String path, Widget Function(GoRouterState state) build, {_Motion motion = _Motion.slide}) {
    return GoRoute(
      path: path,
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _page(state, build(state), motion: motion),
    );
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/more',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final location = state.matchedLocation;
      switch (status) {
        case AuthStatus.unknown:
          return location == '/splash' ? null : '/splash';
        case AuthStatus.unauthenticated:
          return location == '/login' ? null : '/login';
        case AuthStatus.authenticated:
          final config = ref.read(clientConfigProvider);
          if (location == '/login' || location == '/splash') return homeLocation(config);
          final module = moduleForLocation(location);
          if (module != null && config != null && !config.allows(module)) {
            return homeLocation(config);
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => _tab(state, const SplashPage()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const LoginPage(),
          transitionDuration: const Duration(milliseconds: 450),
          transitionsBuilder: (context, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: AppMotion.ease),
            child: child,
          ),
        ),
      ),
      StatefulShellRoute(
        builder: (context, state, navigationShell) => navigationShell,
        navigatorContainerBuilder: (context, navigationShell, children) =>
            AppShell(navigationShell: navigationShell, children: children),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              pageBuilder: (context, state) => _tab(state, const DashboardPage()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/products',
              pageBuilder: (context, state) => _tab(
                state,
                ProductsPage(
                  query: state.uri.queryParameters,
                  queryKey: state.uri.query,
                ),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/movements',
              pageBuilder: (context, state) => _tab(state, const MovementsPage()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/counts',
              pageBuilder: (context, state) => _tab(state, const CountsPage()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/more',
              pageBuilder: (context, state) => _tab(state, const MorePage()),
            ),
          ]),
        ],
      ),
      pushed('/products/new', (_) => const ProductFormPage(), motion: _Motion.rise),
      pushed('/products/import', (_) => const ProductImportPage(), motion: _Motion.rise),
      pushed('/products/:id', (s) => ProductDetailPage(id: _id(s))),
      pushed('/products/:id/edit', (s) => ProductFormPage(id: _id(s))),
      pushed(
        '/history',
        (s) => MovementsPage(
          query: s.uri.queryParameters,
          queryKey: s.uri.query,
          showBack: true,
        ),
      ),
      pushed('/counts/:id', (s) => CountDetailPage(id: _id(s))),
      pushed('/reorder', (_) => const ReorderPage()),
      pushed('/imports', (_) => const ImportsPage()),
      pushed(
        '/imports/new',
        (s) => ImportFormPage(prefill: s.extra is ImportPrefill ? s.extra as ImportPrefill : null),
        motion: _Motion.rise,
      ),
      pushed('/imports/:id', (s) => ImportDetailPage(id: _id(s))),
      pushed('/imports/:id/edit', (s) => ImportFormPage(id: _id(s))),
      pushed('/suppliers', (_) => const SuppliersPage()),
      pushed('/equipment', (_) => const EquipmentPage()),
      pushed('/categories', (_) => const CategoriesPage()),
      pushed('/cost-centers', (_) => const CostCentersPage()),
      pushed('/users', (_) => const UsersPage()),
      pushed('/settings', (_) => const SettingsPage()),
      pushed('/account', (_) => const AccountPage()),
    ],
  );
});
