import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/application/auth_controller.dart';
import '../../customers/application/customers_controller.dart';
import '../application/orders_controller.dart';
import '../data/orders_repository.dart';
import '../domain/order_entry.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _statusFilter = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final statusFilters = const ['all', 'pending', 'in_progress', 'ready', 'delivered', 'cancelled'];

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: session == null
            ? null
            : () async {
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const _CreateOrderSheet(),
                );
                ref.invalidate(ordersProvider);
              },
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New Order'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search by order title or customer',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: statusFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final status = statusFilters[index];
                  final selected = status == _statusFilter;
                  return ChoiceChip(
                    label: Text(status == 'all' ? 'All' : status),
                    selected: selected,
                    onSelected: (_) => setState(() => _statusFilter = status),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ordersAsync.when(
                data: (orders) {
                  var filtered = _statusFilter == 'all'
                      ? orders
                      : orders.where((item) => item.status == _statusFilter).toList();
                  if (_searchQuery.isNotEmpty) {
                    filtered = filtered
                        .where(
                          (item) =>
                              item.title.toLowerCase().contains(_searchQuery) ||
                              item.customerName.toLowerCase().contains(_searchQuery),
                        )
                        .toList();
                  }
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No orders for this filter.'));
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => _OrderCard(order: filtered[index]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Could not load orders: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final OrderEntry order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final statuses = const ['pending', 'in_progress', 'ready', 'delivered', 'cancelled'];

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _OrderDetailsScreen(order: order),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(order.title, style: Theme.of(context).textTheme.titleMedium)),
                  _StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 4),
              Text('Customer: ${order.customerName}'),
              const SizedBox(height: 4),
              Text('Amount: ₦${order.amountTotal.toStringAsFixed(2)}'),
              if (order.dueDate != null) ...[
                const SizedBox(height: 4),
                Text('Due: ${DateFormat('dd MMM yyyy').format(order.dueDate!.toLocal())}'),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: statuses.contains(order.status) ? order.status : 'pending',
                decoration: const InputDecoration(labelText: 'Status'),
                items: statuses
                    .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                    .toList(),
                onChanged: session == null
                    ? null
                    : (value) async {
                        if (value == null || value == order.status) return;
                        await ref.read(ordersRepositoryProvider).updateStatus(
                              orderId: order.id,
                              status: value,
                            );
                        ref.invalidate(ordersProvider);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateOrderSheet extends ConsumerStatefulWidget {
  const _CreateOrderSheet();

  @override
  ConsumerState<_CreateOrderSheet> createState() => _CreateOrderSheetState();
}

class _CreateOrderSheetState extends ConsumerState<_CreateOrderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedCustomerId;
  DateTime? _selectedDueDate;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: customersAsync.when(
        data: (customers) => Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Create Order', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCustomerId,
                decoration: const InputDecoration(labelText: 'Customer'),
                items: customers
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.fullName)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCustomerId = value),
                validator: (value) => value == null ? 'Select customer' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Order title'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Order title is required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount (NGN)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final n = double.tryParse((value ?? '').trim());
                  if (n == null) return 'Enter a valid amount';
                  if (n < 0) return 'Amount cannot be negative';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due date'),
                subtitle: Text(
                  _selectedDueDate == null
                      ? 'No due date'
                      : DateFormat('dd MMM yyyy').format(_selectedDueDate!.toLocal()),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.date_range_rounded),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: _selectedDueDate ?? DateTime.now(),
                    );
                    if (picked != null && mounted) {
                      setState(() => _selectedDueDate = picked);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) {
                          return;
                        }
                        setState(() => _saving = true);
                        try {
                          await ref.read(ordersRepositoryProvider).createOrder(
                                customerId: _selectedCustomerId!,
                                title: _titleController.text.trim(),
                                status: 'pending',
                                amountTotal: double.parse(_amountController.text.trim()),
                                notes: _notesController.text.trim().isEmpty
                                    ? null
                                    : _notesController.text.trim(),
                                dueDate: _selectedDueDate,
                              );
                          if (!mounted) return;
                          Navigator.of(context).pop();
                        } catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Could not create order: $error')));
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: Text(_saving ? 'Saving...' : 'Save Order'),
              ),
            ],
          ),
        ),
        loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
        error: (error, _) => SizedBox(
          height: 160,
          child: Center(child: Text('Could not load customers: $error')),
        ),
      ),
    );
  }
}

class _OrderDetailsScreen extends ConsumerWidget {
  const _OrderDetailsScreen({required this.order});

  final OrderEntry order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final statuses = const ['pending', 'in_progress', 'ready', 'delivered', 'cancelled'];

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    _StatusBadge(status: order.status),
                    const SizedBox(height: 6),
                    Text('Customer: ${order.customerName}'),
                    const SizedBox(height: 6),
                    Text('Amount: ₦${order.amountTotal.toStringAsFixed(2)}'),
                    const SizedBox(height: 6),
                    Text(
                      'Due date: ${order.dueDate == null ? 'No due date' : DateFormat('dd MMM yyyy').format(order.dueDate!.toLocal())}',
                    ),
                    if ((order.notes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Notes: ${order.notes}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: statuses.contains(order.status) ? order.status : 'pending',
              decoration: const InputDecoration(labelText: 'Update status'),
              items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: session == null
                  ? null
                  : (value) async {
                      if (value == null || value == order.status) return;
                      await ref.read(ordersRepositoryProvider).updateStatus(
                            orderId: order.id,
                            status: value,
                          );
                      ref.invalidate(ordersProvider);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order status updated')),
                      );
                    },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: session == null
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                        initialDate: order.dueDate ?? DateTime.now(),
                      );
                      if (picked == null) return;
                      await ref.read(ordersRepositoryProvider).updateDueDate(
                            orderId: order.id,
                            dueDate: picked,
                          );
                      ref.invalidate(ordersProvider);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Due date updated')),
                      );
                    },
              icon: const Icon(Icons.edit_calendar_rounded),
              label: const Text('Edit Due Date'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'pending' => Colors.orange,
      'in_progress' => Colors.blue,
      'ready' => Colors.teal,
      'delivered' => Colors.green,
      'cancelled' => Colors.red,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
