import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Weekday toggle circles (Monday-first, ISO 1..7) for weekly recurrence.
class WeekdaySelector extends StatelessWidget {
  const WeekdaySelector({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  static const List<String> _short = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S'
  ];
  static const List<String> _names = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  Widget build(BuildContext context) {
    final FlowColors colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        for (int day = 1; day <= 7; day++)
          Semantics(
            button: true,
            selected: selected.contains(day),
            label: _names[day - 1],
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onToggle(day),
              child: SizedBox(
                width: AppSpace.x12,
                height: AppSpace.x12,
                child: Center(
                  child: AnimatedContainer(
                    duration: AppMotion.short,
                    curve: Curves.easeOut,
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected.contains(day)
                          ? colors.accent
                          : colors.background,
                      border: Border.all(
                        color: selected.contains(day)
                            ? colors.accent
                            : colors.line,
                      ),
                    ),
                    child: Text(
                      _short[day - 1],
                      style: context.text.labelLarge?.copyWith(
                        color: selected.contains(day)
                            ? colors.onAccent
                            : colors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
