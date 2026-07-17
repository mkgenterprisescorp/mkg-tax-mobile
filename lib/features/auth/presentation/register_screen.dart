import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  /// Test-only override so widget tests can exercise the unavailable UI
  /// without depending on compile-time `API_BASE_URL`.
  @visibleForTesting
  static bool debugForceUnavailable = false;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _referral = TextEditingController();

  /// Testing builds that authenticate against `/api/v1` do not offer online
  /// self-registration. Keep the form disabled so Create Account cannot fire.
  bool get _registrationUnavailable =>
      RegisterScreen.debugForceUnavailable || AppConfig.usesLaravelAuth;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _referral.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_registrationUnavailable) {
      return;
    }
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      _toast('First and last name are required.');
      return;
    }
    if (!_email.text.contains('@')) {
      _toast('Enter a valid email.');
      return;
    }
    if (_phone.text.trim().length < 10) {
      _toast('Enter a valid phone number.');
      return;
    }
    if (_password.text.length < 8) {
      _toast('Password must be at least 8 characters.');
      return;
    }
    if (_password.text != _confirm.text) {
      _toast('Passwords do not match.');
      return;
    }

    final ok = await ref.read(authProvider.notifier).register(
          email: _email.text,
          password: _password.text,
          firstName: _first.text,
          lastName: _last.text,
          phone: _phone.text,
          referralCode: _referral.text,
        );
    if (!mounted) return;
    if (ok) {
      context.go('/forms');
    } else {
      _toast(ref.read(authProvider).error ?? 'Registration failed');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).loading;

    if (_registrationUnavailable) {
      return AuthScaffold(
        title: 'Create client account',
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Already have an account? ', style: TextStyle(color: MkgColors.textGrey)),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('LOG IN', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              AuthRepository.registrationUnavailableMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Return to Sign In'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Back to Login'),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: 'Create client account',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Already have an account? ', style: TextStyle(color: MkgColors.textGrey)),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('LOG IN', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: _first, decoration: const InputDecoration(labelText: 'First Name', prefixIcon: Icon(Icons.badge_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _last, decoration: const InputDecoration(labelText: 'Last Name', prefixIcon: Icon(Icons.badge_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password (min 8)', prefixIcon: Icon(Icons.lock_outline))),
          const SizedBox(height: 12),
          TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm Password', prefixIcon: Icon(Icons.lock_outline))),
          const SizedBox(height: 12),
          TextField(controller: _referral, decoration: const InputDecoration(labelText: 'Referral code (optional)', prefixIcon: Icon(Icons.card_giftcard_outlined))),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: loading ? null : _submit,
            child: loading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create Account'),
          ),
        ],
      ),
    );
  }
}

class CompleteProfileScreen extends StatelessWidget {
  const CompleteProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/forms');
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
