import 'package:flutter/material.dart';

/// Root [ScaffoldMessenger] key so delete Undo bars outlive any one route.
///
/// The detail screen pops before staging its delete; showing the SnackBar
/// through this messenger keeps it visible on the list screen.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
