import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 4) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    // Demo session only — Laravel Sanctum will own auth in a later PR.
    context.go('/forms');
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Sign in to your account',
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
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: MkgColors.red)),
            const SizedBox(height: 8),
          ],
          FilledButton(onPressed: _submit, child: const Text('Log In')),
          const SizedBox(height: 12),
          const Text(
            'Demo UI — tap Log In to explore the app. Production auth will use Laravel Sanctum/MFA.',
            textAlign: TextAlign.center,
            style: TextStyle(color: MkgColors.textGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
