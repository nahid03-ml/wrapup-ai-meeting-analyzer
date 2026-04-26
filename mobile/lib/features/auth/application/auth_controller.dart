import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// Controller for one-shot auth actions (sign-in, sign-up, sign-out).
/// UI listens to this for loading + error state on auth buttons.
///
/// State semantics:
///   - data(null)      -> idle / last action succeeded
///   - loading()       -> action in flight
///   - error(failure)  -> last action failed; surface message in UI
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // No initial async work; controller starts idle.
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.signUpWithPassword(
        email: email,
        password: password,
        fullName: fullName,
      ),
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async {
        await _repo.signInWithPassword(email: email, password: password);
      },
    );
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.signInWithGoogle();
    });
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.sendPasswordResetEmail(email),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.signOut());
  }

  /// Pre-flight email existence check. Returns true if email is taken.
  /// Does not change controller state — UI handles its own form-level
  /// loading for this.
  Future<bool> emailExists(String email) {
    return _repo.emailExists(email);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
