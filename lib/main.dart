import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/mkg_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MkgTaxApp()));
}

class MkgTaxApp extends StatelessWidget {
  const MkgTaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = createRouter();
    return MaterialApp.router(
      title: 'MKG Tax Consultants',
      debugShowCheckedModeBanner: false,
      theme: buildMkgTheme(),
      routerConfig: router,
    );
  }
}
