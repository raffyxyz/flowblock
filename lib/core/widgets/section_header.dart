import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small list-section heading with an optional count and trailing control.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.trailing,
  });

  final String title;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(title, style: context.text.titleMedium),
        if (count != null) ...<Widget>[
          const SizedBox(width: AppSpace.x2),
          Text(
            '$count',
            style: context.text.labelMedium
                ?.copyWith(color: context.colors.muted),
          ),
        ],
        const Spacer(),
        if (trailing case final Widget value) value,
      ],
    );
  }
}
