import 'package:flutter/material.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.onBack,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            key: ValueKey(title),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: onBack == null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _brand(context),
                        )
                      : TextButton.icon(
                          onPressed: onBack,
                          icon: const Icon(Icons.chevron_left, size: 20),
                          label: _brand(context),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                ),
                const SizedBox(height: 8),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _brand(BuildContext context) => Text(
    'Calander',
    style: TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    ),
  );
}

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.password = false,
    this.email = false,
    this.enabled = true,
    this.validator,
    this.onSubmitted,
    this.autofillHints,
  });
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool password;
  final bool email;
  final bool enabled;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;
  final Iterable<String>? autofillHints;
  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          validator: widget.validator,
          autofillHints: widget.autofillHints,
          obscureText: widget.password && _obscure,
          enableSuggestions: !widget.password,
          autocorrect: !widget.password && !widget.email,
          keyboardType: widget.email
              ? TextInputType.emailAddress
              : TextInputType.text,
          textCapitalization: widget.email || widget.password
              ? TextCapitalization.none
              : TextCapitalization.words,
          textInputAction: widget.onSubmitted == null
              ? TextInputAction.next
              : TextInputAction.done,
          onFieldSubmitted: (_) => widget.onSubmitted?.call(),
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            suffixIcon: widget.password
                ? IconButton(
                    onPressed: widget.enabled
                        ? () => setState(() => _obscure = !_obscure)
                        : null,
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  )
                : null,
          ),
        ),
      ],
    ),
  );
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class AuthMessage extends StatelessWidget {
  const AuthMessage(this.message, {super.key, this.error = true});
  final String? message;
  final bool error;
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message!,
              style: TextStyle(
                color: error
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
}

class AuthButton extends StatelessWidget {
  const AuthButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label),
  );
}

String? validateEmail(String? value) {
  if (value == null ||
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
    return 'Enter a valid email address.';
  }
  return null;
}
