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
      throw Exception(
        'Unable to load species settings: ${response.statusCode}',
      );
    }
    final items = jsonDecode(response.body) as List;
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
        (jsonDecode(health.body)
                as Map)['capabilities']?['idempotent_capture_uploads'] !=
            true) {
      throw Exception(
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
      throw Exception(
        'Upload rejected (${response.statusCode}): ${response.body}',
      );
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  void close() => _client.close();
}
