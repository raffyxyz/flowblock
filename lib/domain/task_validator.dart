import 'models/task_item.dart';
import 'validation_exception.dart';

/// Pure validation rules for tasks and subtasks.
void validateTaskTitle(String title) {
  final String trimmed = title.trim();
  if (trimmed.isEmpty) {
    throw const ValidationException('Title cannot be blank');
  }
  if (trimmed.length > 120) {
    throw const ValidationException('Title cannot exceed 120 characters');
  }
}

void validateTaskNotes(String notes) {
  if (notes.length > 2000) {
    throw const ValidationException('Notes cannot exceed 2000 characters');
  }
}

void validateDuration(int? durationMinutes, [String name = 'Duration']) {
  if (durationMinutes != null) {
    if (durationMinutes < 1 || durationMinutes > 600) {
      throw ValidationException('$name must be between 1 and 600 minutes');
    }
  }
}

void validateSubtaskTitle(String title) {
  final String trimmed = title.trim();
  if (trimmed.isEmpty) {
    throw const ValidationException('Subtask title cannot be blank');
  }
  if (trimmed.length > 120) {
    throw const ValidationException('Subtask title cannot exceed 120 characters');
  }
}

void validateTaskItem(TaskItem task) {
  validateTaskTitle(task.title);
  validateTaskNotes(task.notes);
  validateDuration(task.durationMinutes, 'Task duration');
  if (task.subtasks.length > 50) {
    throw const ValidationException('A task cannot have more than 50 subtasks');
  }
  for (final Subtask sub in task.subtasks) {
    validateSubtaskTitle(sub.title);
    validateDuration(sub.durationMinutes, 'Subtask duration');
  }
}
