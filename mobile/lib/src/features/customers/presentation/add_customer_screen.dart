import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../auth/application/auth_controller.dart';
import '../application/customers_controller.dart';
import '../domain/customer.dart';

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

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    if (customer != null) {
      _nameController.text = customer.fullName;
      _phoneController.text = customer.phoneNumber ?? '';
      _notesController.text = customer.notes ?? '';
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
                  decoration: const InputDecoration(labelText: 'Phone number (optional)'),
                  keyboardType: TextInputType.phone,
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
              phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            );
      } else {
        await ref.read(customersRepositoryProvider).updateCustomer(
              customerId: widget.customer!.id,
              fullName: _nameController.text.trim(),
              phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            );
      }
      ref.invalidate(customersProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
}
