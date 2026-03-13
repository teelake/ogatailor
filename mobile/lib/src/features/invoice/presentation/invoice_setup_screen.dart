import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../data/invoice_repository.dart';

final _cacRegex = RegExp(r'^(BN|RC)\d+$', caseSensitive: false);

class InvoiceSetupScreen extends ConsumerStatefulWidget {
  const InvoiceSetupScreen({super.key});

  @override
  ConsumerState<InvoiceSetupScreen> createState() => _InvoiceSetupScreenState();
}

class _InvoiceSetupScreenState extends ConsumerState<InvoiceSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _cacNumberController = TextEditingController();
  final _vatRateController = TextEditingController(text: '7.5');
  final _paymentTermsController = TextEditingController(text: 'Due on receipt');

  bool _loading = true;
  bool _saving = false;
  bool _cacRegistered = false;
  bool _vatEnabled = false;
  String _cacType = 'company';
  String _currency = 'NGN';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose();
    _businessAddressController.dispose();
    _cacNumberController.dispose();
    _vatRateController.dispose();
    _paymentTermsController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(invoiceRepositoryProvider).getBusinessProfile();
      if (profile != null && mounted) {
        _businessNameController.text = (profile['business_name'] ?? '').toString();
        _businessPhoneController.text = (profile['business_phone'] ?? '').toString();
        _businessEmailController.text = (profile['business_email'] ?? '').toString();
        _businessAddressController.text = (profile['business_address'] ?? '').toString();
        _cacRegistered = (profile['cac_registered'] ?? false) == true;
        _cacType = (profile['cac_registration_type'] ?? 'company').toString();
        _cacNumberController.text = (profile['cac_number'] ?? '').toString();
        _vatEnabled = (profile['vat_enabled'] ?? false) == true;
        _vatRateController.text = ((profile['default_vat_rate'] ?? 0) as num).toString();
        _currency = (profile['currency'] ?? 'NGN').toString();
        _paymentTermsController.text = (profile['payment_terms'] ?? 'Due on receipt').toString();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Setup')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Complete your business details to generate invoices. Required before using the invoice feature.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _businessNameController,
                      decoration: const InputDecoration(
                        labelText: 'Business / brand name',
                        hintText: 'e.g. Base07 Clothings',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Business name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Business phone number',
                        hintText: 'e.g. 08012345678',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Business email',
                        hintText: 'e.g. hello@yourbusiness.com',
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return null;
                        if (!RegExp(r'^[\w\-\.]+@[\w\-]+(\.[\w\-]+)+$').hasMatch(s)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessAddressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Business address (optional)',
                        hintText: 'Full address for invoices',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('CAC registration', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Business registered with CAC'),
                      subtitle: const Text('Corporate Affairs Commission'),
                      value: _cacRegistered,
                      onChanged: (v) => setState(() => _cacRegistered = v),
                    ),
                    if (_cacRegistered) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _cacType,
                        decoration: const InputDecoration(labelText: 'Registration type'),
                        items: const [
                          DropdownMenuItem(value: 'company', child: Text('Company')),
                          DropdownMenuItem(value: 'business', child: Text('Business registration')),
                        ],
                        onChanged: (v) => setState(() => _cacType = v ?? 'company'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cacNumberController,
                        decoration: const InputDecoration(
                          labelText: 'CAC registration number',
                          hintText: 'e.g. BN1234567 or RC1234567',
                        ),
                        validator: _cacRegistered
                            ? (v) {
                                final s = (v ?? '').trim().toUpperCase();
                                if (s.isEmpty) return 'CAC number is required';
                                if (!_cacRegex.hasMatch(s)) {
                                  return 'Must start with BN or RC followed by digits';
                                }
                                return null;
                              }
                            : null,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text('Invoice settings', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include VAT on invoices'),
                      value: _vatEnabled,
                      onChanged: (v) => setState(() => _vatEnabled = v),
                    ),
                    if (_vatEnabled) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _vatRateController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Default VAT rate (%)',
                          hintText: 'e.g. 7.5',
                        ),
                        validator: _vatEnabled
                            ? (v) {
                                final n = double.tryParse((v ?? '').trim());
                                if (n == null || n < 0 || n > 100) {
                                  return 'Enter a rate between 0 and 100';
                                }
                                return null;
                              }
                            : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _currency,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: const [
                        DropdownMenuItem(value: 'NGN', child: Text('NGN (₦)')),
                        DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                        DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                      ],
                      onChanged: (v) => setState(() => _currency = v ?? 'NGN'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _paymentTermsController,
                      decoration: const InputDecoration(
                        labelText: 'Payment terms',
                        hintText: 'e.g. Due on receipt, Net 30',
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              setState(() => _saving = true);
                              try {
                                await ref.read(invoiceRepositoryProvider).saveBusinessProfile(
                                      businessName: _businessNameController.text.trim(),
                                      businessPhone: _businessPhoneController.text.trim().isEmpty
                                          ? null
                                          : _businessPhoneController.text.trim(),
                                      businessEmail: _businessEmailController.text.trim().isEmpty
                                          ? null
                                          : _businessEmailController.text.trim(),
                                      businessAddress:
                                          _businessAddressController.text.trim().isEmpty
                                              ? null
                                              : _businessAddressController.text.trim(),
                                      cacRegistered: _cacRegistered,
                                      cacRegistrationType:
                                          _cacRegistered ? _cacType : null,
                                      cacNumber: _cacRegistered &&
                                              _cacNumberController.text.trim().isNotEmpty
                                          ? _cacNumberController.text.trim()
                                          : null,
                                      vatEnabled: _vatEnabled,
                                      defaultVatRate:
                                          double.tryParse(_vatRateController.text.trim()) ?? 0,
                                      currency: _currency,
                                      paymentTerms: _paymentTermsController.text.trim().isEmpty
                                          ? null
                                          : _paymentTermsController.text.trim(),
                                    );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invoice setup completed')),
                                );
                                Navigator.of(context).pop();
                              } catch (error) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      userFriendlyError(
                                        error,
                                        fallback: 'Could not save. Please try again.',
                                      ),
                                    ),
                                  ),
                                );
                              } finally {
                                if (mounted) setState(() => _saving = false);
                              }
                            },
                      child: Text(_saving ? 'Saving...' : 'Complete Setup'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
