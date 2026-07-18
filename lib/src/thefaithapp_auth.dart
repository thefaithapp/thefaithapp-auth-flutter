import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_browser.dart';
import 'authorized_client.dart';
import 'callback_uri_provider.dart';
import 'exceptions.dart';
import 'hosted_auth_api.dart';
import 'models.dart';
import 'pkce.dart';
import 'session_store.dart';

/// The main entry point for hosted member authentication.
final class TheFaithAppAuth {
  TheFaithAppAuth({
    required String apiKey,
    Uri? apiBaseUrl,
    Uri? redirectUri,
    bool allowInsecureHttpForTesting = false,
    TheFaithAuthBrowser? browser,
    TheFaithCallbackUriProvider? callbackUriProvider,
    TheFaithAuthSessionStore? sessionStore,
    http.Client? httpClient,
  }) : apiKey = _validateApiKey(apiKey),
       apiBaseUrl = _validateBaseUrl(
         apiBaseUrl ?? Uri.parse('https://api.thefaithapp.com'),
         allowInsecureHttpForTesting: allowInsecureHttpForTesting,
       ),
       _redirectUri = redirectUri,
       _browser = browser ?? const TheFaithSystemAuthBrowser(),
       _callbackUriProvider =
           callbackUriProvider ?? const TheFaithPackageCallbackUriProvider(),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null {
    _sessionStore =
        sessionStore ?? TheFaithSecureSessionStore(apiKey: this.apiKey);
    _api = HostedAuthApi(
      apiKey: this.apiKey,
      baseUrl: this.apiBaseUrl,
      allowInsecureHttpForTesting: allowInsecureHttpForTesting,
      client: _httpClient,
    );
  }

  final String apiKey;
  final Uri apiBaseUrl;
  final Uri? _redirectUri;
  final TheFaithAuthBrowser _browser;
  final TheFaithCallbackUriProvider _callbackUriProvider;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  late final TheFaithAuthSessionStore _sessionStore;
  late final HostedAuthApi _api;
  bool _signInInProgress = false;

  /// The callback URI to save in `Settings > Developer Access`.
  Future<Uri> get callbackUri async {
    final uri = _redirectUri ?? await _callbackUriProvider.resolve();
    if (!uri.hasScheme || uri.scheme.isEmpty) {
      throw const TheFaithAuthException(
        TheFaithAuthErrorCode.configuration,
        'The hosted auth redirect URI must include a scheme.',
      );
    }
    return uri;
  }

  /// Opens hosted sign-in and returns a securely persisted member session.
  Future<TheFaithAuthSession> signIn() async {
    if (_signInInProgress) {
      throw const TheFaithAuthException(
        TheFaithAuthErrorCode.signInInProgress,
        'A hosted sign-in session is already in progress.',
      );
    }

    _signInInProgress = true;
    try {
      final redirect = await callbackUri;
      final pkce = createPkceRequest();
      final start = await _api.start(
        redirectUri: redirect,
        state: pkce.state,
        codeChallenge: pkce.challenge,
      );
      final callback = await _browser.authenticate(
        authorizationUrl: start.authorizationUrl,
        callbackUri: redirect,
      );

      if (!_matchesCallback(callback, redirect)) {
        throw const TheFaithAuthException(
          TheFaithAuthErrorCode.callbackMismatch,
          'Hosted sign-in returned to an unexpected callback URI.',
        );
      }
      if (!_constantTimeEquals(
        callback.queryParameters['state'] ?? '',
        pkce.state,
      )) {
        throw const TheFaithAuthException(
          TheFaithAuthErrorCode.stateMismatch,
          'Hosted sign-in returned an invalid state value.',
        );
      }

      final callbackError = callback.queryParameters['error'];
      if (callbackError != null && callbackError.isNotEmpty) {
        throw TheFaithAuthException(
          TheFaithAuthErrorCode.server,
          callback.queryParameters['error_description'] ??
              'Hosted sign-in was not completed.',
        );
      }

      final code = callback.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const TheFaithAuthException(
          TheFaithAuthErrorCode.missingAuthorizationCode,
          'Hosted sign-in did not return an authorization code.',
        );
      }

      final session = await _api.exchange(
        code: code,
        redirectUri: redirect,
        codeVerifier: pkce.verifier,
      );
      try {
        await _sessionStore.write(session);
      } on TheFaithAuthException {
        try {
          await _api.logout(session);
        } on Object {
          // The storage error remains the actionable failure.
        }
        rethrow;
      }
      return session;
    } finally {
      _signInInProgress = false;
    }
  }

  /// Returns the securely saved session, if the member is signed in.
  Future<TheFaithAuthSession?> currentSession() => _sessionStore.read();

  /// Returns the current bearer token, if available.
  Future<String?> accessToken() async {
    final session = await _sessionStore.read();
    return session == null || session.isExpired ? null : session.accessToken;
  }

  /// Builds a same-origin HTTP client that injects both authentication headers.
  TheFaithAuthorizedClient authorizedClient({http.Client? innerClient}) =>
      TheFaithAuthorizedClient(
        apiKey: apiKey,
        apiBaseUrl: apiBaseUrl,
        sessionStore: _sessionStore,
        innerClient: innerClient,
      );

  /// Resolves a relative v1 path against the configured API base URL.
  Uri apiUri(String path, {Map<String, String>? queryParameters}) {
    if (Uri.tryParse(path)?.hasScheme ?? false) {
      throw const TheFaithAuthException(
        TheFaithAuthErrorCode.configuration,
        'apiUri expects a relative API path.',
      );
    }
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = apiBaseUrl.resolve(normalized);
    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }

  /// Revokes the current bearer token and clears its local secure copy.
  Future<void> signOut() async {
    final session = await _sessionStore.read();
    TheFaithAuthException? remoteError;

    if (session != null) {
      try {
        await _api.logout(session);
      } on TheFaithAuthException catch (error) {
        remoteError = error;
      }
    }

    await _sessionStore.clear();
    if (remoteError != null) {
      throw remoteError;
    }
  }

  /// Clears the local session without attempting server-side revocation.
  Future<void> clearSession() => _sessionStore.clear();

  /// Releases the SDK's internal HTTP client.
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  static String _validateApiKey(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const TheFaithAuthException(
        TheFaithAuthErrorCode.configuration,
        'A TheFaithApp client API key is required.',
      );
    }
    return normalized;
  }

  static Uri _validateBaseUrl(
    Uri value, {
    required bool allowInsecureHttpForTesting,
  }) {
    if (!value.hasScheme || value.host.isEmpty) {
      throw const TheFaithAuthException(
        TheFaithAuthErrorCode.configuration,
        'apiBaseUrl must be an absolute URL.',
      );
    }
    if (value.scheme != 'https' &&
        !(value.scheme == 'http' && allowInsecureHttpForTesting)) {
      throw const TheFaithAuthException(
        TheFaithAuthErrorCode.configuration,
        'apiBaseUrl must use HTTPS. Set allowInsecureHttpForTesting only for local development.',
      );
    }
    return value.replace(
      path: value.path.endsWith('/') ? value.path : '${value.path}/',
    );
  }

  bool _matchesCallback(Uri actual, Uri expected) {
    if (actual.scheme.toLowerCase() != expected.scheme.toLowerCase() ||
        actual.host.toLowerCase() != expected.host.toLowerCase() ||
        actual.port != expected.port ||
        actual.path != expected.path) {
      return false;
    }
    for (final entry in expected.queryParameters.entries) {
      if (actual.queryParameters[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  bool _constantTimeEquals(String first, String second) {
    final firstBytes = utf8.encode(first);
    final secondBytes = utf8.encode(second);
    var difference = firstBytes.length ^ secondBytes.length;
    final length = firstBytes.length > secondBytes.length
        ? firstBytes.length
        : secondBytes.length;

    for (var index = 0; index < length; index++) {
      final left = index < firstBytes.length ? firstBytes[index] : 0;
      final right = index < secondBytes.length ? secondBytes[index] : 0;
      difference |= left ^ right;
    }
    return difference == 0;
  }
}
