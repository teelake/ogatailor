import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../application/customers_controller.dart';
import '../domain/measurement_entry.dart';

class AddMeasurementScreen extends ConsumerStatefulWidget {
  const AddMeasurementScreen({
    super.key,
    required this.customerId,
    this.measurement,
  });

  final String customerId;
  final MeasurementEntry? measurement;

  @override
  ConsumerState<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends ConsumerState<AddMeasurementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _chestController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipController = TextEditingController();
  final _inseamController = TextEditingController();
  final _notesController = TextEditingController();
  final _speech = SpeechToText();
  bool _isListening = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final payload = widget.measurement?.payload;
    if (payload != null) {
      _chestController.text = (payload['chest'] ?? '').toString();
      _waistController.text = (payload['waist'] ?? '').toString();
      _hipController.text = (payload['hip'] ?? '').toString();
      _inseamController.text = (payload['inseam'] ?? '').toString();
      _notesController.text = (payload['notes'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _chestController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _inseamController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.measurement == null ? 'Add Measurement' : 'Edit Measurement')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                _numberField(_chestController, 'Chest (inches)'),
                const SizedBox(height: 12),
                _numberField(_waistController, 'Waist (inches)'),
                const SizedBox(height: 12),
                _numberField(_hipController, 'Hip (inches)'),
                const SizedBox(height: 12),
                _numberField(_inseamController, 'Inseam (inches)'),
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
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving
                      ? 'Saving...'
                      : widget.measurement == null
                          ? 'Save Measurement'
                          : 'Save Changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label is required';
        }
        if (double.tryParse(value.trim()) == null) {
          return 'Enter a valid number';
        }
        return null;
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'chest': double.parse(_chestController.text.trim()),
        'waist': double.parse(_waistController.text.trim()),
        'hip': double.parse(_hipController.text.trim()),
        'inseam': double.parse(_inseamController.text.trim()),
        'notes': _notesController.text.trim(),
      };

      if (widget.measurement == null) {
        await ref.read(customersRepositoryProvider).createMeasurement(
              customerId: widget.customerId,
              takenAt: DateTime.now(),
              payload: payload,
            );
      } else {
        await ref.read(customersRepositoryProvider).updateMeasurement(
              measurementId: widget.measurement!.id,
              takenAt: DateTime.now(),
              payload: payload,
            );
      }

      ref.invalidate(customerMeasurementsProvider(widget.customerId));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save measurement: $error')),
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
        final words = result.recognizedWords.trim();
        if (words.isEmpty) {
          return;
        }
        final current = _notesController.text.trim();
        _notesController.text = current.isEmpty ? words : '$current $words';
        _notesController.selection = TextSelection.fromPosition(
          TextPosition(offset: _notesController.text.length),
        );
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
    );
  }
}
