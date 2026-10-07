import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/section_header.dart';
import 'settings_providers.dart';

/// Grouped settings list. Only the theme switch is functional; everything
/// else is an in-memory placeholder for later steps.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifications = true;

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming in a later step.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeMode mode = ref.watch(themeModeProvider);
    final int defaultDuration = ref.watch(defaultDurationProvider);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpace.contentMax),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.x5,
            AppSpace.x4,
            AppSpace.x5,
            AppSpace.x8,
          ),
          children: <Widget>[
            Text('Settings', style: context.text.headlineMedium),
            const SizedBox(height: AppSpace.x1),
            Text(
              'Make Flowblock yours.',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.muted,
              ),
            ),
            const SizedBox(height: AppSpace.x4),
            const SectionHeader(title: 'Appearance'),
            const SizedBox(height: AppSpace.x2),
            _Group(
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<AppThemeMode>(
                  segments: const <ButtonSegment<AppThemeMode>>[
                    ButtonSegment<AppThemeMode>(
                      value: AppThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment<AppThemeMode>(
                      value: AppThemeMode.light,
                      label: Text('Light'),
                    ),
                    ButtonSegment<AppThemeMode>(
                      value: AppThemeMode.dark,
                      label: Text('Dark'),
                    ),
                  ],
                  selected: <AppThemeMode>{mode},
                  onSelectionChanged: (Set<AppThemeMode> selected) {
                    ref
                        .read(themeModeProvider.notifier)
                        .set(selected.first);
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpace.x5),
            const SectionHeader(title: 'Focus timer'),
            const SizedBox(height: AppSpace.x2),
            _Group(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Default length',
                    style: context.text.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.x2),
                  Wrap(
                    spacing: AppSpace.x2,
                    children: <int>[5, 15, 25, 50]
                        .map(
                          (int minutes) => ChoiceChip(
                            label: Text('$minutes min'),
                            selected: defaultDuration == minutes,
                            onSelected: (_) => ref
                                .read(defaultDurationProvider.notifier)
                                .set(minutes),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.x5),
            const SectionHeader(title: 'Reminders'),
            const SizedBox(height: AppSpace.x2),
            _Group(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notifications'),
                subtitle: const Text(
                  'Gentle alert when a timer ends (placeholder).',
                ),
                value: _notifications,
                onChanged: (bool value) =>
                    setState(() => _notifications = value),
              ),
            ),
            const SizedBox(height: AppSpace.x5),
            const SectionHeader(title: 'Data'),
            const SizedBox(height: AppSpace.x2),
            _Group(
              child: Column(
                children: <Widget>[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.upload_outlined),
                    title: const Text('Export data'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _comingSoon('Export'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download_outlined),
                    title: const Text('Import data'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _comingSoon('Import'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.x5),
            const SectionHeader(title: 'About'),
            const SizedBox(height: AppSpace.x2),
            const _Group(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.spa_outlined),
                title: Text('Flowblock'),
                subtitle: Text('Version 1.0.0 · Offline-first'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.x4),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadow.soft(context),
      ),
      child: child,
    );
  }
}
