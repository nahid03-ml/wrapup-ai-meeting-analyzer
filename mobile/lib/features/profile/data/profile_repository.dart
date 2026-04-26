import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';

/// Plain-data view of a row from public.profiles.
/// Mirrors the columns selected by the website's useProfile hook.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.role,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? role;
  final String? avatarUrl;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        email: (map['email'] as String?) ?? '',
        fullName: map['full_name'] as String?,
        role: map['role'] as String?,
        avatarUrl: map['avatar_url'] as String?,
      );
}

class ProfileRepository {
  ProfileRepository(this._client);
  final SupabaseClient _client;

  /// Fetches the profile row for [userId]. Returns null if not found.
  Future<UserProfile?> fetchById(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select('id, email, full_name, role, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      return UserProfile.fromMap(row);
    } on PostgrestException {
      rethrow;
    } on SocketException {
      rethrow;
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ProfileRepository(client);
});
