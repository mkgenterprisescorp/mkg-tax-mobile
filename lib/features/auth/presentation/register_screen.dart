import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

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
          const SizedBox(height: 10),
          const Text(
            'Creates your account on financemkgtaxpro via POST /api/register.',
            textAlign: TextAlign.center,
            style: TextStyle(color: MkgColors.textGrey, fontSize: 12),
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
    // Registration now collects profile fields directly against the web API.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/forms');
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.post('/api/forgot-password', data: {'email': _email.text.trim()});
      if (!mounted) return;
      if ((res.statusCode ?? 500) >= 400) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((res.data is Map ? res.data['message'] : null) ?? 'Reset request failed')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('If that email exists, a reset code was sent.')),
        );
        context.go('/login');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Forgot password',
      footer: TextButton(onPressed: () => context.go('/login'), child: const Text('Back to login')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'We will email a reset code using the same financemkgtaxpro endpoint as the web portal.',
            style: TextStyle(color: MkgColors.textGrey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
