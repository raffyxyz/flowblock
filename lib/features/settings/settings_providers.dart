import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder settings state (Step 1: in-memory only, no persistence).
class DefaultDurationNotifier extends Notifier<int> {
  @override
  int build() => 25;

  void set(int minutes) {
    state = minutes;
  }
}

final defaultDurationProvider =
    NotifierProvider<DefaultDurationNotifier, int>(DefaultDurationNotifier.new);
