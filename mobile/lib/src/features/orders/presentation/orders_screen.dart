import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../customers/application/customers_controller.dart';
import '../../customers/domain/customer.dart';
import '../../../core/network/api_client.dart';
import '../../config/application/config_controller.dart';
import '../../invoice/data/invoice_repository.dart';
import '../../invoice/presentation/invoice_pdf_builder.dart';
import '../../invoice/presentation/invoice_preview_widget.dart';
import '../../invoice/presentation/invoice_setup_screen.dart';
import '../../plan/application/plan_controller.dart';
import '../application/orders_controller.dart';
import '../data/orders_repository.dart';
import '../domain/order_entry.dart';

const _kRecentOrderCustomers = 'recent_order_customers';
const _kRecentOrderCustomersMax = 8;

String _formatOrderStatus(String status) {
  return switch (status) {
    'in_progress' => 'In Progress',
    'pending' => 'Pending',
    'ready' => 'Ready',
    'delivered' => 'Delivered',
    'cancelled' => 'Cancelled',
    _ => status,
  };
}

DateTime _todayStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

bool _isPastDate(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.isBefore(_todayStart());
}

bool _isDueToday(DateTime? due) {
  if (due == null) return false;
  final d = DateTime(due.year, due.month, due.day);
  return d == _todayStart();
}

bool _isUpcomingInDays(DateTime? due, int days) {
  if (due == null) return false;
  final d = DateTime(due.year, due.month, due.day);
  final today = _todayStart();
  final end = today.add(Duration(days: days));
  return !d.isBefore(today) && !d.isAfter(end);
}

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _statusFilter = 'all';
  String _searchQuery = '';
  final Map<String, String> _statusOverrides = {};

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
                    label: Text(status == 'all' ? 'All' : _formatOrderStatus(status)),
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
                  String effectiveStatus(OrderEntry order) => _statusOverrides[order.id] ?? order.status;
                  final activeOrders = orders.where((o) => effectiveStatus(o) != 'delivered' && effectiveStatus(o) != 'cancelled').toList();
                  final dueToday = activeOrders.where((o) => _isDueToday(o.dueDate)).toList();

                  var filtered = _statusFilter == 'all'
                      ? orders
                      : orders.where((item) => effectiveStatus(item) == _statusFilter).toList();
                  if (_searchQuery.isNotEmpty) {
                    filtered = filtered
                        .where(
                          (item) =>
                              item.title.toLowerCase().contains(_searchQuery) ||
                              item.customerName.toLowerCase().contains(_searchQuery),
                        )
                        .toList();
                  }
                  return CustomScrollView(
                    slivers: [
                      if (dueToday.isNotEmpty && _statusFilter == 'all') ...[
                        SliverToBoxAdapter(
                          child: Card(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.today_rounded, color: Theme.of(context).colorScheme.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Due today (${dueToday.length})',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...dueToday.map((order) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '• ${order.title} — ${order.customerName}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      ],
                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: Icons.assignment_outlined,
                            title: orders.isEmpty ? 'No orders yet' : 'No orders match your filter',
                            tip: orders.isEmpty
                                ? 'Tap the + button to create your first order'
                                : 'Try a different status or search term',
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final order = filtered[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _OrderCard(
                                  order: order,
                                  displayedStatus: effectiveStatus(order),
                                  onStatusChanged: (nextStatus) {
                                    setState(() => _statusOverrides[order.id] = nextStatus);
                                    ref.invalidate(ordersProvider);
                                  },
                                ),
                              );
                            },
                            childCount: filtered.length,
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    userFriendlyError(
                      error,
                      fallback: 'Could not load orders. Please try again.',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({
    required this.order,
    required this.displayedStatus,
    required this.onStatusChanged,
  });

  final OrderEntry order;
  final String displayedStatus;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _OrderDetailsScreen(order: order),
            ),
          );
          ref.invalidate(ordersProvider);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(order.title, style: Theme.of(context).textTheme.titleMedium)),
                  _StatusBadge(status: displayedStatus),
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
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _showStatusPicker(
                    context,
                    ref,
                    currentStatus: displayedStatus,
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Change status'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showStatusPicker(
    BuildContext context,
    WidgetRef ref, {
    required String currentStatus,
  }) async {
    final statuses = const ['pending', 'in_progress', 'ready', 'delivered', 'cancelled'];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Update status', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: statuses
                  .map(
                    (status) => ChoiceChip(
                      label: Text(_formatOrderStatus(status)),
                      selected: status == currentStatus,
                      onSelected: (_) => Navigator.of(context).pop(status),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (chosen == null || chosen == currentStatus) return;
    onStatusChanged(chosen);
    try {
      await ref.read(ordersRepositoryProvider).updateStatus(
            orderId: order.id,
            status: chosen,
            lastKnownModifiedAt: order.lastModifiedAt,
          );
    } catch (error) {
      onStatusChanged(currentStatus);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFriendlyError(
              error,
              fallback: 'Could not update order status. Please try again.',
            ),
          ),
        ),
      );
    }
  }
}

class _CreateOrderSheet extends ConsumerStatefulWidget {
  const _CreateOrderSheet();

  @override
  ConsumerState<_CreateOrderSheet> createState() => _CreateOrderSheetState();
}

class _CreateOrderSheetState extends ConsumerState<_CreateOrderSheet> {
  static const _pageSize = 30;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  DateTime? _selectedDueDate;
  bool _allowPastDueDate = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_prefillMostRecentCustomer);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('Create Order', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Customer'),
              subtitle: Text(_selectedCustomerName ?? 'Tap to search and select a customer'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _saving ? null : _openCustomerPicker,
            ),
            if (_selectedCustomerId == null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Customer is required',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
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
                    firstDate: _allowPastDueDate ? DateTime.now().subtract(const Duration(days: 3650)) : _todayStart(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDate: _selectedDueDate ?? DateTime.now(),
                  );
                  if (picked != null && mounted) {
                    setState(() => _selectedDueDate = picked);
                  }
                },
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Order is already overdue'),
              subtitle: const Text('Allow selecting a past due date'),
              value: _allowPastDueDate,
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() => _allowPastDueDate = value);
                    },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) {
                        return;
                      }
                      if (_selectedCustomerId == null) {
                        setState(() {});
                        return;
                      }
                      if (_selectedDueDate != null &&
                          _isPastDate(_selectedDueDate!) &&
                          !_allowPastDueDate) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Due date cannot be in the past.')),
                        );
                        return;
                      }
                      setState(() => _saving = true);
                      try {
                        final queuedOffline = await ref.read(ordersRepositoryProvider).createOrder(
                              customerId: _selectedCustomerId!,
                              title: _titleController.text.trim(),
                              status: 'pending',
                              amountTotal: double.parse(_amountController.text.trim()),
                              notes: _notesController.text.trim().isEmpty
                                  ? null
                                  : _notesController.text.trim(),
                              dueDate: _selectedDueDate,
                              allowPastDueDate: _allowPastDueDate,
                            );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              queuedOffline
                                  ? 'Saved offline. It will sync when internet is back.'
                                  : 'Order created successfully.',
                            ),
                          ),
                        );
                        Navigator.of(context).pop();
                      } catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              userFriendlyError(
                                error,
                                fallback: 'Could not create order. Please try again.',
                              ),
                            ),
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: Text(_saving ? 'Saving...' : 'Save Order'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCustomerPicker() async {
    final selected = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CustomerPickerSheet(pageSize: _pageSize),
    );
    if (selected == null || !mounted) return;
    await _saveRecentCustomer(selected);
    setState(() {
      _selectedCustomerId = selected.id;
      _selectedCustomerName = selected.fullName;
    });
  }

  Future<void> _saveRecentCustomer(Customer customer) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRecentOrderCustomers);
    final decoded = raw == null || raw.isEmpty ? <dynamic>[] : (jsonDecode(raw) as List<dynamic>);
    final rows = decoded
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .where((m) => (m['id'] ?? '').toString().isNotEmpty)
        .toList();

    rows.removeWhere((m) => (m['id'] ?? '').toString() == customer.id);
    rows.insert(0, {
      'id': customer.id,
      'full_name': customer.fullName,
      'phone_number': customer.phoneNumber,
    });
    if (rows.length > _kRecentOrderCustomersMax) {
      rows.removeRange(_kRecentOrderCustomersMax, rows.length);
    }
    await prefs.setString(_kRecentOrderCustomers, jsonEncode(rows));
  }

  Future<void> _prefillMostRecentCustomer() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRecentOrderCustomers);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.isEmpty) return;
    final first = decoded.first;
    if (first is! Map) return;
    final map = Map<String, dynamic>.from(first);
    final id = (map['id'] ?? '').toString();
    final name = (map['full_name'] ?? '').toString();
    if (id.isEmpty || name.isEmpty || !mounted) return;
    setState(() {
      _selectedCustomerId = id;
      _selectedCustomerName = name;
    });
  }
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet({required this.pageSize});

  final int pageSize;

  @override
  ConsumerState<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _offset = 0;
  List<Customer> _items = const [];
  List<Customer> _recent = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadRecent();
      await _loadInitial();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Select Customer', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search customer by name or phone',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
                onSubmitted: (_) => _loadInitial(),
              ),
              const SizedBox(height: 10),
              if (_query.isEmpty && _recent.isNotEmpty) ...[
                Text('Recent customers', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recent
                      .map(
                        (c) => ActionChip(
                          avatar: const Icon(Icons.history_rounded, size: 16),
                          label: Text(c.fullName),
                          onPressed: () => Navigator.of(context).pop(c),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loadInitial,
                  child: const Text('Search'),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                        ? EmptyState(
                            icon: Icons.person_search_rounded,
                            title: 'No customers found',
                            tip: 'Try a different search term, or add a customer first',
                            compact: true,
                          )
                        : ListView.separated(
                            itemCount: _items.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (_, index) {
                              if (index == _items.length) {
                                if (_loadingMore) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                if (!_hasMore) {
                                  return const SizedBox.shrink();
                                }
                                return Center(
                                  child: OutlinedButton(
                                    onPressed: _loadMore,
                                    child: const Text('Load more'),
                                  ),
                                );
                              }
                              final customer = _items[index];
                              return Card(
                                child: ListTile(
                                  title: Text(customer.fullName),
                                  subtitle: Text(customer.phoneNumber ?? 'No phone'),
                                  onTap: () => Navigator.of(context).pop(customer),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _offset = 0;
    });
    try {
      final page = await ref.read(customersRepositoryProvider).listCustomersPage(
            limit: widget.pageSize,
            offset: 0,
            query: _query,
          );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _hasMore = page.hasMore;
        _offset = page.items.length;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(customersRepositoryProvider).listCustomersPage(
            limit: widget.pageSize,
            offset: _offset,
            query: _query,
          );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.items];
        _hasMore = page.hasMore;
        _offset += page.items.length;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRecentOrderCustomers);
    if (raw == null || raw.isEmpty) {
      if (mounted) setState(() => _recent = const []);
      return;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      if (mounted) setState(() => _recent = const []);
      return;
    }
    final rows = decoded
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .where((m) => (m['id'] ?? '').toString().isNotEmpty)
        .take(_kRecentOrderCustomersMax)
        .toList();
    if (!mounted) return;
    setState(() {
      _recent = rows
          .map(
            (m) => Customer(
              id: (m['id'] ?? '').toString(),
              fullName: (m['full_name'] ?? '').toString(),
              gender: 'other',
              phoneNumber: (m['phone_number'] ?? '').toString().isEmpty ? null : (m['phone_number'] ?? '').toString(),
            ),
          )
          .toList();
    });
  }
}

class _OrderDetailsScreen extends ConsumerStatefulWidget {
  const _OrderDetailsScreen({required this.order});

  final OrderEntry order;

  @override
  ConsumerState<_OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<_OrderDetailsScreen> {
  late String _status;
  late DateTime? _dueDate;
  bool _allowPastDueDate = false;

  @override
  void initState() {
    super.initState();
    _status = widget.order.status;
    _dueDate = widget.order.dueDate;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final planSummary = ref.watch(planSummaryProvider).valueOrNull;
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
                    Text(widget.order.title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    _StatusBadge(status: _status),
                    const SizedBox(height: 6),
                    Text('Customer: ${widget.order.customerName}'),
                    const SizedBox(height: 6),
                    Text('Amount: ₦${widget.order.amountTotal.toStringAsFixed(2)}'),
                    const SizedBox(height: 6),
                    Text(
                      'Due date: ${_dueDate == null ? 'No due date' : DateFormat('dd MMM yyyy').format(_dueDate!.toLocal())}',
                    ),
                    if ((widget.order.notes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Notes: ${widget.order.notes}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Update status', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: statuses
                  .map(
                    (status) => ChoiceChip(
                      label: Text(_formatOrderStatus(status)),
                      selected: status == _status,
                      onSelected: session == null
                          ? null
                          : (_) async {
                              if (status == _status) return;
                              final previous = _status;
                              setState(() => _status = status);
                              try {
                                await ref.read(ordersRepositoryProvider).updateStatus(
                                      orderId: widget.order.id,
                                      status: status,
                                      lastKnownModifiedAt: widget.order.lastModifiedAt,
                                    );
                                ref.invalidate(ordersProvider);
                              } catch (error) {
                                setState(() => _status = previous);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      userFriendlyError(
                                        error,
                                        fallback: 'Could not update order status. Please try again.',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow past due date'),
              subtitle: const Text('Enable only when fixing an overdue order'),
              value: _allowPastDueDate,
              onChanged: session == null ? null : (value) => setState(() => _allowPastDueDate = value),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: session == null
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: _allowPastDueDate
                            ? DateTime.now().subtract(const Duration(days: 3650))
                            : _todayStart(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                        initialDate: _dueDate ?? DateTime.now(),
                      );
                      if (picked == null) return;
                      if (_isPastDate(picked) && !_allowPastDueDate) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Due date cannot be in the past.')),
                        );
                        return;
                      }
                      try {
                        setState(() => _dueDate = picked);
                        await ref.read(ordersRepositoryProvider).updateDueDate(
                              orderId: widget.order.id,
                              dueDate: picked,
                              lastKnownModifiedAt: widget.order.lastModifiedAt,
                              allowPastDueDate: _allowPastDueDate,
                            );
                        ref.invalidate(ordersProvider);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Due date updated')),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              userFriendlyError(
                                error,
                                fallback: 'Could not update due date. Please try again.',
                              ),
                            ),
                          ),
                        );
                        setState(() => _dueDate = widget.order.dueDate);
                      }
                    },
              icon: const Icon(Icons.edit_calendar_rounded),
              label: const Text('Edit Due Date'),
            ),
            if (planSummary?.hasInvoiceLimit == true) ...[
              const SizedBox(height: 12),
              Card(
                color: planSummary!.isAtInvoiceLimit
                    ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.3)
                    : planSummary.isNearInvoiceLimit
                        ? Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.5)
                        : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        planSummary.isAtInvoiceLimit ? Icons.info_outline_rounded : Icons.receipt_rounded,
                        size: 20,
                        color: planSummary.isAtInvoiceLimit
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          planSummary.isAtInvoiceLimit
                              ? 'Invoice limit reached (${planSummary.invoicesPerMonth}/month). Upgrade for more.'
                              : 'Invoices this month: ${planSummary.invoicesUsedThisMonth} / ${planSummary.invoicesPerMonth}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: session == null || (planSummary?.isAtInvoiceLimit ?? false)
                  ? null
                  : () => _showInvoiceFlow(context),
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Generate Invoice'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInvoiceFlow(BuildContext context) async {
    final repo = ref.read(invoiceRepositoryProvider);
    try {
      await repo.generateFromOrder(widget.order.id);
      ref.invalidate(planSummaryProvider);
    } catch (e) {
      final err = userFriendlyError(e, fallback: 'Could not generate invoice.');
      if (err.contains('Complete invoice setup') && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            action: SnackBarAction(
              label: 'Setup',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InvoiceSetupScreen()),
                );
              },
            ),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }
    if (!context.mounted) return;
    Map<String, dynamic> invoice;
    try {
      invoice = await repo.getByOrderId(widget.order.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyError(e, fallback: 'Could not load invoice.'))),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final config = ref.read(appConfigProvider).valueOrNull;
    final currencySymbols = config?.currencies != null
        ? {for (var c in config!.currencies) c.code.toUpperCase(): c.symbol}
        : null;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _InvoiceShareSheet(invoice: invoice, dio: ref.read(dioProvider), currencySymbols: currencySymbols),
    );
  }
}

class _InvoiceShareSheet extends StatefulWidget {
  const _InvoiceShareSheet({required this.invoice, required this.dio, this.currencySymbols});

  final Map<String, dynamic> invoice;
  final Dio dio;
  final Map<String, String>? currencySymbols;

  @override
  State<_InvoiceShareSheet> createState() => _InvoiceShareSheetState();
}

class _InvoiceShareSheetState extends State<_InvoiceShareSheet> {
  final _previewKey = GlobalKey();

  Map<String, dynamic> get invoice => widget.invoice;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share Invoice', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Choose how to share with your customer'),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _previewKey,
              child: InvoicePreviewWidget(invoice: invoice, width: MediaQuery.of(context).size.width - 48, currencySymbols: widget.currencySymbols),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sharePdf(context),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareImage(context),
                    icon: const Icon(Icons.image_rounded),
                    label: const Text('Image'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final bytes = await buildInvoicePdf(invoice, dio: widget.dio, currencySymbols: widget.currencySymbols);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/invoice_${invoice['invoice_number'] ?? 'inv'}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Invoice from your tailor');
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyError(e, fallback: 'Could not create PDF.'))),
        );
      }
    }
  }

  Future<void> _shareImage(BuildContext context) async {
    try {
      final bytes = await _captureInvoiceImage();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/invoice_${invoice['invoice_number'] ?? 'inv'}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Invoice from your tailor');
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyError(e, fallback: 'Could not create image.'))),
        );
      }
    }
  }

  Future<Uint8List?> _captureInvoiceImage() async {
    final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
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
        _formatOrderStatus(status),
        style: TextStyle(
          color: color.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
