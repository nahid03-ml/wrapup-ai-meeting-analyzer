import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The shared SupabaseClient instance. Supabase.initialize() must have
/// been called in main() before any read of this provider.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Streams the current Supabase auth state. Emits whenever the user
/// signs in, signs out, refreshes their token, or recovers a session.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Convenience: the current Session, or null if signed out.
final currentSessionProvider = Provider<Session?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  // Re-evaluate whenever auth state changes.
  ref.watch(authStateProvider);
  return client.auth.currentSession;
});

/// Convenience: the current User, or null if signed out.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(currentSessionProvider)?.user;
});
