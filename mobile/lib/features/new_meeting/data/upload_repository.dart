import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';

const kMeetingFilesBucket = 'meeting-files';
const kAllowedUploadExtensions = <String>{
  'mp3',
  'wav',
  'm4a',
  'aac',
  'ogg',
  'flac',
  'mp4',
  'mov',
  'webm',
  'mkv',
};
const kUploadWarningThresholdBytes = 200 * 1024 * 1024;
const kUploadHardCapBytes = 1024 * 1024 * 1024;

class UploadRepository {
  UploadRepository(this._client);

  final SupabaseClient _client;

  Future<String> uploadAudioFile({
    required File file,
    required String userId,
    required String meetingId,
    int? timestampMs,
  }) async {
    final objectPath =
        '$userId/$meetingId/${timestampMs ?? DateTime.now().millisecondsSinceEpoch}-${sanitizeUploadFilename(file)}';

    await _client.storage.from(kMeetingFilesBucket).upload(objectPath, file);
    return '$kMeetingFilesBucket/$objectPath';
  }

  Future<void> deleteUploadedFile(String storageRef) async {
    final objectPath = storageObjectPathFromRef(storageRef);
    if (objectPath == null || objectPath.isEmpty) {
      return;
    }

    await _client.storage.from(kMeetingFilesBucket).remove([objectPath]);
  }
}

String sanitizeUploadFilename(File file) {
  final originalName = file.uri.pathSegments.isEmpty
      ? 'recording'
      : file.uri.pathSegments.last;
  final safeName = originalName
      .trim()
      .replaceAll(RegExp(r'[\\/]+'), '_')
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp('_+'), '_')
      .replaceAll(RegExp(r'^\.+'), '')
      .replaceAll(RegExp(r'\.+$'), '');

  return safeName.isEmpty ? 'recording' : safeName;
}

String? storageObjectPathFromRef(String storageRef) {
  final trimmed = storageRef.trim();
  const prefix = '$kMeetingFilesBucket/';
  if (!trimmed.startsWith(prefix)) {
    return null;
  }
  return trimmed.substring(prefix.length).trim();
}

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return UploadRepository(client);
});
