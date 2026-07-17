import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/auth_repository.dart';

/// Web-parity password reset: email → 6-digit code → new password.
/// Mirrors financemkgtaxpro `Login.tsx` forgot / reset-code / new-password steps.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _ResetStep { email, code, newPassword }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  _ResetStep _step = _ResetStep.email;
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String get _title => switch (_step) {
        _ResetStep.email => 'Forgot password',
        _ResetStep.code => 'Enter reset code',
        _ResetStep.newPassword => 'Create new password',
      };

  String get _description => switch (_step) {
        _ResetStep.email => 'Enter your email to receive a password reset code.',
        _ResetStep.code => 'Enter the 6-digit code sent to your email or phone.',
        _ResetStep.newPassword => 'Choose a new password for your account.',
      };

  Future<void> _sendCode({bool resend = false}) async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _toast('Enter a valid email address.');
      return;
    }
    setState(() {
      if (resend) {
        _resending = true;
      } else {
        _loading = true;
      }
    });
    try {
      // Repository normalizes every transport/server outcome to a silent
      // success. Defense in depth: any unexpected throw still yields the
      // same acknowledgement + navigation (never ApiErrorMapper / raw text).
      await ref.read(authRepositoryProvider).requestPasswordReset(email);
    } catch (_) {
      // ignored — identical UX below
    }
    if (!mounted) return;
    _acknowledgeCodeSent(resend);
    if (mounted) {
      setState(() {
        _loading = false;
        _resending = false;
      });
    }
  }

  void _acknowledgeCodeSent(bool resend) {
    _toast(passwordResetAcknowledgement);
    if (!resend) {
      setState(() => _step = _ResetStep.code);
    }
  }

  void _continueFromCode() {
    final code = _code.text.trim();
    if (code.length != 6) {
      _toast('Enter the 6-digit reset code.');
      return;
    }
    setState(() => _step = _ResetStep.newPassword);
  }

  Future<void> _submitNewPassword() async {
    if (_password.text.length < 8) {
      _toast('Password must be at least 8 characters.');
      return;
    }
    if (_password.text != _confirm.text) {
      _toast('Passwords do not match.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            email: _email.text.trim(),
            code: _code.text.trim(),
            newPassword: _password.text,
          );
      if (!mounted) return;
      _toast('Password reset successfully. You can now sign in.');
      context.go('/login');
    } on AuthException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (e) {
      if (!mounted) return;
      _toast(ApiErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _loadingChild() => const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _title,
      footer: TextButton(
        onPressed: _loading
            ? null
            : () {
                if (_step == _ResetStep.email) {
                  context.go('/login');
                } else if (_step == _ResetStep.code) {
                  setState(() {
                    _step = _ResetStep.email;
                    _code.clear();
                  });
                } else {
                  setState(() => _step = _ResetStep.code);
                }
              },
        child: Text(_step == _ResetStep.email
            ? 'Back to login'
            : _step == _ResetStep.code
                ? 'Change email'
                : 'Back'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_description, style: const TextStyle(color: MkgColors.textGrey)),
          const SizedBox(height: 16),
          if (_step == _ResetStep.email) ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading ? null : _sendCode(),
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loading ? null : () => _sendCode(),
              child: _loading ? _loadingChild() : const Text('Send Reset Code'),
            ),
          ] else if (_step == _ResetStep.code) ...[
            Text(
              'Code sent to ${_email.text.trim()}',
              style: const TextStyle(color: MkgColors.textGrey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 6,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
              onSubmitted: (_) => _continueFromCode(),
              decoration: const InputDecoration(
                labelText: 'Reset Code',
                counterText: '',
                prefixIcon: Icon(Icons.pin_outlined),
                hintText: '000000',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _code.text.trim().length == 6 ? _continueFromCode : null,
              child: const Text('Continue'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resending ? null : () => _sendCode(resend: true),
                child: _resending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Resend Code'),
              ),
            ),
          ] else ...[
            TextField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'New Password (min 8)',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading ? null : _submitNewPassword(),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loading ? null : _submitNewPassword,
              child: _loading ? _loadingChild() : const Text('Reset Password'),
            ),
          ],
        ],
      ),
    );
  }
}
