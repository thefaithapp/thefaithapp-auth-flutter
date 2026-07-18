import 'dart:convert';

import 'package:http/http.dart' as http;

import 'environment.dart';
import 'exceptions.dart';
import 'models.dart';

final class HostedAuthStart {
  const HostedAuthStart(this.authorizationUrl);

  final Uri authorizationUrl;
}

final class HostedAuthApi {
  const HostedAuthApi({required this.apiKey, required http.Client client})
    : _client = client;

  final String apiKey;
  final http.Client _client;

  Future<HostedAuthStart> start({
    required Uri redirectUri,
    required String state,
    required String codeChallenge,
  }) async {
    final payload = await _post('/v1/auth/start', <String, Object?>{
      'client_key': apiKey,
      'redirect_uri': redirectUri.toString(),
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });
    final authUrl = payload['auth_url'];
    if (authUrl is! String || authUrl.isEmpty) {
      throw const TheFaithAuthException(
        TheFaithAuthErrorCode.invalidResponse,
        'The hosted auth URL is missing from the server response.',
      );
    }

    final parsed = Uri.tryParse(authUrl);
    if (parsed == null ||
        parsed.host.isEmpty ||
        !_sameOrigin(parsed, TheFaithAppEnvironment.hostedAuthBaseUrl)) {
      throw const TheFaithAuthException(
        TheFaithAuthErrorCode.invalidResponse,
        'The server returned a hosted auth URL outside the production origin.',
      );
    }
    return HostedAuthStart(parsed);
  }

  Future<TheFaithAuthSession> exchange({
    required String code,
    required Uri redirectUri,
    required String codeVerifier,
  }) async {
    final payload = await _post('/v1/auth/token', <String, Object?>{
      'client_key': apiKey,
      'code': code,
      'redirect_uri': redirectUri.toString(),
      'code_verifier': codeVerifier,
    });

    try {
      return TheFaithAuthSession.fromJson(<String, dynamic>{
        ...payload,
        'received_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on FormatException catch (error) {
      throw TheFaithAuthException(
        TheFaithAuthErrorCode.invalidResponse,
        'The token response is incomplete.',
        cause: error,
      );
    }
  }

  Future<void> logout(TheFaithAuthSession session) async {
    await _post(
      '/v1/auth/logout',
      const <String, Object?>{},
      headers: <String, String>{
        'X-API-Key': apiKey,
        'Authorization': '${session.tokenType} ${session.accessToken}',
      },
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body, {
    Map<String, String>? headers,
  }) async {
    http.Response response;
    try {
      response = await _client.post(
        TheFaithAppEnvironment.apiBaseUrl.resolve(path),
        headers: <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...?headers,
        },
        body: jsonEncode(body),
      );
    } on Exception catch (error) {
      throw TheFaithAuthException(
        TheFaithAuthErrorCode.network,
        'The TheFaithApp API could not be reached.',
        cause: error,
      );
    }

    final payload = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TheFaithAuthException(
        TheFaithAuthErrorCode.server,
        _errorMessage(payload),
        statusCode: response.statusCode,
      );
    }
    return payload;
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      // Converted into a stable SDK error below.
    }

    throw TheFaithAuthException(
      TheFaithAuthErrorCode.invalidResponse,
      'The TheFaithApp API returned an invalid response.',
      statusCode: response.statusCode,
    );
  }

  String _errorMessage(Map<String, dynamic> payload) {
    for (final key in const <String>['message', 'error_message', 'error']) {
      final value = payload[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }

    final errors = payload['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty && value.first is String) {
          return value.first as String;
        }
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }
    return 'The hosted authentication request failed.';
  }

  bool _sameOrigin(Uri first, Uri second) =>
      first.scheme.toLowerCase() == second.scheme.toLowerCase() &&
      first.host.toLowerCase() == second.host.toLowerCase() &&
      first.port == second.port;
}
