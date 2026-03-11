import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: loading
                ? null
                : () async {
                    if (isRegister) {
                      await ref.read(authControllerProvider.notifier).register(
                            fullName: _fullNameController.text.trim(),
                            email: _emailController.text.trim(),
                            password: _passwordController.text,
                          );
                    } else {
                      await ref.read(authControllerProvider.notifier).login(
                            email: _emailController.text.trim(),
                            password: _passwordController.text,
                          );
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
            child: Text(isRegister ? 'Create Account' : 'Sign In'),
          ),
          if (authState.hasError) ...[
            const SizedBox(height: 10),
            Text(
              '${authState.error}',
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
    );
  }
}
