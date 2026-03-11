import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/phone_launcher.dart';
import '../../domain/customer.dart';

class CustomerTile extends StatelessWidget {
  const CustomerTile({
    super.key,
    required this.customer,
    this.onTap,
  });

  final Customer customer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Text(
                  customer.fullName.isNotEmpty ? customer.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    _PhoneText(phoneNumber: customer.phoneNumber),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneText extends StatelessWidget {
  const _PhoneText({this.phoneNumber});

  final String? phoneNumber;

  @override
  Widget build(BuildContext context) {
    final hasNumber = phoneNumber != null && phoneNumber!.trim().isNotEmpty;

    if (!hasNumber) {
      return Text(
        'No phone number',
        style: Theme.of(context).textTheme.bodyMedium,
      );
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
          Icon(Icons.phone_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
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
