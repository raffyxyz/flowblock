import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/weekday_selector.dart';
import '../../../domain/models/task_item.dart';
import 'option_chip.dart';

String recurrenceName(RecurrenceType option) {
  switch (option) {
    case RecurrenceType.once:
      return 'Once';
    case RecurrenceType.daily:
      return 'Daily';
    case RecurrenceType.weekly:
      return 'Weekly';
    case RecurrenceType.monthly:
      return 'Monthly';
  }
}

/// Repeat selector for the task form sheet, with weekday circles for weekly.
class RepeatSection extends StatelessWidget {
  const RepeatSection({
    super.key,
    required this.recurrence,
    required this.weekdays,
    required this.onRecurrence,
    required this.onToggleDay,
  });

  final RecurrenceType recurrence;
  final Set<int> weekdays;
  final ValueChanged<RecurrenceType> onRecurrence;
  final ValueChanged<int> onToggleDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: 'Repeat'),
        const SizedBox(height: AppSpace.x2),
        Wrap(
          spacing: AppSpace.x2,
          runSpacing: AppSpace.x2,
          children: <Widget>[
            for (final RecurrenceType option in RecurrenceType.values)
              OptionChip(
                label: recurrenceName(option),
                selected: recurrence == option,
                onTap: () => onRecurrence(option),
              ),
          ],
        ),
        if (recurrence == RecurrenceType.weekly) ...<Widget>[
          const SizedBox(height: AppSpace.x3),
          WeekdaySelector(
            selected: weekdays,
            onToggle: onToggleDay,
          ),
        ],
      ],
    );
  }
}
