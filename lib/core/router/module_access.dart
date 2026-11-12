import '../config/client_config.dart';

/// The module (as named by config_inventory) that governs a route, or null for routes anyone
/// signed in may open.
String? moduleForLocation(String location) {
  final path = Uri.parse(location).path;
  const exact = {
    '/dashboard': 'dashboard',
    '/movements': 'movements',
    '/history': 'movements',
    '/counts': 'counts',
    '/reorder': 'reorder',
    '/imports': 'imports',
    '/suppliers': 'suppliers',
    '/equipment': 'equipment',
    '/categories': 'categories',
    '/cost-centers': 'cost-centers',
    '/users': 'users',
    '/settings': 'settings',
  };
  if (exact.containsKey(path)) return exact[path];
  if (path.startsWith('/products')) return 'products';
  if (path.startsWith('/counts/')) return 'counts';
  if (path.startsWith('/imports/')) return 'imports';
  return null;
}

/// Bottom-bar destinations in order, with the module that shows each one.
const tabDestinations = <(String path, String module)>[
  ('/dashboard', 'dashboard'),
  ('/products', 'products'),
  ('/movements', 'movements'),
  ('/counts', 'counts'),
];

/// Where to land after signing in: the first tab the user can open, else the "More" menu.
String homeLocation(ClientConfig? config) {
  for (final (path, module) in tabDestinations) {
    if (config?.allows(module) ?? false) return path;
  }
  return '/more';
}