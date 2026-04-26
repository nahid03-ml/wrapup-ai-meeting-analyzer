import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'supabase_provider.dart';

/// Dio HTTP client configured for the FastAPI backend.
///
/// - Base URL = BACKEND_URL from .env.
/// - Auth interceptor: attaches `Authorization: Bearer <supabase_access_token>`
///   on every request, mirroring how the website calls the FastAPI backend
///   (see src/lib/session-processing.ts in the web repo).
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.backendUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final client = ref.read(supabaseClientProvider);
        final session = client.auth.currentSession;
        final token = session?.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
});
