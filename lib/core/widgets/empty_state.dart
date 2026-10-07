import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Friendly placeholder for lists with nothing to show.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final FlowColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.x4,
        vertical: AppSpace.x8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accentSoft,
            ),
            child: Icon(icon, size: 28, color: colors.accent),
          ),
          const SizedBox(height: AppSpace.x4),
          Text(
            title,
            style: context.text.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.x1),
          Text(
            subtitle,
            style:
                context.text.bodyMedium?.copyWith(color: colors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
