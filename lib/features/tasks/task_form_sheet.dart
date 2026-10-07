import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/section_header.dart';
import '../../data/task_actions.dart';
import '../../data/task_repository.dart';
import '../../domain/models/task_item.dart';
import '../../domain/validation_exception.dart';
import '../settings/settings_providers.dart';
import 'sheet/repeat_section.dart';
import 'sheet/schedule_section.dart';
import 'sheet/sheet_task_builder.dart';
import 'sheet/subtask_draft.dart';
import 'sheet/timer_section.dart';
import 'task_timer_guard.dart';

/// Opens the add/edit task sheet. The sheet writes straight to the in-memory
/// task list, so the new task appears on Today immediately.
Future<void> showTaskFormSheet(BuildContext context, {TaskItem? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => TaskFormSheet(existing: existing),
  );
}

class TaskFormSheet extends ConsumerStatefulWidget {
  const TaskFormSheet({super.key, this.existing});

  final TaskItem? existing;

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final List<SubtaskDraft> _drafts = <SubtaskDraft>[];

  late DateTime _date;
  TimeOfDay? _time;
  RecurrenceType _recurrence = RecurrenceType.once;
  Set<int> _weekdays = <int>{};
  late int _duration;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    final TaskItem? existing = widget.existing;
    _duration = existing?.durationMinutes ?? ref.read(defaultDurationProvider);
    final DateTime now = DateTime.now();
    _date = existing == null
        ? DateTime(now.year, now.month, now.day)
        : DateTime(existing.date.year, existing.date.month, existing.date.day);
    if (existing != null) {
      _title.text = existing.title;
      _notes.text = existing.notes;
      if (existing.time != null) {
        _time = TimeOfDay(
          hour: existing.time!.hour,
          minute: existing.time!.minute,
        );
      }
      _recurrence = existing.recurrence;
      _weekdays = Set<int>.from(existing.weekdays);

      for (final Subtask s in existing.subtasks) {
        _drafts.add(
          SubtaskDraft(
            id: s.id,
            title: s.title,
            durationMinutes: s.durationMinutes,
            isDone: s.isDone,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    for (final SubtaskDraft draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() => _time = picked);
    }
  }

  Future<void> _pickCustomDuration() async {
    final int? picked = await pickCustomDuration(context, _duration);
    if (picked != null && mounted) {
      setState(() => _duration = picked);
    }
  }

  Future<void> _save() async {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Please add a title');
      return;
    }
    final TaskItem? existing = widget.existing;
    final TaskItem task = buildSheetTask(
      existing: existing,
      title: title,
      notes: _notes.text.trim(),
      date: _date,
      time: _time,
      recurrence: _recurrence,
      weekdays: _weekdays,
      duration: _duration,
      drafts: _drafts,
      newId: ref.read(idGeneratorProvider),
    );
    if (existing != null &&
        !existing.hasSubtasks &&
        task.hasSubtasks) {
      final bool proceed = await confirmStopTaskTimer(context, ref, existing);
      if (!proceed || !mounted) {
        return;
      }
    }
    final TaskActions actions = ref.read(taskActionsProvider);
    try {
      if (existing == null) {
        await actions.addTask(task);
      } else {
        await actions.updateTaskWithSubtasks(task);
      }
    } on ValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the task. Please try again.'),
          ),
        );
      }
      return;
    }
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.x5,
          AppSpace.x2,
          AppSpace.x5,
          AppSpace.x6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.line,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.x3),
            Row(
              children: <Widget>[
                Text(
                  widget.existing == null ? 'New task' : 'Edit task',
                  style: context.text.titleLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.x2),
            TextField(
              controller: _title,
              autofocus: true,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_titleError != null) {
                  setState(() => _titleError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Title',
                errorText: _titleError,
              ),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: _notes,
              maxLines: 3,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
            ),
            const SizedBox(height: AppSpace.x5),
            const SectionHeader(title: 'Subtasks'),
            const SizedBox(height: AppSpace.x2),
            for (int i = 0; i < _drafts.length; i++)
              SubtaskDraftRow(
                index: i,
                draft: _drafts[i],
                onDurationChanged: (int? value) => setState(
                  () => _drafts[i].durationMinutes = value,
                ),
                onRemove: () => setState(() {
                  _drafts[i].dispose();
                  _drafts.removeAt(i);
                }),
              ),
            if (_drafts.length < 50)
              TextButton.icon(
                onPressed: () => setState(() => _drafts.add(SubtaskDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Add subtask'),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
                child: Text(
                  'Maximum 50 subtasks reached',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.colors.muted),
                ),
              ),
            const SizedBox(height: AppSpace.x4),
            ScheduleSection(
              date: _date,
              time: _time,
              onPickDate: _pickDate,
              onPickTime: _pickTime,
            ),
            const SizedBox(height: AppSpace.x4),
            RepeatSection(
              recurrence: _recurrence,
              weekdays: _weekdays,
              onRecurrence: (RecurrenceType value) =>
                  setState(() => _recurrence = value),
              onToggleDay: (int day) => setState(() {
                if (_weekdays.contains(day)) {
                  _weekdays.remove(day);
                } else {
                  _weekdays.add(day);
                }
              }),
            ),
            const SizedBox(height: AppSpace.x4),
            TimerSection(
              duration: _duration,
              enabled: _drafts.isEmpty,
              onDuration: (int value) => setState(() => _duration = value),
              onCustom: _pickCustomDuration,
            ),
            const SizedBox(height: AppSpace.x6),
            PrimaryButton(
              label: widget.existing == null ? 'Save task' : 'Save changes',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
