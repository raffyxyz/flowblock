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

## Step 2: Database (Drift, not yet wired to the UI)

The local SQLite layer is built and tested but deliberately **not connected**
to any screen or existing provider. The app still runs on the in-memory seed
from Step 1; Step 3 will swap the repository over.

### Tables (`lib/data/db/tables.dart`)

- **tasks**: `id` (UUID text PK), `title`, `notes` (nullable),
  `sortOrder`, `isDone` (default false), `completedAt` (nullable),
  `estimatedSeconds` (nullable; kept even with subtasks, ignored for display
  while subtasks exist), `scheduledDate` (nullable `'yyyy-MM-dd'`),
  `scheduledMinutes` (nullable minutes since midnight), `recurrenceType`
  (`once`/`daily`/`weekly`/`monthly`, default `once`), `recurrenceInterval`
  (default 1), `recurrenceWeekdays` (int bitmask, bit 0 = Monday … bit 6 =
  Sunday, default 0), `recurrenceEndsOn` (nullable `'yyyy-MM-dd'`),
  `createdAt`, `updatedAt`.
- **subtasks**: `id`, `taskId` (FK → tasks, `ON DELETE CASCADE`), `title`,
  `sortOrder`, `isDone`, `completedAt` (nullable), `durationSeconds`
  (nullable), `createdAt`, `updatedAt`. One level only (no self-reference).
- **task_occurrences**: one row per date a recurring task is acted on —
  `id`, `taskId` (FK, cascade), `date` (`'yyyy-MM-dd'`), `status`
  (`pending`/`done`/`skipped`), `completedAt` (nullable). Unique on
  `(taskId, date)`.
- **occurrence_subtask_states**: per-occurrence checked state (this is what
  lets subtasks reset each occurrence) — `occurrenceId` (FK, cascade),
  `subtaskId` (FK, cascade), `isDone`, `completedAt` (nullable). PK is
  `(occurrenceId, subtaskId)`.
- **timer_sessions**: `id`, `taskId` (FK, cascade), `subtaskId` (nullable FK,
  `ON DELETE SET NULL` so history survives; null = task-level timer),
  `startedAt`, `endedAt` (nullable), `plannedSeconds`, `elapsedSeconds`
  (default 0, active time excluding pauses), `mode`
  (`countdown`/`stopwatch`, default `countdown`), `endReason` (nullable:
  `completed`/`stopped`/`skipped`).

Indices: `subtasks(taskId, sortOrder)`, `tasks(scheduledDate)`,
`task_occurrences(date)`, unique `task_occurrences(taskId, date)`,
`timer_sessions(taskId)`, `timer_sessions(startedAt)`.

Other pieces:

- `lib/data/db/database.dart` — `AppDatabase` takes a `QueryExecutor`
  (tests inject `NativeDatabase.memory()`; web can be added later),
  `schemaVersion = 1`, `MigrationStrategy` with `onCreate: createAll` plus an
  empty commented `onUpgrade` stub, and `PRAGMA foreign_keys = ON` in
  `beforeOpen`. No static singleton.
- `lib/data/db/connection.dart` — production opener via `drift_flutter`
  (database name `'flowblock'`).
- `lib/data/db/provider.dart` — `appDatabaseProvider` (Riverpod `Provider`
  with `ref.onDispose(close)`). Nothing reads it yet.
- `lib/data/db/daos/` — pure data operations, no business rules
  (no auto-complete-parent, no recurrence math, no timer rules).
- `lib/data/db/mappers.dart` — row ↔ domain conversions (domain never
  imports drift). Schema snapshot: `drift_schemas/v1.json`.

### Time rules

- Instants (`createdAt`, `updatedAt`, `startedAt`, `endedAt`, `completedAt`)
  are stored in **UTC** (mappers call `toUtc()` on write).
- Scheduling is **wall-clock local time**: `scheduledDate` as `'yyyy-MM-dd'`
  text plus `scheduledMinutes` (minutes since midnight). A scheduled time is
  never stored as UTC, so DST changes cannot shift it.
- Enums are stored as **text by name** (`textEnum`).

### Codegen and tests

```bash
dart run build_runner build -d   # regenerate *.g.dart + drift schema
flutter analyze                  # must report "No issues found!"
flutter test                     # in-memory repo tests + new test/data/db/ tests
flutter build apk --debug
```

Schema snapshots for future migration testing:

```bash
dart run drift_dev schema dump lib/data/db/database.dart drift_schemas/v1.json
```

### Step 2 assumptions and deviations

- `analyzer` is temporarily capped at `14.4.0` via `dependency_overrides`:
  `analyzer 14.5.0` (released Oct 2026) removed
  `AnalysisOptionsImpl.contextFeatures`, which `build_runner 2.16.1` still
  sets, so codegen fails without the cap. No new package is added; remove the
  override once `build_runner` ships a fix. `google_fonts` stays pinned.
- `drift_flutter` already brings `path_provider` transitively, so it was not
  added directly.
- Domain models gained DB-backed fields with safe defaults (no UI edits
  needed): `TaskItem`/`Subtask` gained `sortOrder` (default 0),
  `completedAt`/`createdAt`/`updatedAt` (nullable), and `TaskItem` gained
  `recurrenceInterval` (default 1) and `recurrenceEndsOn` (nullable).
  `copyWith` on both was extended (with `clear*` flags for newly nullable
  fields). `hasSubtasks`, `canRunOwnTimer`, and `rolledUpEstimate` are
  unchanged. New domain types: `task_occurrence.dart`
  (`OccurrenceStatus`, `TaskOccurrence`, `OccurrenceSubtaskState`) and
  `timer_session.dart` (`TimerMode`, `TimerEndReason`, `TimerSession`).
- Estimates: domain speaks minutes, rows speak seconds (`minutes * 60` /
  `seconds ~/ 60`). Non-multiple-of-60 seconds read back truncated.
- `SubtasksDao.update`/`delete` are named `updateSubtask`/`deleteSubtask`:
  plain `update`/`delete` would collide with `DatabaseAccessor`'s
  statement builders and fail to compile.
- Test files hide drift's `isNull` helper (`hide isNull, isNotNull`) because
  it clashes with the test matcher's `isNull`.
- Test-only `.g.dart` naming: DAO parts (`tasks_dao.g.dart`, …) are standard
  Drift output; generated files are exempt from the ~300-line rule.
