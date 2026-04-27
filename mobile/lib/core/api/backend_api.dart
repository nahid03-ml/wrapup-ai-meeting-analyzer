import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dio_provider.dart';
import 'backend_exception.dart';

class BackendApi {
  // TODO(phase 5+): replace Map<String, dynamic> return types with typed
  // response classes such as ProcessSessionResponse, SessionStatusResponse,
  // AskResponse, SuggestTimesResponse, CreateShareLinkResponse, and
  // SharedMeetingResponse. Wrap incrementally as each endpoint is consumed
  // by the UI instead of doing all response models at once.
  BackendApi(this._dio);

  final Dio _dio;

  Future<void> processSession(String sessionId) async {
    await _request(() {
      return _dio.post<void>('/sessions/${_path(sessionId)}/process');
    });
  }

  Future<Map<String, dynamic>> getSessionStatus(String sessionId) async {
    return _requestMap(() {
      return _dio.get('/sessions/${_path(sessionId)}/status');
    });
  }

  Future<Map<String, dynamic>> getSessionAudioUrl(String sessionId) async {
    return _requestMap(() {
      return _dio.get('/sessions/${_path(sessionId)}/audio-url');
    });
  }

  Future<Map<String, dynamic>> askAi({
    required String sessionId,
    required String question,
  }) async {
    return _requestMap(() {
      return _dio.post(
        '/sessions/${_path(sessionId)}/ask',
        data: {'question': question},
      );
    });
  }

  Future<void> deleteMeeting(String meetingId) async {
    await _request(() {
      return _dio.delete<void>('/meetings/${_path(meetingId)}');
    });
  }

  Future<Map<String, dynamic>> createShareLink(String meetingId) async {
    return _requestMap(() {
      return _dio.post('/meetings/${_path(meetingId)}/share-link');
    });
  }

  Future<Map<String, dynamic>> getSharedMeeting(String token) async {
    return _requestMap(() {
      return _dio.get('/share/${_path(token)}');
    });
  }

  Future<Map<String, dynamic>> suggestMeetingTimes(
    Map<String, dynamic> payload,
  ) async {
    return _requestMap(() {
      return _dio.post('/meetings/suggest-times', data: payload);
    });
  }

  Future<Map<String, dynamic>> checkBackendHealth() async {
    return _requestMap(() {
      return _dio.get('/healthz');
    });
  }

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _toBackendException(error);
    }
  }

  Future<Map<String, dynamic>> _requestMap(
    Future<Response<dynamic>> Function() request,
  ) async {
    final response = await _request(request);
    return _asMap(response.data);
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value == null) {
    return <String, dynamic>{};
  }
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return {'data': value};
}

BackendException _toBackendException(DioException error) {
  final response = error.response;
  final statusCode = response?.statusCode;
  final details = response?.data ?? error.error;
  final message =
      _extractMessage(response?.data) ??
      response?.statusMessage ??
      error.message ??
      'Backend request failed';

  if (statusCode == 401 || statusCode == 403) {
    return UnauthorizedBackendException(
      message,
      statusCode: statusCode,
      details: details,
    );
  }
  if (statusCode == 404) {
    return NotFoundBackendException(
      message,
      statusCode: statusCode,
      details: details,
    );
  }
  if (statusCode != null && statusCode >= 500) {
    return ServerBackendException(
      message,
      statusCode: statusCode,
      details: details,
    );
  }
  return UnknownBackendException(
    message,
    statusCode: statusCode,
    details: details,
  );
}

String? _extractMessage(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is Map) {
    for (final key in const ['detail', 'message', 'error']) {
      final message = value[key];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      if (message != null) {
        return message.toString();
      }
    }
  }
  return null;
}

String _path(String value) => Uri.encodeComponent(value);

final backendApiProvider = Provider<BackendApi>((ref) {
  final dio = ref.watch(dioProvider);
  return BackendApi(dio);
});
