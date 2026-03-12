import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../data/auth_repository.dart';

const _minPasswordLength = 6;

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _currentController,
                obscureText: _hideCurrentPassword,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _hideCurrentPassword = !_hideCurrentPassword),
                    icon: Icon(
                      _hideCurrentPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    ),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Current password is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newController,
                obscureText: _hideNewPassword,
                decoration: InputDecoration(
                  labelText: 'New password',
                  hintText: 'Min $_minPasswordLength characters',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _hideNewPassword = !_hideNewPassword),
                    icon: Icon(
                      _hideNewPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'New password is required';
                  if (v.length < _minPasswordLength) {
                    return 'Password must be at least $_minPasswordLength characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: _hideConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
                    icon: Icon(
                      _hideConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please confirm your password';
                  if (v != _newController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        setState(() => _saving = true);
                        try {
                          await ref.read(authRepositoryProvider).changePassword(
                                currentPassword: _currentController.text,
                                newPassword: _newController.text,
                              );
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Password changed')),
                          );
                          navigator.pop();
                        } catch (error) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                userFriendlyError(
                                  error,
                                  fallback: 'Could not change password. Please try again.',
                                ),
                              ),
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: Text(_saving ? 'Saving...' : 'Change Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
