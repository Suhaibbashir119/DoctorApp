import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_response.dart';
import 'mock_api_client.dart';

/// Something that can send requests to the backend.
///
/// There are two implementations:
///  - [HttpApiClient]  - makes real HTTP calls.
///  - [MockApiClient]  - returns fake data from memory (used for the demo/tests).
///
/// Every method returns the decoded JSON body as a `Map`, or throws
/// [ApiException] / [ApiUnavailable] when something goes wrong.
abstract class ApiClient {
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query});

  Future<Map<String, dynamic>> post(String path, {Object? body});

  Future<Map<String, dynamic>> put(String path, {Object? body});
}

/// Helper singleton client getter
ApiClient get apiClient => ApiConfig.useMockApi
    ? _mockApiClient
    : _httpApiClient;

final MockApiClient _mockApiClient = MockApiClient();
final HttpApiClient _httpApiClient = HttpApiClient(getToken: () => currentAuthToken);

String? currentAuthToken;
String currentDoctorName = '';

/// Returns the current auth token (or null when the doctor is signed out).
/// The [HttpApiClient] adds it as an `Authorization: Bearer <token>` header.
typedef GetToken = String? Function();

class HttpApiClient implements ApiClient {
  HttpApiClient({required this.getToken, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final GetToken getToken;
  final http.Client _http;

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) {
    final url = _buildUrl(path, query);
    debugPrint('HTTP GET -> $url');
    return _readResponse(_http.get(url, headers: _buildHeaders()), path);
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) {
    final url = _buildUrl(path);
    final encodedBody = jsonEncode(body ?? {});
    debugPrint('HTTP POST -> $url | Body: $encodedBody');
    return _readResponse(
      _http.post(url, headers: _buildHeaders(), body: encodedBody),
      path,
    );
  }

  @override
  Future<Map<String, dynamic>> put(String path, {Object? body}) {
    final url = _buildUrl(path);
    final encodedBody = jsonEncode(body ?? {});
    debugPrint('HTTP PUT -> $url | Body: $encodedBody');
    return _readResponse(
      _http.put(url, headers: _buildHeaders(), body: encodedBody),
      path,
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────

  Uri _buildUrl(String path, [Map<String, dynamic>? query]) {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');
    if (query == null || query.isEmpty) return url;

    // Turn every query value into a string, skipping nulls.
    final params = <String, String>{...url.queryParameters};
    query.forEach((key, value) {
      if (value != null) params[key] = value.toString();
    });
    return url.replace(queryParameters: params);
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Waits for the HTTP call, then turns the result into a `Map` or an error.
  Future<Map<String, dynamic>> _readResponse(
      Future<http.Response> request,
      String path,
      ) async {
    http.Response response;
    try {
      response = await request.timeout(ApiConfig.timeout);
    } on TimeoutException {
      debugPrint('HTTP Timeout on $path');
      throw ApiUnavailable('The server at ${ApiConfig.baseUrl} took too long to respond.');
    } catch (e) {
      debugPrint('HTTP Error on $path: $e');
      throw ApiUnavailable('Cannot connect to ${ApiConfig.baseUrl}. Please check internet or server status.');
    }

    debugPrint('HTTP Response [$path] (${response.statusCode}): ${response.body}');

    final body = _decodeBody(response.body);
    final isOk = response.statusCode >= 200 && response.statusCode < 300;

    if (isOk && body['success'] != false) {
      return body;
    }

    final message = body['message']?.toString() ??
        'Request failed with status code (${response.statusCode}).';
    throw ApiException(message, statusCode: response.statusCode);
  }

  Map<String, dynamic> _decodeBody(String raw) {
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }
}
