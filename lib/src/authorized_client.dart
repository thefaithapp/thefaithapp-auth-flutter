import 'package:http/http.dart' as http;

import 'environment.dart';
import 'exceptions.dart';
import 'session_store.dart';

/// An HTTP client that adds the client key and current member bearer token.
final class TheFaithAuthorizedClient extends http.BaseClient {
  TheFaithAuthorizedClient({
    required String apiKey,
    required TheFaithAuthSessionStore sessionStore,
    http.Client? innerClient,
  }) : _apiKey = apiKey,
       _sessionStore = sessionStore,
       _innerClient = innerClient ?? http.Client();

  final String _apiKey;
  final TheFaithAuthSessionStore _sessionStore;
  final http.Client _innerClient;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_sameOrigin(request.url, TheFaithAppEnvironment.apiBaseUrl)) {
      throw const TheFaithAuthException(
        TheFaithAuthErrorCode.unauthorizedHost,
        'The authorized client can only send requests to the configured TheFaithApp API host.',
      );
    }

    final session = await _sessionStore.read();
    if (session == null || session.isExpired) {
      throw const TheFaithAuthException(
        TheFaithAuthErrorCode.notAuthenticated,
        'Sign in before calling a protected TheFaithApp endpoint.',
      );
    }

    request.headers['X-API-Key'] = _apiKey;
    request.headers['Authorization'] =
        '${session.tokenType} ${session.accessToken}';
    request.headers.putIfAbsent('Accept', () => 'application/json');
    return _innerClient.send(request);
  }

  @override
  void close() => _innerClient.close();

  bool _sameOrigin(Uri first, Uri second) =>
      first.scheme.toLowerCase() == second.scheme.toLowerCase() &&
      first.host.toLowerCase() == second.host.toLowerCase() &&
      first.port == second.port;
}
