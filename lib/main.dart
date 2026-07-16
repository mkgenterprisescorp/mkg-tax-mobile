import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/network/laravel_api_client.dart';
import 'core/router/app_router.dart';
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

class _MkgTaxAppState extends ConsumerState<MkgTaxApp> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).restoreSession());
  }

  @override
  Widget build(BuildContext context) {
    _router ??= createRouterFromRef(ref);
    return MaterialApp.router(
      title: 'MKG Tax Consultants',
      debugShowCheckedModeBanner: false,
      theme: buildMkgTheme(),
      routerConfig: _router!,
    );
  }
}
