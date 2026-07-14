import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../auth/data/auth_repository.dart';

/// Dual-brand splash: MKG Tax Consultants + Finance Advisors.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1100), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (auth.loading) {
      Future<void>.delayed(const Duration(milliseconds: 400), _navigate);
      return;
    }
    if (auth.isAuthenticated) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: MkgColors.primary,
      body: Center(
        child: DualBrandHeader(
          compact: false,
          subtitle: 'Tax · Advisory · Planning',
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    (
      Icons.verified_user_outlined,
      'MKG Tax Consultants',
      'Secure tax filing, organizers, and document vaults with bank-grade compliance controls.',
    ),
    (
      Icons.account_balance_outlined,
      'Finance Advisors',
      'Financial planning, lending guidance, and advisory tools sit alongside your tax workspace.',
    ),
    (
      Icons.forum_outlined,
      'Advisor Chat',
      'Ask TESSA AI or reach your MKG advisor for scheduling, document requests, and next steps.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 200,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: MkgColors.lightPrimary),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: i == 0
                              ? Image.asset('assets/brand/mkg_tax_logo.png', fit: BoxFit.contain)
                              : Icon(p.$1, size: 56, color: MkgColors.primary),
                        ),
                        const SizedBox(height: 28),
                        Text(p.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Text(p.$3, textAlign: TextAlign.center, style: const TextStyle(color: MkgColors.textGrey, fontSize: 15, height: 1.45)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _index;
                return Container(
                  width: active ? 18 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? MkgColors.primary : MkgColors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: FilledButton(
                onPressed: () {
                  if (_index < _pages.length - 1) {
                    _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
                  } else {
                    context.go('/login');
                  }
                },
                child: Text(_index < _pages.length - 1 ? 'NEXT' : 'GET STARTED'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
