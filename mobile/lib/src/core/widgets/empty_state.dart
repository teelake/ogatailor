import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reusable empty state with icon, title, tip, and optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.tip,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? tip;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 56 : 72,
              height: compact ? 56 : 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(compact ? 16 : 24),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: compact ? 28 : 34,
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (tip != null) ...[
              SizedBox(height: compact ? 4 : 6),
              Text(
                tip!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: compact ? 12 : 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
