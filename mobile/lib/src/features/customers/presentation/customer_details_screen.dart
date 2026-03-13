import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/phone_launcher.dart';
import '../../auth/application/auth_controller.dart';
import '../application/customers_controller.dart';
import '../domain/customer.dart';
import '../domain/measurement_entry.dart';
import 'add_customer_screen.dart';
import 'add_measurement_screen.dart';

class CustomerDetailsScreen extends ConsumerStatefulWidget {
  const CustomerDetailsScreen({
    super.key,
    required this.customer,
  });

  final Customer customer;

  @override
  ConsumerState<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends ConsumerState<CustomerDetailsScreen> {
  late Customer _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
  }

  @override
  Widget build(BuildContext context) {
    final measurementsAsync = ref.watch(customerMeasurementsProvider(_customer.id));
    final session = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _onMenuAction(value, session != null),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit customer')),
              PopupMenuItem(
                value: 'archive',
                child: Text(_customer.isArchived ? 'Unarchive customer' : 'Archive customer'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Delete customer')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => AddMeasurementScreen(
                customerId: _customer.id,
                customerGender: _customer.gender,
              ),
            ),
          );
          ref.invalidate(customerMeasurementsProvider(_customer.id));
        },
        icon: const Icon(Icons.straighten_rounded),
        label: const Text('Add Measurement'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_customer.fullName, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    _TappablePhone(phoneNumber: _customer.phoneNumber),
                    const SizedBox(height: 6),
                    Text('Gender: ${_formatGender(_customer.gender)}'),
                    if ((_customer.notes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(_customer.notes!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Measurement History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: measurementsAsync.when(
                data: (entries) {
                  if (entries.isEmpty) {
                    return const Center(child: Text('No measurements yet.'));
                  }

                  return ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final when = DateFormat('dd MMM yyyy, h:mm a').format(entry.takenAt.toLocal());
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _editMeasurement(entry),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(when, style: Theme.of(context).textTheme.titleSmall),
                                    ),
                                    IconButton(
                                      tooltip: 'Share measurement',
                                      onPressed: () => _shareMeasurement(entry),
                                      icon: const Icon(Icons.share_rounded),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: entry.payload.entries
                                      .where((e) => e.key != 'notes' && e.key != 'unit')
                                      .map((item) {
                                    final unit = (entry.payload['unit'] ?? 'inches') as String;
                                    final suffix = unit == 'cm' ? ' cm' : ' in';
                                    final label = _formatKey(item.key);
                                    return Chip(
                                      label: Text('$label: ${item.value}$suffix'),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Could not load history: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatKey(String key) {
    return key
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _formatGender(String value) {
    final v = value.trim();
    if (v.isEmpty) return '-';
    return '${v[0].toUpperCase()}${v.substring(1).toLowerCase()}';
  }

  Future<void> _editMeasurement(MeasurementEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddMeasurementScreen(
          customerId: _customer.id,
          customerGender: _customer.gender,
          measurement: entry,
        ),
      ),
    );
    ref.invalidate(customerMeasurementsProvider(_customer.id));
  }

  Future<void> _shareMeasurement(MeasurementEntry entry) async {
    final takenAt = DateFormat('dd MMM yyyy, h:mm a').format(entry.takenAt.toLocal());
    final unit = (entry.payload['unit'] ?? 'inches') as String;
    final suffix = unit == 'cm' ? 'cm' : 'in';

    final lines = <String>[
      'Oga Tailor - Measurement Record',
      'Customer: ${_customer.fullName}',
      if ((_customer.phoneNumber ?? '').isNotEmpty) 'Phone: ${_customer.phoneNumber}',
      'Taken: $takenAt',
      'Unit: ${unit == 'cm' ? 'Centimetres' : 'Inches'}',
      '',
      'Measurements:',
    ];

    final items = entry.payload.entries.where((e) => e.key != 'notes' && e.key != 'unit');
    for (final item in items) {
      lines.add('- ${_formatKey(item.key)}: ${item.value} $suffix');
    }
    final notes = (entry.payload['notes'] ?? '').toString().trim();
    if (notes.isNotEmpty) {
      lines..add('')..add('Notes: $notes');
    }

    await SharePlus.instance.share(
      ShareParams(text: lines.join('\n')),
    );
  }

  Future<void> _onMenuAction(String action, bool hasSession) async {
    if (!hasSession) {
      return;
    }

    if (action == 'edit') {
      final updated = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AddCustomerScreen(customer: _customer),
        ),
      );
      if (updated == true) {
        ref.invalidate(customersProvider);
        final refreshed = await ref.read(customersProvider.future);
        final match = refreshed.where((item) => item.id == _customer.id);
        if (match.isNotEmpty && mounted) {
          setState(() => _customer = match.first);
        }
      }
      return;
    }

    if (action == 'archive') {
      final willArchive = !_customer.isArchived;
      await ref.read(customersRepositoryProvider).archiveCustomer(
            customerId: _customer.id,
            archived: willArchive,
          );
      ref.invalidate(customersProvider);
      if (!mounted) return;
      final page = await ref.read(customersRepositoryProvider).listCustomersPage(
            limit: 1,
            offset: 0,
            query: _customer.fullName,
            archivedMode: 'all',
          );
      final match = page.items.where((item) => item.id == _customer.id);
      if (match.isNotEmpty) {
        setState(() => _customer = match.first);
      } else {
        final existingNotes = _customer.notes ?? '';
        setState(() {
          _customer = Customer(
            id: _customer.id,
            fullName: _customer.fullName,
            gender: _customer.gender,
            phoneNumber: _customer.phoneNumber,
            notes: willArchive
                ? (existingNotes.startsWith('[ARCHIVED]') ? existingNotes : '[ARCHIVED] ${existingNotes.trim()}'.trim())
                : existingNotes.replaceFirst(RegExp(r'^\[ARCHIVED\]\s*'), '').trim(),
            lastModifiedAt: _customer.lastModifiedAt,
          );
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(willArchive ? 'Customer archived' : 'Customer unarchived'),
        ),
      );
      return;
    }

    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete customer?'),
              content: const Text('This will remove the customer and all saved measurements.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
              ],
            ),
          ) ??
          false;
      if (!confirmed) {
        return;
      }

      await ref.read(customersRepositoryProvider).deleteCustomer(
            customerId: _customer.id,
          );
      ref.invalidate(customersProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }
}

class _TappablePhone extends StatelessWidget {
  const _TappablePhone({this.phoneNumber});

  final String? phoneNumber;

  @override
  Widget build(BuildContext context) {
    final hasNumber = phoneNumber != null && phoneNumber!.trim().isNotEmpty;

    if (!hasNumber) {
      return const Text('No phone number');
    }

    return GestureDetector(
      onTap: () async {
        final launched = await launchPhoneCall(phoneNumber!);
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open phone dialer')),
          );
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            phoneNumber!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
          ),
        ],
      ),
    );
  }
}
