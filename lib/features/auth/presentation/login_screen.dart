import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _remember = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }
    if (password.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your password.')),
      );
      return;
    }
    final ok = await ref.read(authProvider.notifier).login(email, password);
    if (!mounted) return;
    if (ok) {
      context.go('/forms');
    } else {
      final err = ref.read(authProvider).error ?? 'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return AuthScaffold(
      title: AppConfig.usesLaravelAuth
          ? 'Sign in via Laravel API'
          : 'Sign in to ${Uri.parse(AppConfig.webRoot).host}',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Don't have an account? ", style: TextStyle(color: MkgColors.textGrey)),
          TextButton(
            onPressed: () => context.go('/register'),
            child: const Text('SIGN UP', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _remember,
                onChanged: (v) => setState(() => _remember = v ?? true),
              ),
              const Text('Remember me'),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: const Text('Forgot Password?'),
              ),
            ],
          ),
          FilledButton(
            onPressed: auth.loading ? null : _submit,
            child: auth.loading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Log In'),
          ),
          const SizedBox(height: 12),
          Text(
            AppConfig.usesLaravelAuth
                ? 'Authoritative auth via Laravel Sanctum at ${AppConfig.apiRoot}. Neon is never contacted from the app.'
                : 'Transitional cookie login against ${AppConfig.apiRoot}. Production builds use https://api.financemkgtax.com/api/v1.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: MkgColors.textGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
