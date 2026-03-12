import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../application/auth_controller.dart';
import 'forgot_password_screen.dart';

enum AuthSheetMode { login, register }

Future<void> showAuthSheet(BuildContext context, {required AuthSheetMode mode}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AuthSheet(mode: mode),
  );
}

class _AuthSheet extends ConsumerStatefulWidget {
  const _AuthSheet({required this.mode});

  final AuthSheetMode mode;

  @override
  ConsumerState<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends ConsumerState<_AuthSheet> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = widget.mode == AuthSheetMode.register;
    final authState = ref.watch(authControllerProvider);
    final loading = authState.isLoading;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isRegister ? 'Create Account' : 'Sign In',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (isRegister) ...[
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: 'e.g. 08012345678',
                ),
                keyboardType: TextInputType.phone,
                maxLength: 11,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Phone number is required';
                  if (!RegExp(r'^\d+$').hasMatch(value)) return 'Phone must be numeric only';
                  if (value.length != 11) return 'Phone must be exactly 11 digits';
                  return null;
                },
              ),
              const SizedBox(height: 10),
            ],
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Email is required';
                if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(value)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  ),
                ),
              ),
              obscureText: _hidePassword,
              validator: (v) {
                final value = v ?? '';
                if (value.isEmpty) return 'Password is required';
                if (value.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            if (isRegister) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
                    icon: Icon(
                      _hideConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    ),
                  ),
                ),
                obscureText: _hideConfirmPassword,
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Please confirm password';
                  if (v != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () => _submit(isRegister: isRegister),
              child: Text(isRegister ? 'Create Account' : 'Sign In'),
            ),
            if (authState.hasError) ...[
              const SizedBox(height: 10),
              if (isConnectivityIssue(authState.error ?? Exception('Authentication failed')))
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No internet connection.',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                      ),
                      const SizedBox(height: 4),
                      const Text('Please turn on mobile data or Wi-Fi, then try again.'),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: loading ? null : () => _submit(isRegister: isRegister),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              if (!isConnectivityIssue(authState.error ?? Exception('Authentication failed')))
                Text(
                  userFriendlyError(
                    authState.error ?? Exception('Authentication failed'),
                    fallback: 'Authentication failed. Please check your details and try again.',
                  ),
                  style: const TextStyle(color: Colors.red),
                ),
            ],
            if (!isRegister) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                  );
                },
                child: const Text('Forgot password?'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit({required bool isRegister}) async {
    if (!_formKey.currentState!.validate()) return;
    if (isRegister) {
      await ref.read(authControllerProvider.notifier).register(
            fullName: _fullNameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } else {
      await ref.read(authControllerProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    }

    final latest = ref.read(authControllerProvider);
    if (!latest.hasError && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
