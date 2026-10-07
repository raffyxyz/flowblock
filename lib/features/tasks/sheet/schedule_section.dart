import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_header.dart';

/// Date and time pickers for the task form sheet.
class ScheduleSection extends StatelessWidget {
  const ScheduleSection({
    super.key,
    required this.date,
    required this.time,
    required this.onPickDate,
    required this.onPickTime,
  });

  final DateTime date;
  final TimeOfDay? time;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: 'Schedule'),
        const SizedBox(height: AppSpace.x2),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(DateFormat('EEE, MMM d').format(date)),
              ),
            ),
            const SizedBox(width: AppSpace.x2),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickTime,
                icon: const Icon(Icons.schedule),
                label: Text(
                  time == null ? 'No time' : time!.format(context),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
