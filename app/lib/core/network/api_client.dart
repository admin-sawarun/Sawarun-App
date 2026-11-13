import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// A failed backend call. Carries the HTTP status so callers can react to
/// specific cases (e.g. 401 when a sensitive action needs a fresh login).
class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  @override
  String toString() => 'Exception: $message';
}

/// Thin helper for authenticated JSON calls to the Savarun Node backend.
///
/// Every backend route sits behind `requireAuth`, so each call carries the
/// user's Firebase ID token as a bearer token.
class ApiClient {
  const ApiClient();

  Future<Map<String, dynamic>> get(String url) async {
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse(url),
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> patch(String url, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse(url),
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> put(String url, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse(url),
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> delete(String url) async {
    final res = await http.delete(Uri.parse(url), headers: await _headers());
    return _decode(res);
  }

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    return {'Authorization': 'Bearer ${await user.getIdToken()}'};
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } on FormatException {
      json = null;
    }
    // 2xx are all success (POSTs that create return 201).
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (!ok || json == null || json['ok'] != true) {
      throw ApiException(
        (json?['error'] ?? 'Request failed (${res.statusCode})').toString(),
        res.statusCode,
      );
    }
    return json;
  }
}
