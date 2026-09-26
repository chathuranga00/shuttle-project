import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/widgets/app_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // UI only for now — backend endpoint not implemented yet
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: _submitted ? _SuccessView() : _FormView(
            formKey: _formKey,
            emailCtrl: _emailCtrl,
            onSubmit: _submit,
          ),
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.formKey,
    required this.emailCtrl,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_reset_rounded,
                size: 42,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Forgot your password?', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            "Enter the email address linked to your account and we'll send you a reset link.",
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 32),
          AppTextField(
            label: 'Email address',
            hint: 'you@university.lk',
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(Icons.email_outlined),
            autofillHints: const [AutofillHints.email],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onSubmit,
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: 48),
        Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 48,
              color: Colors.green,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Check your inbox', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          "If an account exists for that email, we've sent a password reset link. Check your spam folder if you don't see it.",
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        OutlinedButton(
          onPressed: () => context.pop(),
          child: const Text('Back to Sign In'),
        ),
      ],
    );
  }
}
