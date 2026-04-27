import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import 'action_item.dart';

class ActionItemsRepository {
  ActionItemsRepository(this._client);

  final SupabaseClient _client;

  /// Mirrors src/hooks/useActionItems.ts: newest first, relying on RLS
  /// for current-user visibility.
  Future<List<ActionItem>> fetchAllForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const [];
    }

    final rows = await _client
        .from('action_items')
        .select()
        .order('created_at', ascending: false);

    return rows.map((row) => ActionItem.fromMap(_asRow(row))).toList();
  }

  Future<ActionItem> insert({
    required String meetingId,
    required String title,
    String? sessionId,
    String? assignedTo,
    DateTime? deadline,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = _requireCurrentUserId();
    final payload = <String, dynamic>{
      'meeting_id': meetingId,
      'owner_id': userId,
      'title': title,
    };
    if (sessionId != null) {
      payload['session_id'] = sessionId;
    }
    if (assignedTo != null) {
      payload['assigned_to'] = assignedTo;
    }
    if (deadline != null) {
      payload['deadline'] = deadline.toUtc().toIso8601String();
    }
    if (metadata != null) {
      payload['metadata'] = metadata;
    }

    final row = await _client
        .from('action_items')
        .insert(payload)
        .select()
        .single();
    return ActionItem.fromMap(_asRow(row));
  }

  Future<void> toggle(String id, bool isCompleted) async {
    await _client
        .from('action_items')
        .update({'is_completed': isCompleted})
        .eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('action_items').delete().eq('id', id);
  }

  /// Emits once for each public.action_items realtime change.
  Stream<void> subscribe() {
    final controller = StreamController<void>();
    final channel = _client.channel('action-items-realtime');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'action_items',
          callback: (_) {
            if (!controller.isClosed) {
              controller.add(null);
            }
          },
        )
        .subscribe();

    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };
    return controller.stream;
  }

  String _requireCurrentUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('A signed-in user is required.');
    }
    return userId;
  }
}

Map<String, dynamic> _asRow(dynamic value) {
  return Map<String, dynamic>.from(value as Map);
}

final actionItemsRepositoryProvider = Provider<ActionItemsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ActionItemsRepository(client);
});
