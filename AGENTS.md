PROJECT: Flowblock, a Flutter app (Android first, multi-platform later).

WHAT IT DOES: Users create tasks, add subtasks to a task, run a timer on a task or on any subtask, and schedule tasks to repeat (once, daily, weekly on chosen weekdays, monthly).

KEY DECISIONS:

- Offline-only for now. No accounts, no cloud sync.
- Any task or subtask can have its own timer. Only one timer runs at a time.
- Completing all subtasks auto-completes the parent task.
- Timer-finished alert is a gentle notification, not an alarm sound.
- Recurring tasks reset their subtasks every occurrence.

STACK: Flutter with Dart, Material 3, Riverpod (flutter_riverpod + riverpod_generator), go_router, Drift (SQLite) for storage later, freezed for models later, flutter_local_notifications + timezone for reminders later.

ARCHITECTURE: feature-first folders.
lib/
core/ theme, router, shared widgets, utils
data/ db and repositories (later steps)
domain/ models and logic (later steps)
features/ tasks/, timer/, schedule/, settings/
main.dart

RULES:

- Null-safe, strongly typed Dart. Declare explicit types on public APIs.
- No Platform.isAndroid checks outside platform-specific service implementations.
- Keep widgets small and in separate files. No file over ~300 lines.
- Do not add packages I did not list. Ask first.
- Do not implement anything outside the current step.
