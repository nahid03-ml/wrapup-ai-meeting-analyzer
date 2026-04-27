import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/supabase_provider.dart';

class EdgeFunctionsApi {
  EdgeFunctionsApi(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> checkSubscription() async {
    final response = await _client.functions.invoke('check-subscription');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> createCheckoutSession({
    required String planType,
    required String origin,
  }) async {
    final response = await _client.functions.invoke(
      'create-checkout-session',
      headers: {'origin': origin},
      body: {'planType': planType},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> customerPortal() async {
    final response = await _client.functions.invoke('customer-portal');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> suggestTimes(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.functions.invoke(
      'suggest-times',
      body: payload,
    );
    return _asMap(response.data);
  }

  Future<bool> checkEmailExists({required String email}) async {
    final response = await _client.functions.invoke(
      'check-email-exists',
      body: {'email': email},
    );
    final data = _asMap(response.data);
    return data['exists'] == true;
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

final edgeFunctionsApiProvider = Provider<EdgeFunctionsApi>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return EdgeFunctionsApi(client);
});
