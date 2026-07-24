import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/auth_repository.dart';

/// Post-signup email verification (Sanctum): enter the code from the signup email.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late final TextEditingController _email;
  final _code = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final code = _code.text.trim();
    if (!email.contains('@')) {
      _toast('Enter a valid email address.');
      return;
    }
    if (code.length < 4) {
      _toast('Enter the verification code from your email.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).confirmEmailVerification(
            email: email,
            code: code,
          );
      if (!mounted) return;
      _toast('Email verified. You can sign in now.');
      context.go('/login');
    } on AuthException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Verify your email',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Already verified? ', style: TextStyle(color: MkgColors.textGrey)),
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
            AuthRepository.registrationVerificationMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            decoration: const InputDecoration(
              labelText: 'Verification code',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _loading || _code.text.trim().length < 4 ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Verify email'),
          ),
        ],
      ),
    );
  }
}
