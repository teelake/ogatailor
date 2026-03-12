import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../data/auth_repository.dart';

final _emailRegex = RegExp(r'^[\w\-\.]+@[\w\-]+(\.[\w\-]+)+$');

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(authRepositoryProvider).fetchProfile();
      _fullNameController.text = (profile['full_name'] ?? '').toString();
      _emailController.text = (profile['email'] ?? '').toString();
      _phoneController.text = (profile['phone_number'] ?? '').toString();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Full name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Email is required';
                        if (!_emailRegex.hasMatch(s)) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: 'e.g. 08012345678',
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return 'Phone number is required';
                        if (!RegExp(r'^\d+$').hasMatch(value)) {
                          return 'Phone must be numeric only';
                        }
                        if (value.length != 11) {
                          return 'Phone must be exactly 11 digits';
                        }
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
                              await ref.read(authRepositoryProvider).updateProfile(
                                    fullName: _fullNameController.text.trim(),
                                    email: _emailController.text.trim(),
                                    phoneNumber: _phoneController.text.trim(),
                                  );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Profile updated')),
                              );
                            } catch (error) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    userFriendlyError(
                                      error,
                                      fallback: 'Could not update profile. Please try again.',
                                    ),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
                      child: Text(_saving ? 'Saving...' : 'Save Profile'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
