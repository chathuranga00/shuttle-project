import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/widgets/app_text_field.dart';
import '../../../../core/utils/widgets/error_banner.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _facultyCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _studentIdCtrl.dispose();
    _facultyCtrl.dispose();
    _yearCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          studentId: _studentIdCtrl.text.trim(),
          faculty: _facultyCtrl.text.trim(),
          year: int.parse(_yearCtrl.text.trim()),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go(AppRoutes.login),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student Registration',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Fill in your university details to get started',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),

                // ── Error banner ─────────────────────────────────────────
                if (authState.errorMessage != null) ...[
                  ErrorBanner(
                    message: authState.errorMessage!,
                    onDismiss: () =>
                        ref.read(authProvider.notifier).clearError(),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Section: Personal ────────────────────────────────────
                const _SectionLabel(label: 'Personal Information'),
                const SizedBox(height: 12),

                AppTextField(
                  label: 'Full name',
                  hint: 'As it appears on your ID',
                  controller: _nameCtrl,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  autofillHints: const [AutofillHints.name],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    if (v.trim().length < 2) return 'Name is too short';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                AppTextField(
                  label: 'Email address',
                  hint: 'your@university.lk',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.email_outlined),
                  autofillHints: const [AutofillHints.email],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                AppTextField(
                  label: 'Phone number (optional)',
                  hint: '+94 77 000 0000',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!RegExp(r'^\+?[\d\s\-]{7,20}$').hasMatch(v.trim())) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Password ─────────────────────────────────────────────
                AppTextField(
                  label: 'Password',
                  hint: 'Min. 8 characters',
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // ── Section: Academic ────────────────────────────────────
                const _SectionLabel(label: 'Academic Details'),
                const SizedBox(height: 12),

                AppTextField(
                  label: 'Student ID',
                  hint: 'e.g. S2024001',
                  controller: _studentIdCtrl,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.badge_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Student ID is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                AppTextField(
                  label: 'Faculty',
                  hint: 'e.g. Engineering',
                  controller: _facultyCtrl,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.school_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Faculty is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                AppTextField(
                  label: 'Enrollment year',
                  hint: 'e.g. 2024',
                  controller: _yearCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enrollment year is required';
                    }
                    final year = int.tryParse(v.trim());
                    if (year == null || year < 2000 || year > 2100) {
                      return 'Enter a valid year (e.g. 2024)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // ── Register button ──────────────────────────────────────
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _submit,
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 20),

                // ── Login link ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
