import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mkg_tax_mobile/l10n/app_localizations.dart';

import 'core/config/app_config.dart';
import 'core/localization/locale_controller.dart';
import 'core/network/api_client.dart';
import 'core/network/laravel_api_client.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_models.dart';
import 'core/sync/sync_providers.dart';
import 'core/theme/mkg_theme.dart';
import 'features/auth/data/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    AppConfig.validate();
  } on AppConfigError catch (error) {
    // A misconfigured build must fail loudly and visibly, never silently
    // talk to the wrong host — see AppConfig for why there is no default.
    runApp(ConfigErrorApp(message: error.message));
    return;
  }

  final api = await ApiClient.create();
  final laravel = LaravelApiClient.create();
  runApp(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        laravelApiClientProvider.overrideWithValue(laravel),
      ],
      child: const MkgTaxApp(),
    ),
  );
}

/// Shown instead of the real app when [AppConfig.validate] fails. Deliberately
/// minimal — this is a build-configuration error, not a runtime app state.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration error',
                  style: TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(message, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MkgTaxApp extends ConsumerStatefulWidget {
  const MkgTaxApp({super.key});

  @override
  ConsumerState<MkgTaxApp> createState() => _MkgTaxAppState();
}

class _MkgTaxAppState extends ConsumerState<MkgTaxApp> with WidgetsBindingObserver {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(authProvider.notifier).restoreSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (ref.read(authProvider).user == null) return;
    unawaited(
      ref.read(syncCoordinatorProvider).pull(reason: 'resume').catchError((_) => SyncPullResult.empty),
    );
  }

  @override
  Widget build(BuildContext context) {
    _router ??= createRouterFromRef(ref);
    final lang = ref.watch(localeControllerProvider);
    return MaterialApp.router(
      title: 'MKG Tax Consultants',
      debugShowCheckedModeBanner: false,
      theme: buildMkgTheme(),
      locale: lang.materialLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router!,
    );
  }
}
