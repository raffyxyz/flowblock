import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Neutral icon-plus-label pill, used for date/time/repeat meta info.
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final FlowColors colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.x3,
        vertical: AppSpace.x2,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: colors.muted),
          const SizedBox(width: AppSpace.x1),
          Text(
            label,
            style: context.text.labelMedium?.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}
