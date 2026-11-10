import 'dart:convert';

import 'package:http/http.dart' as http;

import 'species.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);
const apiToken = String.fromEnvironment('API_TOKEN');
const authenticatedOperatorId = String.fromEnvironment(
  'OPERATOR_ID',
  defaultValue: 'operator-1',
);

class RegistryApiError implements Exception {
  final int status;
  final String message;
  const RegistryApiError(this.status, this.message);
  @override
  String toString() => 'Registry request rejected ($status): $message';
}

class ApiError implements Exception {
  final int status;
  final String message;
  const ApiError(this.status, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _client;
  final String _token;
  final String _baseUrl;

  ApiClient({
    http.Client? client,
    String token = apiToken,
    String baseUrl = apiBaseUrl,
  }) : _client = client ?? http.Client(),
       _token = token,
       _baseUrl = baseUrl;
  Uri endpoint(String path) =>
      Uri.parse('${_baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
  bool get hasCredentials => _token.trim().isNotEmpty;
  Map<String, String> get _headers {
    if (_token.isEmpty) {
      throw Exception('Configure an operator API_TOKEN before connecting');
    }
    return {'Authorization': 'Bearer $_token'};
  }

  Future<List<SpeciesConfig>> loadSpecies() async {
    final response = await _client
        .get(endpoint('/api/v1/species'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw ApiError(
        response.statusCode,
        'Unable to load species settings: ${response.statusCode}',
      );
    }
    final items = jsonDecode(utf8.decode(response.bodyBytes)) as List;
    return items
        .map(
          (item) =>
              SpeciesConfig.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .where((config) => config.enabled)
        .toList();
  }

  Future<Map<String, dynamic>> upload(
    String imagePath,
    Map<String, dynamic> metadata,
    String requestKey,
  ) async {
    final headers = _headers;
    final health = await _client
        .get(endpoint('/health'), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (health.statusCode != 200 ||
        (jsonDecode(utf8.decode(health.bodyBytes))
                as Map)['capabilities']?['idempotent_capture_uploads'] !=
            true) {
      throw ApiError(
        health.statusCode,
        'Update the backend before queued uploads: safe upload retries are unavailable.',
      );
    }
    final request = http.MultipartRequest('POST', endpoint('/api/v1/captures'))
      ..headers.addAll(headers)
      ..headers['Idempotency-Key'] = requestKey
      ..fields['metadata'] = jsonEncode(metadata)
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));
    final response = await (() async {
      return http.Response.fromStream(await _client.send(request));
    })().timeout(const Duration(seconds: 90));
    if (response.statusCode != 201) {
      throw ApiError(
        response.statusCode,
        'Upload rejected (${response.statusCode}): ${utf8.decode(response.bodyBytes)}',
      );
    }
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
  }

  Future<dynamic> registryGet(String path) async {
    final response = await _client
        .get(endpoint(path), headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw RegistryApiError(
        response.statusCode,
        utf8.decode(response.bodyBytes),
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<Map<String, dynamic>> registryPost(
    String path,
    Map<String, dynamic> body,
    String key,
  ) async {
    final response = await _client
        .post(
          endpoint(path),
          headers: {
            ..._headers,
            'Content-Type': 'application/json',
            'Idempotency-Key': key,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw RegistryApiError(
        response.statusCode,
        utf8.decode(response.bodyBytes),
      );
    }
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
  }

  void close() => _client.close();
}
