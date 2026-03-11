import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/preferences/measurement_unit_provider.dart';
import '../application/customers_controller.dart';
import '../domain/measurement_entry.dart';

class AddMeasurementScreen extends ConsumerStatefulWidget {
  const AddMeasurementScreen({
    super.key,
    required this.customerId,
    required this.customerGender,
    this.measurement,
  });

  final String customerId;
  final String customerGender;
  final MeasurementEntry? measurement;

  @override
  ConsumerState<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends ConsumerState<AddMeasurementScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _measurementControllers = {};
  final _notesController = TextEditingController();
  final _speech = SpeechToText();
  bool _isListening = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final keys = _fieldDefinitionsForGender(widget.customerGender).keys.toList();
    for (final key in keys) {
      _measurementControllers[key] = TextEditingController();
    }

    final payload = widget.measurement?.payload;
    if (payload != null) {
      for (final entry in payload.entries) {
        if (entry.key == 'notes' || entry.key == 'unit') continue;
        _measurementControllers.putIfAbsent(entry.key, () => TextEditingController());
        _measurementControllers[entry.key]!.text = (entry.value ?? '').toString();
      }
      _notesController.text = (payload['notes'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    for (final controller in _measurementControllers.values) {
      controller.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(measurementUnitProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.measurement == null ? 'Add Measurement' : 'Edit Measurement')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                ..._buildMeasurementFields(unit),
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

  List<Widget> _buildMeasurementFields(MeasurementUnit unit) {
    final definitions = _fieldDefinitionsForGender(widget.customerGender);
    final unitLabel = unit == MeasurementUnit.inches ? 'inches' : 'cm';
    final fields = <Widget>[];
    for (final entry in definitions.entries) {
      final key = entry.key;
      final label = entry.value;
      final controller = _measurementControllers[key]!;
      fields.add(_numberField(controller, '$label ($unitLabel)'));
      fields.add(const SizedBox(height: 12));
    }
    return fields;
  }

  Map<String, String> _fieldDefinitionsForGender(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return {
          'head_circumference': 'Head / Cap (Fila)',
          'neck': 'Neck',
          'shoulder': 'Shoulder',
          'chest': 'Chest',
          'waist': 'Waist',
          'hip': 'Hip',
          'sleeve': 'Sleeve',
          'armhole': 'Armhole',
          'back_length': 'Back Length',
          'front_length': 'Front Length',
          'inseam': 'Inseam',
          'trouser_length': 'Trouser Length',
          'thigh': 'Thigh',
          'knee': 'Knee',
        };
      case 'female':
        return {
          'head_circumference': 'Head / Cap (Fila)',
          'neck': 'Neck',
          'shoulder': 'Shoulder',
          'chest': 'Chest',
          'bust': 'Bust',
          'under_bust': 'Under Bust',
          'waist': 'Waist',
          'hip': 'Hip',
          'sleeve': 'Sleeve',
          'armhole': 'Armhole',
          'back_length': 'Back Length',
          'front_length': 'Front Length',
          'blouse_length': 'Blouse Length',
          'gown_length': 'Gown Length',
          'skirt_length': 'Skirt Length',
          'inseam': 'Inseam',
          'trouser_length': 'Trouser Length',
          'thigh': 'Thigh',
          'knee': 'Knee',
        };
      default:
        return {
          'head_circumference': 'Head / Cap (Fila)',
          'neck': 'Neck',
          'shoulder': 'Shoulder',
          'chest': 'Chest',
          'waist': 'Waist',
          'hip': 'Hip',
          'sleeve': 'Sleeve',
          'armhole': 'Armhole',
          'back_length': 'Back Length',
          'inseam': 'Inseam',
          'trouser_length': 'Trouser Length',
          'thigh': 'Thigh',
          'knee': 'Knee',
        };
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    try {
      final unit = ref.read(measurementUnitProvider);
      final payload = <String, dynamic>{};
      for (final entry in _measurementControllers.entries) {
        payload[entry.key] = double.parse(entry.value.text.trim());
      }
      payload['notes'] = _notesController.text.trim();
      payload['unit'] = unit == MeasurementUnit.inches ? 'inches' : 'cm';

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
