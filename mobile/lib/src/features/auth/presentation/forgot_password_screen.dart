import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

final _emailRegex = RegExp(r'^[\w\-\.]+@[\w\-]+(\.[\w\-]+)+$');
const _minPasswordLength = 6;

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _sending = false;
  bool _resetting = false;
  String _debugCode = '';

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Account email'),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Email is required';
                  if (!_emailRegex.hasMatch(s)) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _sending
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _sending = true);
                      try {
                        final code = await ref.read(authRepositoryProvider).forgotPassword(
                              email: _emailController.text.trim(),
                            );
                        if (!mounted) return;
                        setState(() => _debugCode = code);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reset code generated')),
                        );
                      } catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not generate code: $error')),
                        );
                      } finally {
                        if (mounted) setState(() => _sending = false);
                      }
                    },
                child: Text(_sending ? 'Sending...' : 'Generate Reset Code'),
              ),
              if (_debugCode.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Reset code (MVP): $_debugCode'),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Reset code'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Reset code is required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  hintText: 'Min $_minPasswordLength characters',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'New password is required';
                  if (v.length < _minPasswordLength) {
                    return 'Password must be at least $_minPasswordLength characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _resetting
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _resetting = true);
                      try {
                        await ref.read(authRepositoryProvider).resetPassword(
                              email: _emailController.text.trim(),
                              resetCode: _codeController.text.trim(),
                              newPassword: _newPasswordController.text,
                            );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password reset successful')),
                        );
                        Navigator.of(context).pop();
                      } catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not reset password: $error')),
                        );
                      } finally {
                        if (mounted) setState(() => _resetting = false);
                      }
                    },
                child: Text(_resetting ? 'Resetting...' : 'Reset Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
