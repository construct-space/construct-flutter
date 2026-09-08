// Inline email + password login, mirroring construct-app/LoginPage:
//   /api/auth/login → access_token | requires_2fa | error
//   /verify-2fa     → access_token | error
// Passkey path falls back to OAuth in an in-app browser (passkeys
// need real browser origin/RP-ID, can't run in arbitrary webviews).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../password.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

enum _Mode { password, twoFactor }

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _codeCtl = TextEditingController();

  _Mode _mode = _Mode.password;
  String _pendingToken = '';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    final email = _emailCtl.text.trim();
    final password = _passwordCtl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await ref.read(passwordAuthProvider).login(email, password);
    if (!mounted) return;
    setState(() => _busy = false);
    await _handle(res);
  }

  Future<void> _submit2FA() async {
    final code = _codeCtl.text.trim();
    if (code.length < 6) {
      setState(
        () => _error = 'Enter the 6-digit code from your authenticator.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await ref
        .read(passwordAuthProvider)
        .verifyTwoFactor(_pendingToken, code);
    if (!mounted) return;
    setState(() => _busy = false);
    await _handle(res);
  }

  Future<void> _handle(LoginOutcome res) async {
    switch (res) {
      case LoginOk(:final accessToken):
        await ref.read(authProvider.notifier).setToken(accessToken);
      case LoginNeeds2FA(:final pendingToken):
        setState(() {
          _pendingToken = pendingToken;
          _mode = _Mode.twoFactor;
          _codeCtl.clear();
        });
      case LoginMustReset():
        setState(
          () => _error = 'Password reset required — sign in via the browser.',
        );
      case LoginError(:final message):
        setState(() => _error = message);
    }
  }

  Future<void> _signInWithPasskey() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(oauthServiceProvider).signIn();
      await ref.read(authProvider.notifier).setToken(result.accessToken);
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        setState(() {
          _error = msg.contains('CANCELED') ? 'Sign-in canceled.' : msg;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cancel2FA() {
    setState(() {
      _mode = _Mode.password;
      _codeCtl.clear();
      _pendingToken = '';
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/constr.png',
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'CONSTRUCT',
                    style: theme.textTheme.bodySmall?.copyWith(
                      letterSpacing: 2,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _mode == _Mode.twoFactor ? 'Verify' : 'Sign in',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _mode == _Mode.twoFactor
                        ? 'Enter the 6-digit code from your authenticator app.'
                        : 'Access your spaces and continue building.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_mode == _Mode.password)
                    _buildPasswordForm()
                  else
                    _build2FAForm(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailCtl,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.mail_outline),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submitPassword(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtl,
          autofillHints: const [AutofillHints.password],
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submitPassword(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submitPassword,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('SIGN IN'),
        ),
        const SizedBox(height: 16),
        Divider(color: Theme.of(context).dividerColor),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _signInWithPasskey,
          icon: const Icon(Icons.key),
          label: const Text('Passkey (opens browser)'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _build2FAForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeCtl,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(fontSize: 22, letterSpacing: 6),
          decoration: const InputDecoration(
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit2FA(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit2FA,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('VERIFY'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : _cancel2FA,
          child: const Text('Use a different account'),
        ),
      ],
    );
  }
}
