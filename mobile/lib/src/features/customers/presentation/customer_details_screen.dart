import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit customer')),
              PopupMenuItem(value: 'archive', child: Text('Archive customer')),
              PopupMenuItem(value: 'delete', child: Text('Delete customer')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => AddMeasurementScreen(customerId: _customer.id),
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
                    Text(_customer.phoneNumber ?? 'No phone number'),
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
                                Text(when, style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: entry.payload.entries.map((item) {
                                    return Chip(label: Text('${item.key}: ${item.value}'));
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

  Future<void> _editMeasurement(MeasurementEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddMeasurementScreen(
          customerId: _customer.id,
          measurement: entry,
        ),
      ),
    );
    ref.invalidate(customerMeasurementsProvider(_customer.id));
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
      await ref.read(customersRepositoryProvider).archiveCustomer(
            customerId: _customer.id,
            archived: true,
          );
      ref.invalidate(customersProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
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
