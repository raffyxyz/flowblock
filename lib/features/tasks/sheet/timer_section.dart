import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_header.dart';
import 'option_chip.dart';

const List<int> durationPresets = <int>[5, 15, 25, 50];

/// Duration presets plus a custom-minutes entry for the task form sheet.
///
/// Disabled (dimmed, non-interactive) when the sheet has subtask rows, since
/// timers then live on the subtasks. The chosen [duration] is kept upstream
/// so removing all rows restores it.
class TimerSection extends StatelessWidget {
  const TimerSection({
    super.key,
    required this.duration,
    required this.enabled,
    required this.onDuration,
    required this.onCustom,
  });

  final int duration;
  final bool enabled;
  final ValueChanged<int> onDuration;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final bool isCustom = !durationPresets.contains(duration);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: 'Timer'),
        if (!enabled) ...<Widget>[
          const SizedBox(height: AppSpace.x1),
          Text(
            'Set timers on subtasks instead',
            style: context.text.bodySmall?.copyWith(
              color: context.colors.muted,
            ),
          ),
        ],
        const SizedBox(height: AppSpace.x2),
        Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Wrap(
            spacing: AppSpace.x2,
            runSpacing: AppSpace.x2,
            children: <Widget>[
              for (final int preset in durationPresets)
                OptionChip(
                  label: '$preset min',
                  selected: duration == preset,
                  onTap: enabled ? () => onDuration(preset) : null,
                ),
              OptionChip(
                label: isCustom ? '$duration min' : 'Custom',
                selected: isCustom,
                onTap: enabled ? onCustom : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom-minutes dialog shared by the task form sheet. Returns the picked
/// value, or null when cancelled / invalid.
Future<int?> pickCustomDuration(BuildContext context, int current) async {
  final TextEditingController controller = TextEditingController(
    text: '$current',
  );
  final int? picked = await showDialog<int>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Custom minutes'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'e.g. 40',
            suffixText: 'min',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              int.tryParse(controller.text.trim()),
            ),
            child: const Text('Set'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  if (picked != null && picked > 0 && picked <= 480) {
    return picked;
  }
  return null;
}
