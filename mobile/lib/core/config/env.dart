import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized access to environment variables loaded from `.env`.
///
/// Call [Env.load] once at app startup before reading any value.
class Env {
  Env._();

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
    _validate();
    _logLoadedKeys();
  }

  static String get supabaseUrl {
    return _requiredAny(
      preferredKey: 'VITE_SUPABASE_URL',
      fallbackKey: 'SUPABASE_URL',
      missingMessage: 'Supabase URL is missing.',
    );
  }

  static String get supabaseAnonKey {
    return _requiredAny(
      preferredKey: 'VITE_SUPABASE_ANON_KEY',
      fallbackKey: 'SUPABASE_ANON_KEY',
      missingMessage: 'Supabase anon key is missing.',
    );
  }

  static String get backendUrl {
    final value = _trimTrailingSlashes(
      _requiredAny(
        preferredKey: 'VITE_BACKEND_URL',
        fallbackKey: 'BACKEND_URL',
        missingMessage: 'Backend URL is missing.',
      ),
    );
    _validateBackendUrl(value);

    final configuredSupabaseUrl = _firstConfiguredValue(
      preferredKey: 'VITE_SUPABASE_URL',
      fallbackKey: 'SUPABASE_URL',
    );
    if (configuredSupabaseUrl != null &&
        _sameConfiguredUrl(value, configuredSupabaseUrl)) {
      throw StateError(
        'Backend URL is using the Supabase URL. Set VITE_BACKEND_URL to the '
        'deployed FastAPI backend base URL.',
      );
    }
    return value;
  }

  @Deprecated('Use Env.backendUrl with live_websocket_url_builder instead.')
  static String get backendWsUrl {
    final uri = Uri.parse(backendUrl);
    final scheme = switch (uri.scheme.toLowerCase()) {
      'http' => 'ws',
      'https' => 'wss',
      'ws' => 'ws',
      'wss' => 'wss',
      _ => uri.scheme,
    };
    return uri.replace(scheme: scheme).toString();
  }

  static void _validate() {
    // Touch each required key so missing config fails fast at startup
    // instead of deep inside a feature.
    supabaseUrl;
    supabaseAnonKey;
    backendUrl;
  }

  static String _requiredAny({
    required String preferredKey,
    required String fallbackKey,
    required String missingMessage,
  }) {
    final value = _firstConfiguredValue(
      preferredKey: preferredKey,
      fallbackKey: fallbackKey,
    );
    if (value == null) {
      throw StateError(missingMessage);
    }
    return value;
  }

  static String? _firstConfiguredValue({
    required String preferredKey,
    required String fallbackKey,
  }) {
    final preferred = dotenv.maybeGet(preferredKey)?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      return preferred;
    }

    final fallback = dotenv.maybeGet(fallbackKey)?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }

    return null;
  }

  static String _trimTrailingSlashes(String value) {
    var trimmed = value.trim();
    while (trimmed.endsWith('/') && !trimmed.endsWith('://')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static void _validateBackendUrl(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('/healthz')) {
      throw StateError('Backend URL must be the base URL, not /healthz.');
    }
    if (lower.contains('/ws/live-transcription')) {
      throw StateError(
        'Backend URL must be the base URL, not the WebSocket path.',
      );
    }
  }

  static bool _sameConfiguredUrl(String left, String right) {
    return _trimTrailingSlashes(left).toLowerCase() ==
        _trimTrailingSlashes(right).toLowerCase();
  }

  static void _logLoadedKeys() {
    if (!kDebugMode) {
      return;
    }

    debugPrint('Env loaded: supabaseUrl=yes, anonKey=yes, backendUrl=yes');
  }
}
