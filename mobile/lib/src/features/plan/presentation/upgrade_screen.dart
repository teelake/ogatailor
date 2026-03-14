import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/plan_controller.dart';
import '../data/plan_repository.dart';
import '../domain/plan_tier.dart';

class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  List<PlanTier>? _plans;
  String? _error;
  bool _loading = true;
  String? _upgradingPlan;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(planRepositoryProvider);
      final plans = await repo.fetchPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _upgrade(PlanTier plan) async {
    if (!plan.isUpgrade) return;
    setState(() => _upgradingPlan = plan.planCode);
    try {
      final repo = ref.read(planRepositoryProvider);
      final result = await repo.initializeUpgrade(plan.planCode);
      final url = result['authorization_url'];
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            ref.invalidate(planSummaryProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Complete payment in the browser. Return here after payment.',
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open payment page')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment link not available')),
          );
        }
      }
    } catch (e) {
      final msg = e.toString();
      final friendly = msg.contains('503') || msg.contains('not configured')
          ? 'Payment is not configured yet. Please contact support.'
          : msg.contains('422') && msg.contains('Email')
              ? 'Add your email in Profile before upgrading.'
              : 'Could not start payment. Try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendly)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _upgradingPlan = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final planSummary = ref.watch(planSummaryProvider).valueOrNull;
    final currentPlan = planSummary?.planCode ?? 'starter';

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Plan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPlans,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _plans == null || _plans!.isEmpty
                  ? const Center(child: Text('No plans available'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Grow Your Tailoring Business',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Plans are configured by your platform. Upgrade for cloud backup, export, multi-device, and higher limits.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          ..._plans!.map((plan) {
                            final isCurrent = plan.planCode == currentPlan;
                            final canUpgrade = plan.isUpgrade &&
                                (plan.planCode == 'pro' ||
                                    (plan.planCode == 'growth' &&
                                        currentPlan == 'starter'));
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PlanCard(
                                plan: plan,
                                isCurrentPlan: isCurrent,
                                onUpgrade: canUpgrade
                                    ? () => _upgrade(plan)
                                    : null,
                                isLoading:
                                    _upgradingPlan == plan.planCode,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrentPlan,
    this.onUpgrade,
    required this.isLoading,
  });

  final PlanTier plan;
  final bool isCurrentPlan;
  final VoidCallback? onUpgrade;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan.displayName +
                      (plan.isFree ? ' (Free)' : ''),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!plan.isFree)
                  Text(
                    '₦${plan.priceNgn.toStringAsFixed(0)}/mo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
              ],
            ),
            if (plan.customerLimitLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                plan.customerLimitLabel + ' customers',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            ...plan.features.map((f) => Text('• $f')),
            if (onUpgrade != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onUpgrade,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Upgrade Now'),
                ),
              ),
            ] else if (isCurrentPlan) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Current plan',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
