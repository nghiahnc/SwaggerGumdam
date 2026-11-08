import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  String? token;

  Future<dynamic> request(String method, String path, {Object? body}) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return _send(request);
  }

  /// Gửi một file dạng multipart/form-data, ô tên [field].
  Future<dynamic> upload(
    String path, {
    required String field,
    required String filename,
    required List<int> bytes,
  }) {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..headers['Accept'] = 'application/json'
      ..files.add(
        http.MultipartFile.fromBytes(field, bytes, filename: filename),
      );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    return _send(request, timeout: const Duration(seconds: 60));
  }

  Future<dynamic> _send(
    http.BaseRequest request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      dynamic payload;
      try {
        payload = response.body.isEmpty ? null : jsonDecode(response.body);
      } on FormatException {
        throw const ApiException('Máy chủ trả dữ liệu không hợp lệ.');
      }
      if (response.statusCode >= 400) {
        final data = payload is Map<String, dynamic> ? payload : null;
        final errors = data?['errors'];
        String? validation;
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) {
            validation = first.first.toString();
          }
        }
        throw ApiException(
          validation ??
              data?['title']?.toString() ??
              'Lỗi HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      return payload;
    } on TimeoutException {
      throw const ApiException('Kết nối quá thời gian. Hãy thử lại.');
    } on http.ClientException {
      throw const ApiException('Yêu cầu mạng thất bại. Hãy thử lại.');
    }
  }

  void close() => _client.close();
}
