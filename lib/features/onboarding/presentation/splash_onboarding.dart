import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/mkg_theme.dart';

/// Figma `splashes` / onboarding-welcome entry.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) context.go('/onboarding');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: MkgColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance, size: 72, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'MKG Tax Consultants',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text('Tax Filing', style: TextStyle(color: Colors.white70, fontSize: 15)),
          ],
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
    (Icons.verified_user_outlined, 'Secure tax filing', 'File with MKG Tax Consultants using bank-grade encryption and compliance controls.'),
    (Icons.description_outlined, 'Guided organizers', 'Complete consent forms, Schedule A deductions, and client data sheets step by step.'),
    (Icons.cloud_upload_outlined, 'Upload & track', 'Send documents and refund information to financemkgtaxpro in real time.'),
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
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: MkgColors.lightPrimary,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(p.$1, size: 56, color: MkgColors.primary),
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
