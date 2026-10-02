import 'dart:convert';

import 'package:http/http.dart' as http;

class RouteStop {
  const RouteStop({
    required this.id,
    required this.latitude,
    required this.longitude,
  });
  final String id;
  final double latitude;
  final double longitude;
}

class RouteResult {
  const RouteResult({
    required this.durationSeconds,
    required this.distanceMeters,
    required this.encodedPolyline,
  });
  final int durationSeconds;
  final int distanceMeters;
  final String encodedPolyline;
}

abstract interface class RouteService {
  Future<RouteResult?> calculate(List<RouteStop> stops);
}

/// Calls our Supabase Edge Function, never Google directly from the app.
/// The Edge Function owns the Google key, quotas, caching and billing limits.
class GoogleRoutesService implements RouteService {
  GoogleRoutesService({
    http.Client? client,
    String? endpoint,
    String? accessToken,
    String? anonKey,
  }) : _client = client ?? http.Client(),
       _endpoint =
           endpoint ?? const String.fromEnvironment('ROUTES_FUNCTION_URL'),
       _accessToken = accessToken ?? '',
       _anonKey = anonKey ?? const String.fromEnvironment('SUPABASE_ANON_KEY');

  final http.Client _client;
  final String _endpoint;
  final String _accessToken;
  final String _anonKey;

  @override
  Future<RouteResult?> calculate(List<RouteStop> stops) async {
    if (_endpoint.isEmpty ||
        _accessToken.isEmpty ||
        _anonKey.isEmpty ||
        stops.length < 2) {
      return null;
    }
    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'authorization': 'Bearer $_accessToken',
        'apikey': _anonKey,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'stops': stops
            .map(
              (stop) => {
                'id': stop.id,
                'latitude': stop.latitude,
                'longitude': stop.longitude,
              },
            )
            .toList(),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return RouteResult(
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toInt() ?? 0,
      encodedPolyline: json['encodedPolyline'] as String? ?? '',
    );
  }
}
