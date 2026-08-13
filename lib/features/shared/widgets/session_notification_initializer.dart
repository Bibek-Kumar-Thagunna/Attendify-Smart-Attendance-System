import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:attendify/features/student/services/scheduler_service.dart';

class SessionNotificationInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const SessionNotificationInitializer({super.key, required this.child});

  @override
  ConsumerState<SessionNotificationInitializer> createState() =>
      _SessionNotificationInitializerState();
}

class _SessionNotificationInitializerState
    extends ConsumerState<SessionNotificationInitializer> {
  @override
  void initState() {
    super.initState();
    // Initialize scheduler service to start listening for sessions
    // We do this in a post-frame callback to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(schedulerServiceProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
