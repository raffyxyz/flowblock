import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Editable subtask row model used by the task form sheet.
class SubtaskDraft {
  SubtaskDraft({String? title, this.durationMinutes, this.isDone = false}) {
    if (title != null) {
      controller.text = title;
    }
  }

  final TextEditingController controller = TextEditingController();
  int? durationMinutes;
  bool isDone;

  void dispose() => controller.dispose();
}

const List<int?> subtaskDurationOptions = <int?>[null, 5, 10, 15, 25, 50];

/// One editable subtask row: title field, duration picker, remove button.
class SubtaskDraftRow extends StatelessWidget {
  const SubtaskDraftRow({
    super.key,
    required this.index,
    required this.draft,
    required this.onDurationChanged,
    required this.onRemove,
  });

  final int index;
  final SubtaskDraft draft;
  final ValueChanged<int?> onDurationChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.x2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: draft.controller,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: 'Subtask ${index + 1}'),
            ),
          ),
          const SizedBox(width: AppSpace.x2),
          SubtaskDurationMenu(
            draft: draft,
            onChanged: onDurationChanged,
          ),
          IconButton(
            tooltip: 'Remove subtask',
            onPressed: onRemove,
            icon: Icon(
              Icons.remove_circle_outline,
              color: context.colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact per-subtask duration picker shown inside a draft row.
/// Rebuilds via the parent calling setState on selection.
class SubtaskDurationMenu extends StatelessWidget {
  const SubtaskDurationMenu({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final SubtaskDraft draft;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final FlowColors colors = context.colors;
    return PopupMenuButton<int?>(
      tooltip: 'Subtask duration',
      onSelected: onChanged,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<int?>>[
        for (final int? option in subtaskDurationOptions)
          PopupMenuItem<int?>(
            value: option,
            child: Text(option == null ? 'No timer' : '$option min'),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.x3,
          vertical: AppSpace.x3,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              draft.durationMinutes == null
                  ? '—'
                  : '${draft.durationMinutes}',
              style:
                  context.text.labelMedium?.copyWith(color: colors.muted),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: colors.muted),
          ],
        ),
      ),
    );
  }
}
