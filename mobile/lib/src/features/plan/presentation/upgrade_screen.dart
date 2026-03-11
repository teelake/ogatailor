import 'package:flutter/material.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Plan')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Grow Your Tailoring Business', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            const Text(
              'Starter includes up to 50 customers. Upgrade for cloud backup, export, multi-device, and higher limits.',
            ),
            const SizedBox(height: 16),
            const _PlanCard(
              title: 'Starter (Free)',
              points: [
                'Up to 50 customers',
                'Offline usage',
                'Basic due-date reminders',
              ],
            ),
            const SizedBox(height: 10),
            const _PlanCard(
              title: 'Growth',
              points: [
                'Up to 500 customers',
                'Cloud backup & restore',
                'Measurement export',
              ],
            ),
            const SizedBox(height: 10),
            const _PlanCard(
              title: 'Pro',
              points: [
                'Unlimited customers',
                'Multi-device access',
                'Advanced reminder options',
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment integration comes in next phase.')),
                );
              },
              child: const Text('Upgrade Now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.title, required this.points});

  final String title;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final point in points) Text('• $point'),
          ],
        ),
      ),
    );
  }
}
