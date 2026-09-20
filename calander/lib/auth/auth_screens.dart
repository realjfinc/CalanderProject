import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/legal/privacy_policy_screen.dart';
import '../ui/legal/terms_screen.dart';
import 'auth_service.dart';
import 'auth_widgets.dart';

enum AuthPage { welcome, signup, login, reset, resetSent }

class SignedOutFlow extends StatefulWidget {
  const SignedOutFlow({super.key, required this.auth});
  final AuthService auth;
  @override
  State<SignedOutFlow> createState() => _SignedOutFlowState();
}

class _SignedOutFlowState extends State<SignedOutFlow> {
  AuthPage _page = AuthPage.welcome;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  void _go(AuthPage page) {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    _password.clear();
    _confirm.clear();
    setState(() {
      _page = page;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (_page) {
        case AuthPage.signup:
          await widget.auth.createAccount(
            _name.text,
            _email.text,
            _password.text,
          );
          TextInput.finishAutofillContext();
        case AuthPage.login:
          await widget.auth.logIn(_email.text, _password.text);
          TextInput.finishAutofillContext();
        case AuthPage.reset:
          await widget.auth.sendPasswordReset(_email.text);
          if (mounted) setState(() => _page = AuthPage.resetSent);
        default:
          break;
      }
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Widget _emailField() => AuthField(
    label: 'Email',
    controller: _email,
    hint: 'you@example.com',
    email: true,
    enabled: !_busy,
    validator: validateEmail,
    autofillHints: const [AutofillHints.email],
    onSubmitted: _page == AuthPage.reset ? _submit : null,
  );

  String? _passwordValidation(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    if (_page == AuthPage.signup && value.length < 8) {
      return 'Use at least 8 characters.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_page) {
      AuthPage.welcome => 'Welcome To Calander',
      AuthPage.signup => 'Create account',
      AuthPage.login => 'Welcome back',
      AuthPage.reset => 'Reset password',
      AuthPage.resetSent => 'Check your inbox',
    };
    final subtitle = switch (_page) {
      AuthPage.welcome => 'A little more room for life (and sports).',
      AuthPage.signup => 'Make your days your own.',
      AuthPage.login => 'Your day is waiting.',
      AuthPage.reset => 'We’ll send you a reset link.',
      AuthPage.resetSent => 'Let’s get you back to your plans.',
    };
    return PopScope(
      canPop: _page == AuthPage.welcome && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _go(AuthPage.welcome);
      },
      child: AuthLayout(
        title: title,
        subtitle: subtitle,
        onBack: _page == AuthPage.welcome || _busy
            ? null
            : () => _go(AuthPage.welcome),
        children: [
          if (_page == AuthPage.welcome) ...[
            const SizedBox(height: 20),
            const _WelcomePreview(),
            const SizedBox(height: 24),
            Text(
              'Your calendars, friends and favorite teams.\nOne simple place to plan your day.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            AuthButton('Get started', onPressed: () => _go(AuthPage.signup)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _go(AuthPage.login),
              child: const Text('I already have an account'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
              child: const Text('Privacy Policy'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsScreen()),
              ),
              child: const Text('Terms and Conditions'),
            ),
          ] else if (_page == AuthPage.resetSent) ...[
            const SizedBox(height: 24),
            AuthCard(
              title: 'Check your email',
              message:
                  'If an account exists for ${_email.text.trim()}, we’ve sent a password reset link. Open it to choose a new password, then return here to log in.',
            ),
            const SizedBox(height: 24),
            AuthButton('Back to log in', onPressed: () => _go(AuthPage.login)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _go(AuthPage.reset),
              child: const Text('Try another email'),
            ),
          ] else ...[
            if (_page == AuthPage.reset) ...[
              const AuthCard(
                title: 'Forgotten happens.',
                message: 'Enter the email you used for Calander. We’ll help you get back to your plans.',
              ),
              const SizedBox(height: 24),
            ],
            AutofillGroup(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_page == AuthPage.signup)
                      AuthField(
                        label: 'Full name',
                        controller: _name,
                        hint: 'Your name',
                        enabled: !_busy,
                        autofillHints: const [AutofillHints.name],
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Enter your name.'
                            : null,
                      ),
                    _emailField(),
                    if (_page != AuthPage.reset)
                      AuthField(
                        label: 'Password',
                        controller: _password,
                        hint: _page == AuthPage.signup
                            ? 'Create a strong password'
                            : 'Enter your password',
                        password: true,
                        enabled: !_busy,
                        validator: _passwordValidation,
                        autofillHints: [
                          _page == AuthPage.signup
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onSubmitted: _page == AuthPage.login ? _submit : null,
                      ),
                    if (_page == AuthPage.signup)
                      AuthField(
                        label: 'Confirm password',
                        controller: _confirm,
                        hint: 'Re-enter your password',
                        password: true,
                        enabled: !_busy,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: _submit,
                        validator: (v) =>
                            v != _password.text || (v?.isEmpty ?? true)
                            ? 'Your passwords don’t match.'
                            : null,
                      ),
                    if (_page == AuthPage.login)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _busy ? null : () => _go(AuthPage.reset),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    AuthMessage(_error ?? widget.auth.notice),
                    AuthButton(
                      switch (_page) {
                        AuthPage.signup => 'Create account',
                        AuthPage.login => 'Log in',
                        _ => 'Send reset link',
                      },
                      onPressed: _submit,
                      busy: _busy,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _go(
                      _page == AuthPage.login
                          ? AuthPage.signup
                          : AuthPage.login,
                    ),
              child: Text(
                _page == AuthPage.login
                    ? 'New here? Create an account'
                    : _page == AuthPage.signup
                    ? 'Already have an account? Log in'
                    : 'Back to log in',
              ),
            ),
          ],
        ],
      ),
    );
  }

}

class _WelcomePreview extends StatelessWidget {
  const _WelcomePreview();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A LITTLE LOOK AHEAD',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Space for\nwhat matters.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 24),
        Text(
          '09:00   Design review',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        const Text('12:30   Jets game'),
        const SizedBox(height: 12),
        const Text('18:00   A little time to relax'),
      ],
    ),
  );
}

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key, required this.auth});
  final AuthService auth;
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _message;
  bool _error = false;
  int _cooldown = 0;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) {
      unawaited(_check(quiet: true));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = authErrorMessage(error);
          _error = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check({bool quiet = false}) => _run(() async {
    await widget.auth.refreshAccount();
    if (mounted && !(widget.auth.account?.verified ?? false) && !quiet) {
      setState(
        () => _message = 'Your email isn’t verified yet. Open the link in your email, then try again.',
      );
    }
  });
  Future<void> _resend() => _run(() async {
    if (_cooldown > 0) return;
    await widget.auth.sendVerification();
    if (!mounted) return;
    setState(() {
      _message = 'Verification email sent. Check your inbox and spam folder.';
      _cooldown = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  });
  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Check your inbox',
    subtitle: 'One last step to get started.',
    children: [
      const SizedBox(height: 24),
      AuthCard(
        title: 'You’ve got mail',
        message:
            'Open the verification link sent to ${widget.auth.account?.email ?? 'your email'}. Verify your address to continue to Calander.',
      ),
      const SizedBox(height: 24),
      AuthMessage(widget.auth.notice),
      AuthMessage(_message, error: _error),
      AuthButton(
        'I’ve verified my email',
        onPressed: () => _check(),
        busy: _busy,
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: _busy || _cooldown > 0 ? null : _resend,
        child: Text(
          _cooldown > 0 ? 'Resend email in ${_cooldown}s' : 'Resend email',
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: _busy ? null : () => _run(widget.auth.logOut),
        child: const Text('Use a different account'),
      ),
    ],
  );
}
