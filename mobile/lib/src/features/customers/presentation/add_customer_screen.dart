import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../auth/application/auth_controller.dart';
import '../application/customers_controller.dart';
import '../domain/customer.dart';
import '../domain/duplicate_customer_exception.dart';
import 'customer_details_screen.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({
    super.key,
    this.customer,
  });

  final Customer? customer;

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _speech = SpeechToText();
  bool _isListening = false;
  bool _saving = false;
  String _gender = 'female';

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    if (customer != null) {
      _nameController.text = customer.fullName;
      _phoneController.text = customer.phoneNumber ?? '';
      _notesController.text = customer.notes ?? '';
      _gender = customer.gender;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.customer == null ? 'Add Customer' : 'Edit Customer')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone number (optional)',
                    hintText: 'e.g. 08012345678',
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return null;
                    if (!RegExp(r'^\d+$').hasMatch(v)) {
                      return 'Phone must be numeric only';
                    }
                    if (v.length > 11) {
                      return 'Phone must be max 11 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) => setState(() => _gender = value ?? 'other'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    suffixIcon: IconButton(
                      onPressed: _toggleSpeechToText,
                      icon: Icon(_isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
                    ),
                  ),
                  maxLines: 3,
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _saving ? null : _saveCustomer,
                  child: Text(_saving ? 'Saving...' : widget.customer == null ? 'Save Customer' : 'Save Changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need an active session. Please re-open app.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.customer == null) {
        await ref.read(customersRepositoryProvider).createCustomer(
              fullName: _nameController.text.trim(),
              gender: _gender,
              phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            );
      } else {
        await ref.read(customersRepositoryProvider).updateCustomer(
              customerId: widget.customer!.id,
              fullName: _nameController.text.trim(),
              gender: _gender,
              phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            );
      }
      ref.invalidate(customersProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DuplicateCustomerException catch (e) {
      if (!mounted) return;
      if (widget.customer == null) {
        final choice = await _showDuplicateDialog(context, e);
        if (choice == _DuplicateChoice.openExisting && mounted) {
          final customers = await ref.read(customersProvider.future);
          final existing = customers.where((c) => c.id == e.existingCustomerId).firstOrNull;
          if (existing != null) {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerDetailsScreen(customer: existing),
              ),
            );
          }
        }
      } else {
        await _showDuplicateEditDialog(context, e);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save customer: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleSpeechToText() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize();
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice input is not available on this device.')),
      );
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        final current = _notesController.text.trim();
        final newWords = result.recognizedWords.trim();
        if (newWords.isEmpty) {
          return;
        }
        _notesController.text = current.isEmpty ? newWords : '$current $newWords';
        _notesController.selection = TextSelection.fromPosition(
          TextPosition(offset: _notesController.text.length),
        );
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
    );
  }

  Future<_DuplicateChoice?> _showDuplicateDialog(
    BuildContext context,
    DuplicateCustomerException e,
  ) async {
    return showDialog<_DuplicateChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Customer already exists'),
        content: Text(
          'You already have a customer named "${e.customerName}".\n\n'
          'To add another person with a similar name, use a distinguishing detail '
          'e.g. "Fatima Mohammed (daughter)" or "Musa - Ikeja".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_DuplicateChoice.cancel),
            child: const Text('Change name'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_DuplicateChoice.openExisting),
            child: const Text('Open existing'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDuplicateEditDialog(
    BuildContext context,
    DuplicateCustomerException e,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name already in use'),
        content: Text(
          'Another customer is already named "${e.customerName}".\n\n'
          'Use a distinguishing detail in the name, e.g. "(daughter)" or "- Ikeja".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

enum _DuplicateChoice { cancel, openExisting }
