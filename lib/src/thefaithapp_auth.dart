import 'package:http/http.dart' as http;

import 'auth_client.dart';
import 'models.dart';

/// The production entry point for TheFaithApp hosted member authentication.
///
/// The client API key is the only required configuration. The API and hosted
/// auth origins are fixed by the package, and the callback is derived from the
/// consuming application's Android application ID or iOS bundle ID.
final class TheFaithAppAuth {
  TheFaithAppAuth({required String apiKey})
    : _client = TheFaithAppAuthClient(apiKey: apiKey);

  final TheFaithAppAuthClient _client;

  /// The callback URI to save in `Settings > Developer Access`.
  Future<Uri> get callbackUri => _client.callbackUri;

  /// Opens hosted sign-in and returns a securely persisted member session.
  Future<TheFaithAuthSession> signIn() => _client.signIn();

  /// Returns the securely saved session, if the member is signed in.
  Future<TheFaithAuthSession?> currentSession() => _client.currentSession();

  /// Returns the current bearer token, if available.
  Future<String?> accessToken() => _client.accessToken();

  /// Builds a production-only HTTP client that injects both auth headers.
  http.Client authorizedClient() => _client.authorizedClient();

  /// Resolves a relative v1 path against the production API origin.
  Uri apiUri(String path, {Map<String, String>? queryParameters}) =>
      _client.apiUri(path, queryParameters: queryParameters);

  /// Revokes the current bearer token and clears its local secure copy.
  Future<void> signOut() => _client.signOut();

  /// Releases the SDK's internal HTTP client.
  void dispose() => _client.dispose();
}
