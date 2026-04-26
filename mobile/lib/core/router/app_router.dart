import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_placeholder_page.dart';
import '../../features/home/home_placeholder_page.dart';
import '../providers/supabase_provider.dart';

/// Route paths used throughout the app. Names match the website's
/// route conventions (/login, /dashboard, etc.) so deep links and
/// mental models stay aligned.
class AppRoutes {
  AppRoutes._();
  static const String login = '/login';
  static const String dashboard = '/dashboard';
}

/// GoRouter instance with auth-guard redirect.
///
/// Mirrors the website's behavior: pages under /dashboard require
/// a Supabase session; if missing, redirect to /login. If a signed-in
/// user lands on /login, send them to /dashboard.
final routerProvider = Provider<GoRouter>((ref) {
  // Re-build router redirect logic whenever auth state changes.
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    redirect: (context, state) {
      final session = ref.read(currentSessionProvider);
      final loggedIn = session != null;
      final goingToLogin = state.matchedLocation == AppRoutes.login;

      // Still resolving auth on first frame: don't redirect yet.
      if (authState.isLoading) return null;

      if (!loggedIn && !goingToLogin) return AppRoutes.login;
      if (loggedIn && goingToLogin) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPlaceholderPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const HomePlaceholderPage(),
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
