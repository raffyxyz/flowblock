# Flowblock

A calm space for tasks and focused time. Offline-only, Android-first Flutter app.

## Step 1: Project setup and UI only

Complete UI with hard-coded mock data. No database, no notifications, no real
timer persistence yet.

### How to run

Requirements: Flutter 3.47+ (Dart 3.13+), Android SDK with an emulator or
device.

```bash
flutter pub get
flutter analyze        # must report "No issues found!"
flutter test           # unit tests for the task auto-complete logic
flutter run            # on an Android emulator or device
```

Debug APK (also verified in CI-less local builds):

```bash
flutter build apk --debug
# output: build/app/outputs/flutter-apk/app-debug.apk
```

### What is mocked

- **Data**: `InMemoryTaskRepository` in `lib/data/task_repository.dart` seeds
  8 realistic tasks (dates relative to today). Checking/unchecking, adding,
  editing, deleting, and reordering all work in-memory for the session only.
  Everything sits behind the `TaskRepository` abstract class plus
  `taskListProvider`, so Drift can replace it later without touching widgets.
- **Timer**: `TimerController` in `lib/features/timer/timer_controller.dart`
  is a plain in-memory 1-second ticker. It owns `ActiveTimer` state read by
  both the full timer screen and the mini timer bar. This file is isolated on
  purpose and will be swapped for persisted timer logic in a later step.
- **Settings**: only the theme switch (System/Light/Dark) is functional.
  Default timer length is kept in-memory; notifications toggle, export, and
  import show "coming in a later step" placeholders.

### Project structure

```text
lib/
  main.dart                      # ProviderScope + MaterialApp.router
  core/
    theme/app_theme.dart         # color/type/spacing/radius/motion tokens + light & dark
    theme/theme_provider.dart    # functional System/Light/Dark switch
    router/app_router.dart        # go_router ShellRoute (Today/Upcoming/Settings) + detail/timer
    utils/format.dart            # intl date formats, mm:ss, recurrence labels
    widgets/                     # TaskCard, SubtaskTile, ProgressSummaryCard, SectionHeader,
                                 # EmptyState, DurationChip, WeekdaySelector, CircularTimerRing,
                                 # MiniTimerBar, PrimaryButton, AppCheckbox
  data/task_repository.dart      # TaskRepository abstraction + in-memory store + providers
  domain/models/task_item.dart    # plain immutable TaskItem / Subtask / RecurrenceType
  features/
    tasks/                       # Today, detail, add/edit sheet (+ sheet/ sections)
    timer/                       # placeholder ticker controller + full-screen timer UI
    upcoming/                    # 14-day strip + per-day task list
    settings/                    # grouped settings (theme works, rest placeholders)
```

### Assumptions and left-out items

- `google_fonts` is pinned to `^6.3.3` (not v9): v9 is built on the
  `material_ui` fork whose `TextTheme` is incompatible with Flutter's
  `ThemeData`. Plus Jakarta Sans headings + Inter body still apply.
- No database, notifications, permissions, background services, or timer
  persistence (per constraints). No `Platform.isAndroid` checks anywhere.
- Subtask deletion exists in the store (`removeSubtask`) but has no UI yet;
  the detail screen supports toggle, inline add, and drag-reorder.
- Form-sheet subtask rows always create new ids on save; done states of
  existing subtasks are preserved by matching titles (see `sheet_task_builder`).
- Timer end does not mark anything complete; it just stops at 00:00.
- Light/dark themes share the single `#4F7EF7` accent; chips and rings reuse
  `accentSoft` so no other bright colors appear.
- Emulator/device run was verified via `flutter build apk --debug`
  (builds clean); on-device tap-through was not performed in this environment.
