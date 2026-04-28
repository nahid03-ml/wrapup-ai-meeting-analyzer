import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/action_items/presentation/action_items_page.dart';
import '../../features/auth/presentation/email_check_page.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/signup_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/meetings/presentation/meeting_detail_page.dart';
import '../../features/meetings/presentation/meetings_list_page.dart';
import '../../features/new_meeting/presentation/new_meeting_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../providers/supabase_provider.dart';
import '../shell/app_shell.dart';

class AppRoutes {
  AppRoutes._();
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String emailCheck = '/check-email';
  static const String dashboard = '/dashboard';
  static const String dashboardHome = '/dashboard/home';
  static const String dashboardMeetings = '/dashboard/meetings';
  static const String dashboardNew = '/dashboard/new';
  static const String dashboardActionItems = '/dashboard/action-items';
  static const String dashboardProfile = '/dashboard/profile';
  static const String meetingDetail = '/dashboard/meetings/:id';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>();
final _meetingsNavigatorKey = GlobalKey<NavigatorState>();
final _newNavigatorKey = GlobalKey<NavigatorState>();
final _tasksNavigatorKey = GlobalKey<NavigatorState>();
final _profileNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.dashboardHome,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final session = ref.read(currentSessionProvider);
      final loggedIn = session != null;
      final location = state.uri.path;
      final isAuthRoute =
          location == AppRoutes.login ||
          location == AppRoutes.signup ||
          location == AppRoutes.forgotPassword ||
          location == AppRoutes.emailCheck;

      if (authState.isLoading) return null;

      if (!loggedIn && !isAuthRoute) return AppRoutes.login;
      if (loggedIn && isAuthRoute) return AppRoutes.dashboardHome;
      if (loggedIn && location == AppRoutes.dashboard) {
        return AppRoutes.dashboardHome;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.emailCheck,
        name: 'check-email',
        builder: (context, state) =>
            EmailCheckPage(email: state.extra as String?),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        redirect: (context, state) => AppRoutes.dashboardHome,
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.meetingDetail,
        name: 'meeting-detail',
        builder: (context, state) {
          final meetingId = state.pathParameters['id']!;
          return MeetingDetailPage(meetingId: meetingId);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            initialLocation: AppRoutes.dashboardHome,
            routes: [
              GoRoute(
                path: AppRoutes.dashboardHome,
                name: 'dashboard-home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _meetingsNavigatorKey,
            initialLocation: AppRoutes.dashboardMeetings,
            routes: [
              GoRoute(
                path: AppRoutes.dashboardMeetings,
                name: 'dashboard-meetings',
                builder: (context, state) => const MeetingsListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _newNavigatorKey,
            initialLocation: AppRoutes.dashboardNew,
            routes: [
              GoRoute(
                path: AppRoutes.dashboardNew,
                name: 'dashboard-new',
                builder: (context, state) => const NewMeetingPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _tasksNavigatorKey,
            initialLocation: AppRoutes.dashboardActionItems,
            routes: [
              GoRoute(
                path: AppRoutes.dashboardActionItems,
                name: 'dashboard-action-items',
                builder: (context, state) => const ActionItemsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            initialLocation: AppRoutes.dashboardProfile,
            routes: [
              GoRoute(
                path: AppRoutes.dashboardProfile,
                name: 'dashboard-profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Route not found: ${state.uri}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    _authSubscription = ref.listen<AsyncValue<AuthState>>(
      authStateProvider,
      (previous, next) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<AuthState>> _authSubscription;

  @override
  void dispose() {
    _authSubscription.close();
    super.dispose();
  }
}
