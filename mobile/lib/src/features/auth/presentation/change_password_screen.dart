import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Current password is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newController,
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
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
                        setState(() => _saving = true);
                      try {
                        await ref.read(authRepositoryProvider).changePassword(
                              currentPassword: _currentController.text,
                              newPassword: _newController.text,
                            );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password changed')),
                        );
                        Navigator.of(context).pop();
                      } catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not change password: $error')),
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
