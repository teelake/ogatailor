import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(authRepositoryProvider).fetchProfile();
      _fullNameController.text = (profile['full_name'] ?? '').toString();
      _emailController.text = (profile['email'] ?? '').toString();
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
                      decoration: const InputDecoration(labelText: 'Email (optional)'),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return null;
                        if (!_emailRegex.hasMatch(s)) return 'Enter a valid email';
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
                                  );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Profile updated')),
                              );
                            } catch (error) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not update profile: $error')),
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
