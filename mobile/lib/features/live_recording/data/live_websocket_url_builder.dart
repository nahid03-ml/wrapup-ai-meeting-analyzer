import 'live_session_models.dart';

Uri buildLiveTranscriptionWebSocketUri({
  required String backendBaseUrl,
  required String sessionId,
  required String languageCode,
  required String accessToken,
}) {
  final trimmedBaseUrl = backendBaseUrl.trim();
  if (trimmedBaseUrl.isEmpty) {
    throw ArgumentError.value(
      backendBaseUrl,
      'backendBaseUrl',
      'Backend base URL is required.',
    );
  }

  final baseUri = Uri.parse(trimmedBaseUrl);
  final scheme = _webSocketSchemeFor(baseUri.scheme);
  final basePathSegments = baseUri.pathSegments
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);

  return Uri(
    scheme: scheme,
    userInfo: baseUri.userInfo,
    host: baseUri.host,
    port: baseUri.hasPort ? baseUri.port : null,
    pathSegments: <String>[
      ...basePathSegments,
      'ws',
      'live-transcription',
      sessionId,
    ],
    queryParameters: <String, String>{
      LiveTranscriptionProtocol.languageQueryParam: languageCode,
      LiveTranscriptionProtocol.tokenQueryParam: accessToken,
    },
  );
}

String buildLiveTranscriptionWebSocketUrl({
  required String backendBaseUrl,
  required String sessionId,
  required String languageCode,
  required String accessToken,
}) {
  return buildLiveTranscriptionWebSocketUri(
    backendBaseUrl: backendBaseUrl,
    sessionId: sessionId,
    languageCode: languageCode,
    accessToken: accessToken,
  ).toString();
}

String _webSocketSchemeFor(String scheme) {
  return switch (scheme.toLowerCase()) {
    'http' => 'ws',
    'https' => 'wss',
    'ws' => 'ws',
    'wss' => 'wss',
    _ => throw ArgumentError.value(
      scheme,
      'backendBaseUrl',
      'Backend base URL must use http, https, ws, or wss.',
    ),
  };
}
