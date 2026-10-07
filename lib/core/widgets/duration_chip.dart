import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small neutral pill showing a time estimate, e.g. "25 min".
class DurationChip extends StatelessWidget {
  const DurationChip({super.key, required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final FlowColors colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.x2,
        vertical: AppSpace.x1,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.schedule, size: 14, color: colors.muted),
          const SizedBox(width: AppSpace.x1),
          Text(
            '$minutes min',
            style: context.text.labelMedium?.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}
