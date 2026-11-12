import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/json.dart';
import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import 'server_config.dart';

/// How a company wants its app to look (see config_inventory).
class Branding {
  const Branding({
    required this.appName,
    required this.tagline,
    required this.logoBytes,
    required this.palette,
  });

  final String appName;
  final String? tagline;
  final Uint8List? logoBytes;
  final BrandPalette palette;

  static const neutral = Branding(
    appName: 'Inventario',
    tagline: null,
    logoBytes: null,
    palette: BrandPalette.defaults,
  );

  /// Images travel as `data:image/png;base64,...`; anything unreadable just means "no logo".
  static Uint8List? _decodeImage(Object? value) {
    if (value is! String) return null;
    final comma = value.indexOf(',');
    if (!value.startsWith('data:image/') || comma < 0) return null;
    try {
      return base64Decode(value.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  factory Branding.fromJson(Object? json) {
    final map = asMap(json);
    return Branding(
      appName: asString(map['appName'], 'Inventario'),
      tagline: asStringOrNull(map['tagline']),
      logoBytes: _decodeImage(map['logoUrl']),
      palette: BrandPalette.fromJson(map['palette']),
    );
  }
}

/// What the server says the signed-in user may see and do in their company.
class ClientConfig {
  const ClientConfig({
    required this.companySlug,
    required this.companyName,
    required this.branding,
    required this.role,
    required this.allowedModules,
    required this.permissions,
    required this.raw,
  });

  final String companySlug;
  final String companyName;
  final Branding branding;
  final String role;
  final Set<String> allowedModules;
  final Set<String> permissions;

  /// The unparsed response, kept so it can be cached and read back.
  final Map<String, dynamic> raw;

  bool can(String permission) => permissions.contains(permission);
  bool allows(String module) => allowedModules.contains(module);
  bool get canSeeCosts => can('products.costs.view');
  bool get canSeePrices => can('products.prices.view');
  bool get isAdmin => role == 'ADMIN';

  factory ClientConfig.fromJson(Map<String, dynamic> json) {
    final company = asMap(json['company']);
    return ClientConfig(
      companySlug: asString(company['slug']),
      companyName: asString(company['name']),
      branding: Branding.fromJson(json['branding']),
      role: asString(json['role'], 'PERSONAL'),
      allowedModules: {...(json['allowedModules'] as List? ?? const []).map((e) => '$e')},
      permissions: {...(json['permissions'] as List? ?? const []).map((e) => '$e')},
      raw: json,
    );
  }
}

const _configKey = 'client_config';
const _companyKey = 'company_slug';

/// Bumped whenever the active palette changes so the whole app repaints with the new colors.
final brandVersionProvider = NotifierProvider<_BrandVersion, int>(_BrandVersion.new);

class _BrandVersion extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// The branding currently shown (company-specific once known, neutral otherwise).
final brandingProvider = NotifierProvider<BrandingController, Branding>(BrandingController.new);

class BrandingController extends Notifier<Branding> {
  /// Set in `main()` from the cache so the first frame already wears the company's colors.
  static Branding initial = Branding.neutral;

  @override
  Branding build() => initial;

  /// Applies the palette and repaints the app when it differs from the one in use.
  void apply(Branding branding) {
    final changed = !_samePalette(state.palette, branding.palette);
    AppColors.applyPalette(branding.palette);
    state = branding;
    if (changed) ref.read(brandVersionProvider.notifier).bump();
  }

  bool _samePalette(BrandPalette a, BrandPalette b) =>
      a.primary[600] == b.primary[600] &&
      a.primary[900] == b.primary[900] &&
      a.accent[500] == b.accent[500];

  void reset() => apply(Branding.neutral);
}

final clientConfigProvider =
    NotifierProvider<ClientConfigController, ClientConfig?>(ClientConfigController.new);

class ClientConfigController extends Notifier<ClientConfig?> {
  @override
  ClientConfig? build() => null;

  /// The company code the user last signed in with.
  String? get lastCompany => ref.read(sharedPreferencesProvider).getString(_companyKey);

  void rememberCompany(String slug) =>
      ref.read(sharedPreferencesProvider).setString(_companyKey, slug.trim().toLowerCase());

  /// Stores a response from `/api/config` and paints the company's brand.
  void accept(Map<String, dynamic> json) {
    final config = ClientConfig.fromJson(json);
    ref.read(sharedPreferencesProvider)
      ..setString(_configKey, jsonEncode(json))
      ..setString(_companyKey, config.companySlug);
    state = config;
    ref.read(brandingProvider.notifier).apply(config.branding);
  }

  /// Offline start: the last known configuration is better than showing nothing.
  bool restoreCached() {
    final raw = ref.read(sharedPreferencesProvider).getString(_configKey);
    if (raw == null) return false;
    try {
      final config = ClientConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      state = config;
      ref.read(brandingProvider.notifier).apply(config.branding);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Signing out keeps the company code and its colors for the next sign-in.
  void clear() {
    ref.read(sharedPreferencesProvider).remove(_configKey);
    state = null;
  }

  /// Colors cached for a company so the sign-in screen can paint them before anyone signs in.
  Branding? cachedBranding(String slug) {
    final raw = ref.read(sharedPreferencesProvider).getString('branding_$slug');
    if (raw == null) return null;
    try {
      return Branding.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  void cacheBranding(String slug, Map<String, dynamic> branding) =>
      ref.read(sharedPreferencesProvider).setString('branding_$slug', jsonEncode(branding));
}

/// Convenience reads for widgets: `ref.watch(canProvider('products.create'))`.
final canProvider = Provider.family<bool, String>(
  (ref, permission) => ref.watch(clientConfigProvider)?.can(permission) ?? false,
);

final canSeeCostsProvider = Provider<bool>(
  (ref) => ref.watch(clientConfigProvider)?.canSeeCosts ?? false,
);

final canSeePricesProvider = Provider<bool>(
  (ref) => ref.watch(clientConfigProvider)?.canSeePrices ?? false,
);

final allowsModuleProvider = Provider.family<bool, String>(
  (ref, module) => ref.watch(clientConfigProvider)?.allows(module) ?? false,
);

/// Shows [child] only when the user holds every listed permission.
class Can extends ConsumerWidget {
  const Can(this.permissions, {super.key, required this.child, this.otherwise});

  /// One permission code or a list; all of them are required.
  final Object permissions;
  final Widget child;
  final Widget? otherwise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needed = permissions is List ? List<String>.from(permissions as List) : ['$permissions'];
    final config = ref.watch(clientConfigProvider);
    final allowed = config != null && needed.every(config.can);
    return allowed ? child : (otherwise ?? const SizedBox.shrink());
  }
}

/// Public branding fetched before sign-in; null when the company does not exist.
class CompanyLookup {
  const CompanyLookup(this.slug, this.name, this.branding);

  final String slug;
  final String name;
  final Branding branding;
}

CompanyLookup parseCompanyLookup(Object? json) {
  final map = asMap(json);
  return CompanyLookup(
    asString(map['slug']),
    asString(map['name']),
    Branding.fromJson(map['branding']),
  );
}

bool isNotFound(Object error) => error is ApiException && error.statusCode == 404;