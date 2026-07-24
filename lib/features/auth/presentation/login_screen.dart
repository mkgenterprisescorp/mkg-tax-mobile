import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final _otp = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  bool _awaitingOtp = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _otp.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      _toast('Enter a valid email address.');
      return;
    }
    if (password.length < 4) {
      _toast('Enter your password.');
      return;
    }
    if (_awaitingOtp && _otp.text.trim().length != 6) {
      _toast('Enter the 6-digit verification code.');
      return;
    }

    final ok = await ref.read(authProvider.notifier).login(
          email,
          password,
          otp: _awaitingOtp ? _otp.text.trim() : null,
        );
    if (!mounted) return;

    final auth = ref.read(authProvider);
    if (ok) {
      context.go('/home');
      return;
    }
    if (auth.requiresOtp) {
      final wasAwaiting = _awaitingOtp;
      setState(() => _awaitingOtp = true);
      if (!wasAwaiting) {
        _toast(auth.error ?? 'Enter the verification code sent to your email.');
      } else if (auth.error != null) {
        _toast(auth.error!);
      }
      return;
    }
    _toast(
      auth.error ??
          'We’re unable to sign you in right now. Please try again later.',
    );
  }

  Future<void> _resendOtp() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || password.length < 4) return;
    setState(() => _resending = true);
    try {
      await ref.read(authProvider.notifier).login(email, password);
      if (!mounted) return;
      final auth = ref.read(authProvider);
      if (auth.requiresOtp) {
        setState(() => _awaitingOtp = true);
        _toast('A new verification code was sent to your email.');
      } else if (auth.error != null) {
        _toast(auth.error!);
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _backToPassword() {
    setState(() {
      _awaitingOtp = false;
      _otp.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final showOtp = _awaitingOtp || auth.requiresOtp;

    return AuthScaffold(
      title: showOtp ? 'Enter verification code' : 'Secure Client Sign In',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showOtp)
            TextButton(
              onPressed: auth.loading ? null : _backToPassword,
              child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          else ...[
            const Text("Don't have an account? ", style: TextStyle(color: MkgColors.textGrey)),
            TextButton(
              onPressed: () => context.go('/register'),
              child: const Text('SIGN UP', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!showOtp) ...[
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
          ] else ...[
            Text(
              'Use the same password as mkgtaxconsultants.com. We emailed a 6-digit code to ${_email.text.trim()}.',
              style: const TextStyle(color: MkgColors.textGrey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Verification code',
                prefixIcon: Icon(Icons.pin_outlined),
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: (auth.loading || _resending) ? null : _resendOtp,
                child: _resending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Resend code'),
              ),
            ),
          ],
          FilledButton(
            onPressed: auth.loading ? null : _submit,
            child: auth.loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(showOtp ? 'Verify & Log In' : 'Log In'),
          ),
        ],
      ),
    );
  }
}
