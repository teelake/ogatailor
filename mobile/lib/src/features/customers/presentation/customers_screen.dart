import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/sync/offline_sync_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../plan/application/plan_controller.dart';
import '../../plan/domain/plan_summary.dart';
import '../../plan/presentation/upgrade_screen.dart';
import '../application/customers_controller.dart';
import '../domain/customer.dart';
import 'add_customer_screen.dart';
import 'customer_details_screen.dart';
import 'widgets/customer_tile.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _queryController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final planSummaryAsync = ref.watch(planSummaryProvider);
    final syncStatusAsync = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          _PlanBadge(summaryAsync: planSummaryAsync),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
          );
          ref.invalidate(customersProvider);
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Customer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _PlanUsageBanner(summaryAsync: planSummaryAsync),
            const SizedBox(height: 10),
            _SyncStatusBanner(syncStatusAsync: syncStatusAsync),
            const SizedBox(height: 10),
            TextField(
              controller: _queryController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.tune_rounded),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: customersAsync.when(
                data: (customers) {
                  if (customers.isEmpty) {
                    return const _EmptyState();
                  }

                  final filtered = _filterCustomers(customers, _query);
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final customer = filtered[index];
                      return CustomerTile(
                        customer: customer,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CustomerDetailsScreen(customer: customer),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Could not load customers: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Customer> _filterCustomers(List<Customer> customers, String query) {
    if (query.isEmpty) {
      return customers;
    }
    final q = query.toLowerCase();
    return customers
        .where(
          (customer) =>
              customer.fullName.toLowerCase().contains(q) ||
              (customer.phoneNumber ?? '').toLowerCase().contains(q),
        )
        .toList();
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({
    required this.summaryAsync,
  });

  final AsyncValue<PlanSummary?> summaryAsync;

  @override
  Widget build(BuildContext context) {
    final label = summaryAsync.valueOrNull?.isFree == false ? 'Paid Plan' : 'Free Plan';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 16, color: AppColors.accentGold),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanUsageBanner extends StatelessWidget {
  const _PlanUsageBanner({
    required this.summaryAsync,
  });

  final AsyncValue<PlanSummary?> summaryAsync;

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      data: (summary) {
        if (summary == null || !summary.isFree || summary.customerLimit == null) {
          return const SizedBox.shrink();
        }
        final limit = summary.customerLimit!;
        final used = summary.customerCount;
        final ratio = (used / limit).clamp(0, 1).toDouble();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Free Plan Usage: $used / $limit customers'),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: ratio),
                const SizedBox(height: 8),
                const Text('Upgrade for unlimited customers and cloud backup.'),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _SyncStatusBanner extends ConsumerWidget {
  const _SyncStatusBanner({
    required this.syncStatusAsync,
  });

  final AsyncValue<Map<String, dynamic>> syncStatusAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return syncStatusAsync.when(
      data: (status) {
        final state = (status['state'] ?? 'synced') as String;
        final pendingCount = (status['pending_count'] ?? 0) as int;
        final lastError = status['last_error'] as String?;

        if (state == 'synced' && pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.sync_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state == 'failed'
                        ? 'Sync failed ($pendingCount pending). ${lastError ?? ''}'
                        : 'Sync pending: $pendingCount change(s)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await ref.read(offlineSyncServiceProvider).processQueue();
                    ref.invalidate(syncStatusProvider);
                    ref.invalidate(customersProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.people_alt_outlined, color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 14),
          Text(
            'No customers yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "Add Customer" to save your first client profile.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
