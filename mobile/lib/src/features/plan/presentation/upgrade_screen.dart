import 'package:flutter/material.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade to Paid Plan')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Protect Your Business Data', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            const Text(
              'Upgrade to unlock cloud backup, restore on new phone, unlimited customers, export, and multiple devices.',
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paid Plan Includes:'),
                    SizedBox(height: 8),
                    Text('• Cloud backup & restore'),
                    Text('• Unlimited customers'),
                    Text('• Measurement export'),
                    Text('• Multi-device access'),
                  ],
                ),
              ),
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
