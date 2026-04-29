import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config/env.dart';

void main() {
  setUp(dotenv.clean);
  tearDown(dotenv.clean);

  test('Env prefers VITE keys and trims backend trailing slash', () {
    _loadEnv('''
VITE_SUPABASE_URL=https://vite-project.supabase.co
SUPABASE_URL=https://legacy-project.supabase.co
VITE_SUPABASE_ANON_KEY=vite-public-anon-key
SUPABASE_ANON_KEY=legacy-public-anon-key
VITE_BACKEND_URL=https://backend.example.com/
BACKEND_URL=https://legacy-backend.example.com
''');

    expect(Env.supabaseUrl, 'https://vite-project.supabase.co');
    expect(Env.supabaseAnonKey, 'vite-public-anon-key');
    expect(Env.backendUrl, 'https://backend.example.com');
  });

  test('Env falls back to legacy public keys', () {
    _loadEnv('''
SUPABASE_URL=https://legacy-project.supabase.co
SUPABASE_ANON_KEY=legacy-public-anon-key
BACKEND_URL=https://legacy-backend.example.com
''');

    expect(Env.supabaseUrl, 'https://legacy-project.supabase.co');
    expect(Env.supabaseAnonKey, 'legacy-public-anon-key');
    expect(Env.backendUrl, 'https://legacy-backend.example.com');
  });

  test('Env reports missing Supabase URL clearly', () {
    _loadEnv('''
VITE_SUPABASE_ANON_KEY=public-anon-key
VITE_BACKEND_URL=https://backend.example.com
''');

    expect(
      () => Env.supabaseUrl,
      _throwsStateError('Supabase URL is missing.'),
    );
  });

  test('Env reports missing Supabase anon key clearly', () {
    _loadEnv('''
VITE_SUPABASE_URL=https://project.supabase.co
VITE_BACKEND_URL=https://backend.example.com
''');

    expect(
      () => Env.supabaseAnonKey,
      _throwsStateError('Supabase anon key is missing.'),
    );
  });

  test('Env reports missing backend URL clearly', () {
    _loadEnv('''
VITE_SUPABASE_URL=https://project.supabase.co
VITE_SUPABASE_ANON_KEY=public-anon-key
''');

    expect(() => Env.backendUrl, _throwsStateError('Backend URL is missing.'));
  });

  test('Env rejects backend health check URLs', () {
    _loadEnv('''
VITE_SUPABASE_URL=https://project.supabase.co
VITE_SUPABASE_ANON_KEY=public-anon-key
VITE_BACKEND_URL=https://backend.example.com/healthz
''');

    expect(
      () => Env.backendUrl,
      _throwsStateError('Backend URL must be the base URL, not /healthz.'),
    );
  });

  test('Env rejects backend WebSocket path URLs', () {
    _loadEnv('''
VITE_SUPABASE_URL=https://project.supabase.co
VITE_SUPABASE_ANON_KEY=public-anon-key
VITE_BACKEND_URL=https://backend.example.com/ws/live-transcription
''');

    expect(
      () => Env.backendUrl,
      _throwsStateError(
        'Backend URL must be the base URL, not the WebSocket path.',
      ),
    );
  });

  test('Env rejects using the Supabase URL as the backend URL', () {
    _loadEnv('''
VITE_SUPABASE_URL=https://project.supabase.co
VITE_SUPABASE_ANON_KEY=public-anon-key
VITE_BACKEND_URL=https://project.supabase.co/
''');

    expect(
      () => Env.backendUrl,
      _throwsStateError(
        'Backend URL is using the Supabase URL. Set VITE_BACKEND_URL to the '
        'deployed FastAPI backend base URL.',
      ),
    );
  });
}

void _loadEnv(String envString) {
  dotenv.loadFromString(envString: envString);
}

Matcher _throwsStateError(String message) {
  return throwsA(
    isA<StateError>().having((error) => error.message, 'message', message),
  );
}
