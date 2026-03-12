import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/sync/offline_sync_service.dart';
import '../../../core/utils/error_message.dart';
import '../../plan/application/plan_controller.dart';
import '../../plan/domain/plan_summary.dart';
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
  static const _pageSize = 50;
  final _queryController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _offset = 0;
  int _total = 0;
  String? _error;
  List<Customer> _items = const [];
  String _alphaFilter = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(_reload);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          await _reload();
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
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _alphaOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, index) {
                  final option = _alphaOptions[index];
                  final selected = option == _alphaFilter;
                  return ChoiceChip(
                    label: Text(option.toUpperCase()),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _alphaFilter = option);
                      _reload();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _queryController,
              onChanged: (value) {
                _query = value.trim();
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 350), _reload);
              },
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
              child: _buildCustomersList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomersList() {
    if (_loadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load customers: $_error'),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _reload, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const _EmptyState();
    }

    return ListView.separated(
      itemCount: _items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          if (_loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!_hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'Showing ${_items.length} of $_total customers',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          }
          return Center(
            child: OutlinedButton.icon(
              onPressed: _loadMore,
              icon: const Icon(Icons.expand_more_rounded),
              label: const Text('Load more'),
            ),
          );
        }
        final customer = _items[index];
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
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _loadingInitial = true;
      _error = null;
      _offset = 0;
    });
    try {
      final query = _query.trim().toLowerCase();
      final startsWith = _alphaFilter == 'all' ? '' : _alphaFilter.toLowerCase();
      final useLocalFilteredMode = query.isNotEmpty || startsWith.isNotEmpty;

      if (useLocalFilteredMode) {
        final all = await ref.read(customersRepositoryProvider).listCustomers();
        final filtered = all.where((customer) {
          final name = customer.fullName.toLowerCase();
          final phone = (customer.phoneNumber ?? '').toLowerCase();
          final matchesQuery = query.isEmpty || name.contains(query) || phone.contains(query);
          final matchesAlpha = startsWith.isEmpty || name.startsWith(startsWith);
          return matchesQuery && matchesAlpha;
        }).toList();

        if (!mounted) return;
        setState(() {
          _items = filtered;
          _total = filtered.length;
          _hasMore = false;
          _offset = filtered.length;
        });
        return;
      }

      final page = await ref.read(customersRepositoryProvider).listCustomersPage(
            limit: _pageSize,
            offset: 0,
          );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _total = page.total;
        _hasMore = page.hasMore;
        _offset = page.items.length;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFriendlyError(
          error,
          fallback: 'Could not load customers. Please try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    if (_query.trim().isNotEmpty || _alphaFilter != 'all') return;
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(customersRepositoryProvider).listCustomersPage(
            limit: _pageSize,
            offset: _offset,
            query: _query.trim(),
            startsWith: _alphaFilter == 'all' ? null : _alphaFilter,
          );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.items];
        _total = page.total;
        _hasMore = page.hasMore;
        _offset += page.items.length;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }
}

const _alphaOptions = [
  'all',
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'j',
  'k',
  'l',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z',
];

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({
    required this.summaryAsync,
  });

  final AsyncValue<PlanSummary?> summaryAsync;

  @override
  Widget build(BuildContext context) {
    final summary = summaryAsync.valueOrNull;
    final label = summary?.displayName ?? 'Starter';
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
        if (summary == null || !summary.isStarter || summary.customerLimit == null) {
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
                Text('Starter Plan Usage: $used / $limit customers'),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: ratio),
                const SizedBox(height: 8),
                const Text('Upgrade to Growth/Pro for more customers and cloud backup.'),
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
        final conflictCount = (status['conflict_count'] ?? 0) as int;
        final lastError = status['last_error'] as String?;

        if (state == 'synced' && pendingCount == 0 && conflictCount == 0) {
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
                    state == 'conflict'
                        ? 'Sync conflict: $conflictCount item(s) need review.'
                        : state == 'failed'
                            ? 'Sync failed ($pendingCount pending). ${lastError ?? ''}'
                            : 'Sync pending: $pendingCount change(s)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    if (state == 'conflict') {
                      final conflicts = await ref.read(syncConflictsProvider.future);
                      if (!context.mounted) return;
                      await showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Sync Conflicts'),
                          content: SizedBox(
                            width: 360,
                            child: ListView(
                              shrinkWrap: true,
                              children: conflicts
                                  .map(
                                    (c) => ListTile(
                                      dense: true,
                                      title: Text('${c['method']} ${c['path']}'),
                                      subtitle: Text(
                                        ((c['server'] as Map?)?['message'] ?? 'Server has newer data').toString(),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                            FilledButton(
                              onPressed: () async {
                                await ref.read(offlineSyncServiceProvider).clearConflicts();
                                ref.invalidate(syncStatusProvider);
                                if (context.mounted) Navigator.of(context).pop();
                              },
                              child: const Text('Mark reviewed'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      await ref.read(offlineSyncServiceProvider).processQueue();
                      ref.invalidate(syncStatusProvider);
                      ref.invalidate(customersProvider);
                    }
                  },
                  child: Text(state == 'conflict' ? 'Review' : 'Retry'),
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
