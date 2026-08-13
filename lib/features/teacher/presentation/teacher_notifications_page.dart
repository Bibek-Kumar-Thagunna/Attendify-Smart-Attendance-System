import 'package:flutter/material.dart';
import 'teacher_shell.dart';
import '../../notifications/presentation/notifications_page.dart';

class TeacherNotificationsPage extends StatelessWidget {
  const TeacherNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TeacherShell(child: NotificationsPage());
  }
}
