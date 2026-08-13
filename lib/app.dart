import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/notification_listener.dart';

class AttendifyApp extends ConsumerWidget {
  const AttendifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final theme = buildAttendifyTheme();

    // Watch the notification listener to activate it
    ref.watch(notificationListenerProvider);

    return MaterialApp.router(
      title: 'Attendify',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AppScrollBehavior(),
      theme: theme.light,
      darkTheme: theme.dark,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // No glow on web; clean minimal scroll like shadcn sites
    return child;
  }
}
