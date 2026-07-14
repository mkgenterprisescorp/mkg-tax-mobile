import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/network/api_client.dart';
import 'core/network/laravel_api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/mkg_theme.dart';
import 'features/auth/data/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
