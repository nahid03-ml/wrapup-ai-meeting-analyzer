import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/edge_functions_api.dart';
import '../../../core/providers/supabase_provider.dart';
import 'auth_exceptions.dart';

/// Mobile redirect URL used for Google OAuth deep-link return.
/// Must match the entry added to Supabase dashboard's redirect allow-list.
/// Matches the value registered in AndroidManifest.xml and Info.plist.
const String kMobileOAuthRedirect = 'io.wrapupai.app://login-callback';

class AuthRepository {
  AuthRepository(this._client, this._edgeFunctionsApi);

  final SupabaseClient _client;
  final EdgeFunctionsApi _edgeFunctionsApi;

  /// Email + password sign up. Backend trigger creates a profiles row.
  /// Mirrors src/lib/auth.ts:13-23 on the website.
  Future<void> signUpWithPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
    } on AuthException catch (e) {
      throw _translate(e);
    } on SocketException {
      throw const NetworkFailure();
    } catch (e) {
      throw UnknownAuthFailure(e.toString());
    }
  }

  /// Email + password login. Mirrors src/lib/auth.ts:25-28.
  Future<Session> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final session = response.session;
      if (session == null) {
        throw const UnknownAuthFailure('Sign-in returned no session.');
      }
      return session;
    } on AuthException catch (e) {
      throw _translate(e);
    } on SocketException {
      throw const NetworkFailure();
    } catch (e) {
      throw UnknownAuthFailure(e.toString());
    }
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: kMobileOAuthRedirect,
      );
    } on AuthException catch (e) {
      throw _translate(e);
    } on SocketException {
      throw const NetworkFailure();
    } catch (e) {
      throw UnknownAuthFailure(e.toString());
    }
  }

  /// Google OAuth via Supabase. Opens the system browser; the redirect
  /// URL bounces back into the app via deep link.
  ///
  /// Returns true once the OAuth flow was initiated. The actual session
  /// arrives later via the auth state stream.
  ///
  /// NOTE: requires the redirect URL to be on the Supabase project's
  /// allow-list (Authentication > URL Configuration > Redirect URLs).
  Future<bool> signInWithGoogle() async {
    try {
      return await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kMobileOAuthRedirect,
      );
    } on AuthException catch (e) {
      throw _translate(e);
    } on SocketException {
      throw const NetworkFailure();
    } catch (e) {
      throw UnknownAuthFailure(e.toString());
    }
  }

  /// Pre-flight check: does this email already have an account?
  /// Mirrors the website's `check-email-exists` edge function call.
  Future<bool> emailExists(String email) async {
    try {
      return await _edgeFunctionsApi.checkEmailExists(email: email);
    } catch (_) {
      // If the function is unavailable, do NOT block signup — let the
      // server decide. The signUp call itself will reject duplicates.
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw _translate(e);
    } on SocketException {
      throw const NetworkFailure();
    } catch (e) {
      throw UnknownAuthFailure(e.toString());
    }
  }

  AuthFailure _translate(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return const InvalidCredentialsFailure();
    }
    if (message.contains('email not confirmed') ||
        message.contains('email_not_confirmed')) {
      return const EmailNotConfirmedFailure();
    }
    if (message.contains('user already registered') ||
        message.contains('already registered') ||
        message.contains('user_already_exists')) {
      return const EmailAlreadyExistsFailure();
    }
    if (message.contains('password') && message.contains('weak')) {
      return const WeakPasswordFailure();
    }
    return UnknownAuthFailure(e.message);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final edgeFunctionsApi = ref.watch(edgeFunctionsApiProvider);
  return AuthRepository(client, edgeFunctionsApi);
});
