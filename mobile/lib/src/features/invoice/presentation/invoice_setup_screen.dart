import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/error_message.dart';
import '../../config/application/config_controller.dart';
import '../../config/data/config_repository.dart';
import '../data/invoice_repository.dart';
import '../domain/logo_validator.dart';

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
  bool _showAdvancedOptions = false;
  String _cacType = 'company';
  String _currency = 'NGN';
  String? _logoBase64;
  String? _logoError;

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
    AppConfig? config;
    try {
      config = await ref.read(appConfigProvider.future);
    } catch (_) {}
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
        _currency = (profile['currency'] ?? config?.invoiceDefaults.currency ?? 'NGN').toString();
        _paymentTermsController.text = (profile['payment_terms'] ?? config?.invoiceDefaults.paymentTerms ?? 'Due on receipt').toString();
        _logoBase64 = (profile['logo_data'] as String?)?.trim();
        if (_logoBase64 != null && _logoBase64!.isEmpty) _logoBase64 = null;
      } else if (mounted && config != null) {
        _vatRateController.text = config.invoiceDefaults.vatRate.toString();
        _currency = config.invoiceDefaults.currency;
        _paymentTermsController.text = config.invoiceDefaults.paymentTerms;
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
                      'Add your business details so invoices show your brand. Only the basics are required.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Text('Basic info', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 12),
                    _LogoUploadField(
                      logoBase64: _logoBase64,
                      error: _logoError,
                      onPicked: (base64) {
                        setState(() {
                          _logoBase64 = base64;
                          _logoError = null;
                        });
                      },
                      onRemove: () {
                        setState(() {
                          _logoBase64 = null;
                          _logoError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessNameController,
                      decoration: const InputDecoration(
                        labelText: 'Business / brand name',
                        hintText: 'e.g. Base07 Clothings',
                        helperText: 'This appears at the top of your invoices',
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
                        helperText: 'Optional — for customers to contact you',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Business email',
                        hintText: 'e.g. hello@yourbusiness.com',
                        helperText: 'Optional — shown on invoices',
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
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: () => setState(() => _showAdvancedOptions = !_showAdvancedOptions),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              _showAdvancedOptions ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _showAdvancedOptions ? 'Hide optional settings' : 'More options (CAC, VAT, etc.)',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showAdvancedOptions) ...[
                      const SizedBox(height: 16),
                      Text('CAC registration', style: Theme.of(context).textTheme.titleSmall),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'CAC = Corporate Affairs Commission. Only needed if your business is officially registered.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Business registered with CAC'),
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
                            helperText: 'Starts with BN or RC, then numbers',
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
                      const SizedBox(height: 20),
                      Text('Invoice settings', style: Theme.of(context).textTheme.titleSmall),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'VAT = Value Added Tax. Turn on if you charge tax on your services.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
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
                            helperText: 'Common rate in Nigeria is 7.5%',
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
                    ],
                    const SizedBox(height: 20),
                    Text('Invoice format', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _currency,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        helperText: 'Currency shown on your invoices',
                      ),
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
                        helperText: 'When payment is expected (e.g. "Due on receipt" or "Pay within 7 days")',
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              setState(() => _saving = true);
                              _logoError = _logoBase64 != null ? LogoValidation.validateBase64(_logoBase64!) : null;
                              if (_logoError != null) {
                                setState(() {});
                                return;
                              }
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
                                      logoData: _logoBase64,
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

class _LogoUploadField extends StatelessWidget {
  const _LogoUploadField({
    required this.logoBase64,
    required this.error,
    required this.onPicked,
    required this.onRemove,
  });

  final String? logoBase64;
  final String? error;
  final ValueChanged<String> onPicked;
  final VoidCallback onRemove;

  static const _maxSizeBytes = 512 * 1024;
  static const _minDim = 64;
  static const _maxDim = 512;

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      maxWidth: _maxDim.toDouble(),
      maxHeight: _maxDim.toDouble(),
      imageQuality: 90,
    );
    if (xFile == null || !context.mounted) return;
    final bytes = await xFile.readAsBytes();
    if (bytes.length > _maxSizeBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image must be under 500KB (current: ${(bytes.length / 1024).toStringAsFixed(0)}KB)')),
        );
      }
      return;
    }
    final err = LogoValidation.validate(bytes);
    if (err != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }
    onPicked(base64Encode(bytes));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Brand logo',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'PNG, JPEG or WEBP. 64–512px, max 500KB. Shown at top of invoices.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (logoBase64 != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(logoBase64!),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.photo_library_rounded),
                              title: const Text('Gallery'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickImage(context, ImageSource.gallery);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.camera_alt_rounded),
                              title: const Text('Camera'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickImage(context, ImageSource.camera);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Change'),
                  ),
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Remove'),
                  ),
                ],
              ),
            ] else
              OutlinedButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.photo_library_rounded),
                          title: const Text('Gallery'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickImage(context, ImageSource.gallery);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.camera_alt_rounded),
                          title: const Text('Camera'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickImage(context, ImageSource.camera);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: const Text('Upload logo'),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
