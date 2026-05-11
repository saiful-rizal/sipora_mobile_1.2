import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class LocalhostApiService {
  LocalhostApiService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl {
    final androidEnv = dotenv.env['API_BASE_URL_ANDROID']?.trim();
    final webEnv = dotenv.env['API_BASE_URL_WEB']?.trim();
    final desktopEnv = dotenv.env['API_BASE_URL_DESKTOP']?.trim();
    final genericEnv = dotenv.env['API_BASE_URL']?.trim();

    if (kIsWeb) {
      if (webEnv != null && webEnv.isNotEmpty) return webEnv;
      if (genericEnv != null && genericEnv.isNotEmpty) return genericEnv;
      return 'http://localhost/sipora_api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (androidEnv != null && androidEnv.isNotEmpty) return androidEnv;
      if (genericEnv != null && genericEnv.isNotEmpty) return genericEnv;
      return 'http://10.0.2.2/sipora_api';
    }

    if (desktopEnv != null && desktopEnv.isNotEmpty) return desktopEnv;
    if (genericEnv != null && genericEnv.isNotEmpty) return genericEnv;
    return 'http://localhost/sipora_api';
  }

  Uri resolveFileUri(String filePath) {
    final trimmed = filePath.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('filePath cannot be empty');
    }

    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }

    final base = _baseUrl.endsWith('/') ? _baseUrl : '$_baseUrl/';
    final relativePath = trimmed.startsWith('/')
        ? trimmed.substring(1)
        : trimmed;
    return Uri.parse(base).resolve(relativePath);
  }

  Uri _uri(String endpoint, [Map<String, dynamic>? query]) {
    final cleanEndpoint = endpoint.startsWith('/')
        ? endpoint.substring(1)
        : endpoint;
    final raw = '$_baseUrl/$cleanEndpoint';
    final uri = Uri.parse(raw);

    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: query.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _client.get(
      _uri(endpoint, query),
      headers: _jsonHeaders,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    final response = await _client.post(
      _uri(endpoint, query),
      headers: _jsonHeaders,
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    final response = await _client.put(
      _uri(endpoint, query),
      headers: _jsonHeaders,
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    final response = await _client.delete(
      _uri(endpoint, query),
      headers: _jsonHeaders,
      body: body == null ? null : jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Map<String, String> get _jsonHeaders => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      } else {
        payload = {'data': decoded};
      }
    } catch (_) {
      payload = {'message': response.body};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }

    final errorMessage =
        payload['message']?.toString() ??
        'Request failed (${response.statusCode})';
    throw Exception(errorMessage);
  }

  void dispose() {
    _client.close();
  }
}
