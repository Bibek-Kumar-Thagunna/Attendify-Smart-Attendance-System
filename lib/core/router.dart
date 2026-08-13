import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/dashboard/presentation/admin_dashboard_page.dart';
import '../features/dashboard/presentation/admin_institutions_page.dart';
import '../features/dashboard/presentation/admin_users_page.dart';
import '../features/dashboard/presentation/admin_analytics_page.dart';
import '../features/dashboard/presentation/admin_teachers_analytics_page.dart';
import '../features/dashboard/presentation/admin_company_drive_page.dart';
import '../features/dashboard/presentation/admin_reports_page.dart';
import '../features/dashboard/presentation/admin_about_page.dart';
import '../features/dashboard/presentation/admin_profile_page.dart';
import '../features/dashboard/presentation/admin_class_groups_page.dart';
import '../features/dashboard/presentation/admin_teacher_approval_page.dart';
import '../features/dashboard/presentation/admin_subjects_page.dart';
import '../features/dashboard/presentation/admin_notifications_page.dart';
import '../features/dashboard/presentation/admin_broadcast_page.dart';
import '../features/super_admin/presentation/super_admin_dashboard_page.dart';
import '../features/super_admin/presentation/super_admin_profile_page.dart';
import '../features/super_admin/presentation/super_admin_about_page.dart';
import '../features/super_admin/presentation/system_health_page.dart';
import '../features/super_admin/presentation/institution_details_page.dart';
import '../features/super_admin/presentation/super_admin_users_page.dart';
import '../features/super_admin/presentation/super_admin_settings_page.dart';
import '../features/super_admin/presentation/audit_logs_page.dart';
import '../features/super_admin/presentation/global_notifications_page.dart';
import '../features/super_admin/presentation/super_admin_notifications_page.dart';
import '../features/teacher/presentation/teacher_dashboard_page.dart';
import '../features/teacher/presentation/teacher_students_page.dart';
import '../features/teacher/presentation/teacher_subjects_page.dart';
import '../features/teacher/presentation/teacher_schedule_page.dart';
import '../features/teacher/presentation/teacher_attendance_page.dart';
import '../features/teacher/presentation/teacher_notifications_page.dart';
import '../features/teacher/presentation/teacher_exports_page.dart';
import '../features/teacher/presentation/teacher_settings_page.dart';
import '../features/teacher/presentation/teacher_pending_approval_page.dart';
import '../features/teacher/presentation/manual_attendance_page.dart';
import '../features/student/presentation/student_monthly_summary_page.dart';
import '../features/student/presentation/student_notifications_page.dart';
import '../features/student/presentation/student_subjects_page.dart';
import '../features/student/presentation/student_profile_page.dart';
import '../features/auth/presentation/signup_page.dart';
import '../features/auth/presentation/initial_signup_page.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/teacher/presentation/generate_qr_page.dart';
import '../features/student/presentation/scan_qr_page.dart';
import '../features/student/presentation/attendance_history_page.dart';
import '../features/student/presentation/student_home_page.dart';
import '../features/student/presentation/student_analytics_page.dart';
import '../features/splash/presentation/splash_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Keep a single router instance and refresh it when auth changes.
  final notifier = ValueNotifier<int>(0);
  ref.onDispose(() => notifier.dispose());
  ref.listen<AuthState>(authControllerProvider, (_, __) => notifier.value++);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/splash',
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isPublicRoute =
          state.uri.path == '/login' ||
          state.uri.path == '/signup' ||
          state.uri.path == '/splash' ||
          state.uri.path == '/onboarding' ||
          state.uri.path == '/forgot-password';

      // If we have a selected institution for signup (e.g. from redirect flow), go to onboarding
      // But ONLY if we don't already have a valid role (i.e. not already onboarded)
      if (authState.selectedInstitutionForSignup != null &&
          state.uri.path != '/onboarding' &&
          authState.role == UserRole.none) {
        return '/onboarding';
      }

      // If not authenticated and trying to access protected route
      if (authState.role == UserRole.none && !isPublicRoute) {
        return '/login';
      }

      // If authenticated and trying to access public route (like login), redirect to home
      if (authState.role != UserRole.none && isPublicRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const InitialSignupPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final authState = ref.read(authControllerProvider);
          // Prioritize super admin check
          if (authState.isSuperAdmin) {
            return '/super-admin';
          }
          // Prioritize admin check
          if (authState.isAdmin || authState.role == UserRole.admin) {
            return '/admin';
          }
          // Check if teacher is not approved
          if (authState.role == UserRole.teacher && !authState.approved) {
            return '/teacher/pending';
          }
          // Otherwise route based on role
          switch (authState.role) {
            case UserRole.admin:
              return '/admin';
            case UserRole.teacher:
              return '/teacher';
            case UserRole.student:
              return '/student';
            case UserRole.none:
              return '/login';
          }
        },
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        redirect: (context, state) {
          final authState = ref.read(authControllerProvider);
          // Redirect super admins to super-admin pages
          if (authState.isSuperAdmin) {
            return '/super-admin';
          }
          // Redirect non-admins to home
          if (!authState.isAdmin && authState.role != UserRole.admin) {
            return '/';
          }
          return null;
        },
        builder: (context, state) => const AdminDashboardPage(),
        routes: [
          GoRoute(
            path: 'users',
            builder: (context, state) => const AdminUsersPage(),
          ),
          GoRoute(
            path: 'class-groups',
            builder: (context, state) => const AdminClassGroupsPage(),
          ),
          GoRoute(
            path: 'approve-teachers',
            builder: (context, state) => const AdminTeacherApprovalPage(),
          ),
          GoRoute(
            path: 'analytics',
            builder: (context, state) => const AdminAnalyticsPage(),
          ),
          GoRoute(
            path: 'teachers-analytics',
            builder: (context, state) => const AdminTeachersAnalyticsPage(),
          ),
          GoRoute(
            path: 'company-drive',
            builder: (context, state) => const AdminCompanyDrivePage(),
          ),
          GoRoute(
            path: 'reports',
            builder: (context, state) => const AdminReportsPage(),
          ),
          GoRoute(
            path: 'subjects',
            builder: (context, state) => const AdminSubjectsPage(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const AdminNotificationsPage(),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const AdminProfilePage(),
          ),
          GoRoute(
            path: 'about',
            builder: (context, state) => const AdminAboutPage(),
          ),
          GoRoute(
            path: 'broadcast',
            builder: (context, state) => const AdminBroadcastPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/super-admin',
        name: 'super-admin',
        redirect: (context, state) {
          final authState = ref.read(authControllerProvider);
          if (!authState.isSuperAdmin) return '/';
          return null;
        },
        builder: (context, state) => const SuperAdminDashboardPage(),
        routes: [
          GoRoute(
            path: 'institutions',
            builder: (context, state) => const AdminInstitutionsPage(),
          ),
          GoRoute(
            path: 'institutions/:id', // Corrected path to be relative
            builder: (context, state) => InstitutionDetailsPage(
              institutionId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const SuperAdminProfilePage(),
          ),
          GoRoute(
            path: 'about',
            builder: (context, state) => const SuperAdminAboutPage(),
          ),
          GoRoute(
            path: 'health',
            builder: (context, state) => const SystemHealthPage(),
          ),
          GoRoute(
            path: 'users',
            builder: (context, state) => const SuperAdminUsersPage(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SuperAdminSettingsPage(),
          ),
          GoRoute(
            path: 'audit-logs',
            builder: (context, state) => const AuditLogsPage(),
          ),
          GoRoute(
            path: 'broadcast',
            builder: (context, state) => const GlobalNotificationsPage(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const SuperAdminNotificationsPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/teacher',
        name: 'teacher-home',
        redirect: (context, state) {
          final authState = ref.read(authControllerProvider);
          // Redirect admins to admin pages even if they access teacher routes
          if (authState.isAdmin || authState.role == UserRole.admin) {
            return '/admin';
          }
          // Redirect unapproved teachers to pending page
          if (authState.role == UserRole.teacher && !authState.approved) {
            return '/teacher/pending';
          }
          // Redirect non-teachers to home (unless admin, but admins usually use admin dashboard)
          if (authState.role != UserRole.teacher &&
              !authState.isAdmin &&
              authState.role != UserRole.admin) {
            return '/';
          }
          return null; // Allow navigation to teacher pages
        },
        builder: (context, state) => const TeacherDashboardPage(),
        routes: [
          GoRoute(
            path: 'pending',
            builder: (context, state) => const TeacherPendingApprovalPage(),
          ),
          GoRoute(
            path: 'generate',
            name: 'generate-qr',
            builder: (context, state) => const GenerateQrPage(),
          ),
          GoRoute(
            path: 'students',
            builder: (context, state) => const TeacherStudentsPage(),
          ),
          GoRoute(
            path: 'subjects',
            builder: (context, state) => const TeacherSubjectsPage(),
          ),
          GoRoute(
            path: 'schedule',
            builder: (context, state) => const TeacherSchedulePage(),
          ),
          GoRoute(
            path: 'attendance',
            builder: (context, state) => const TeacherAttendancePage(),
          ),
          GoRoute(
            path: 'manual-attendance',
            builder: (context, state) => const ManualAttendancePage(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const TeacherNotificationsPage(),
          ),
          GoRoute(
            path: 'exports',
            builder: (context, state) => const TeacherExportsPage(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const TeacherSettingsPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/student',
        name: 'student-home',
        redirect: (context, state) {
          final authState = ref.read(authControllerProvider);
          if (authState.role != UserRole.student) {
            return '/';
          }
          return null;
        },
        builder: (context, state) => const StudentHomePage(),
        routes: [
          GoRoute(
            path: 'scan',
            name: 'scan-qr',
            builder: (context, state) => const ScanQrPage(),
          ),
          GoRoute(
            path: 'history',
            name: 'attendance-history',
            builder: (context, state) => const AttendanceHistoryPage(),
          ),
          GoRoute(
            path: 'summary',
            builder: (context, state) => const StudentMonthlySummaryPage(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const StudentNotificationsPage(),
          ),
          GoRoute(
            path: 'subjects',
            builder: (context, state) => const StudentSubjectsPage(),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const StudentProfilePage(),
          ),
          GoRoute(
            path: 'analytics',
            builder: (context, state) => const StudentAnalyticsPage(),
          ),
        ],
      ),
    ],
  );
});
