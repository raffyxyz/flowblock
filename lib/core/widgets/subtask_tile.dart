import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_checkbox.dart';
import '../../../core/widgets/duration_chip.dart';
import '../../../domain/models/task_item.dart';

/// One row in a subtask list: checkbox, title, optional duration chip,
/// optional play button, optional drag handle for reordering.
class SubtaskTile extends StatelessWidget {
  const SubtaskTile({
    super.key,
    required this.subtask,
    required this.onToggled,
    this.onPlay,
    this.dragIndex,
    this.highlighted = false,
  });

  final Subtask subtask;
  final ValueChanged<bool> onToggled;
  final VoidCallback? onPlay;

  /// When non-null, shows a drag handle wired to this list index.
  final int? dragIndex;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final FlowColors colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: highlighted ? colors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        children: <Widget>[
          AppCheckbox(
            value: subtask.isDone,
            semanticLabel: subtask.isDone
                ? 'Mark ${subtask.title} as not done'
                : 'Mark ${subtask.title} as done',
            onChanged: onToggled,
          ),
          Expanded(
            child: Text(
              subtask.title,
              style: context.text.bodyLarge?.copyWith(
                decoration:
                    subtask.isDone ? TextDecoration.lineThrough : null,
                color: subtask.isDone ? colors.muted : colors.heading,
              ),
            ),
          ),
          if (subtask.durationMinutes != null) ...<Widget>[
            DurationChip(minutes: subtask.durationMinutes!),
            const SizedBox(width: AppSpace.x1),
          ],
          if (onPlay != null)
            IconButton(
              tooltip: 'Start timer for ${subtask.title}',
              onPressed: onPlay,
              icon: Icon(Icons.play_arrow, color: colors.accent),
            ),
          if (dragIndex != null)
            Semantics(
              label: 'Reorder ${subtask.title}',
              child: ReorderableDragStartListener(
                index: dragIndex!,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.x3),
                  child: Icon(Icons.drag_handle, color: colors.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
