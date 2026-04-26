import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized access to environment variables loaded from `.env`.
///
/// Call [Env.load] once at app startup before reading any value.
class Env {
  Env._();

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
    _validate();
  }

  static String get supabaseUrl => _required('SUPABASE_URL');
  static String get supabaseAnonKey => _required('SUPABASE_ANON_KEY');
  static String get backendUrl => _required('BACKEND_URL');
  static String get backendWsUrl => _required('BACKEND_WS_URL');

  static String _required(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing required env var "$key". '
        'Check mobile/.env against mobile/.env.example.',
      );
    }
    return value;
  }

  static void _validate() {
    // Touch each required key so missing config fails fast at startup
    // instead of deep inside a feature.
    supabaseUrl;
    supabaseAnonKey;
    backendUrl;
    backendWsUrl;
  }
}
