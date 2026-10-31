import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thefaithapp_auth/src/auth_browser.dart';
import 'package:thefaithapp_auth/src/auth_client.dart';
import 'package:thefaithapp_auth/src/authorized_client.dart';
import 'package:thefaithapp_auth/src/callback_uri_provider.dart';
import 'package:thefaithapp_auth/src/environment.dart';
import 'package:thefaithapp_auth/src/session_store.dart';
import 'package:thefaithapp_auth/thefaithapp_auth.dart';

void main() {
  const apiKey = 'client-key';
  final expectedApiOrigin = Uri.parse(
    const String.fromEnvironment(
      'TEST_EXPECTED_API_ORIGIN',
      defaultValue: 'https://api.thefaithapp.com',
    ),
  );
  final expectedAuthOrigin = Uri.parse(
    const String.fromEnvironment(
      'TEST_EXPECTED_AUTH_ORIGIN',
      defaultValue: 'https://auth.thefaithapp.com',
    ),
  );
  final callbackUri = Uri.parse(
    'com.example.church.thefaithapp://auth/callback',
  );

  group('environment origins', () {
    test('allows HTTPS origins and loopback HTTP for local development', () {
      expect(
        parseTheFaithAppEnvironmentUri(
          'https://api.example.test',
          name: 'origin',
        ),
        Uri.parse('https://api.example.test'),
      );
      expect(
        parseTheFaithAppEnvironmentUri('http://127.0.0.1:8000', name: 'origin'),
        Uri.parse('http://127.0.0.1:8000'),
      );
      expect(
        parseTheFaithAppEnvironmentUri(
          'http://localhost:3001/',
          name: 'origin',
        ),
        Uri.parse('http://localhost:3001'),
      );
      expect(
        parseTheFaithAppEnvironmentUri('http://[::1]:8000', name: 'origin'),
        Uri.parse('http://[::1]:8000'),
      );
      expect(
        parseTheFaithAppEnvironmentUri(
          ' HTTPS://API.EXAMPLE.TEST:8443/ ',
          name: 'origin',
        ),
        Uri.parse('https://api.example.test:8443'),
      );
    });

    test('rejects unsafe or non-origin configuration', () {
      for (final value in <String>[
        'http://api.example.test',
        'https://user:password@api.example.test',
        'https://api.example.test/v1',
        'https://api.example.test?tenant=1',
        'https://api.example.test#fragment',
        'http://localhost.example.test',
        'http://127.0.0.1.example.test',
        'ftp://localhost',
        '/relative',
        '',
      ]) {
        expect(
          () => parseTheFaithAppEnvironmentUri(value, name: 'origin'),
          throwsArgumentError,
          reason: value,
        );
      }
    });
  });

  test('derives a mobile callback URI from the application ID', () {
    expect(
      TheFaithPackageCallbackUriProvider.forPackageName('com.example.church'),
      callbackUri,
    );
  });

  test('rejects application IDs that cannot be URL schemes', () {
    expect(
      () => TheFaithPackageCallbackUriProvider.forPackageName(
        'com.example.church_app',
      ),
      throwsA(
        isA<TheFaithAuthException>().having(
          (error) => error.code,
          'code',
          TheFaithAuthErrorCode.configuration,
        ),
      ),
    );
  });

  test('public SDK uses the expected build-time origins', () {
    final auth = TheFaithAppAuth(apiKey: apiKey);

    expect(TheFaithAppEnvironment.apiBaseUrl, expectedApiOrigin);
    expect(TheFaithAppEnvironment.hostedAuthBaseUrl, expectedAuthOrigin);
    expect(auth.apiUri('/v1/user'), expectedApiOrigin.resolve('/v1/user'));

    auth.dispose();
  });

  test('public SDK requires a client API key', () {
    expect(
      () => TheFaithAppAuth(apiKey: '  '),
      throwsA(
        isA<TheFaithAuthException>().having(
          (error) => error.code,
          'code',
          TheFaithAuthErrorCode.configuration,
        ),
      ),
    );
  });

  test(
    'signIn uses S256 PKCE, validates state, and stores the session',
    () async {
      final store = MemorySessionStore();
      Map<String, dynamic>? startBody;
      Map<String, dynamic>? tokenBody;
      final httpClient = MockClient((request) async {
        expect(request.url.origin, expectedApiOrigin.origin);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path == '/v1/auth/start') {
          startBody = body;
          return http.Response(
            jsonEncode(<String, Object?>{
              'auth_url': expectedAuthOrigin
                  .resolve('/member/sign-in')
                  .toString(),
            }),
            200,
          );
        }
        if (request.url.path == '/v1/auth/token') {
          tokenBody = body;
          return http.Response(jsonEncode(sessionPayload), 200);
        }
        fail('Unexpected request: ${request.url}');
      });
      final browser = CallbackBrowser(() {
        final state = startBody!['state'] as String;
        return callbackUri.replace(
          queryParameters: <String, String>{
            'code': 'one-time-code',
            'state': state,
          },
        );
      });
      final auth = TheFaithAppAuthClient(
        apiKey: apiKey,
        redirectUri: callbackUri,
        browser: browser,
        sessionStore: store,
        httpClient: httpClient,
      );

      final session = await auth.signIn();

      expect(session.accessToken, 'member-token');
      expect(session.member.email, 'jane@example.com');
      expect(store.session, same(session));
      expect(startBody!['code_challenge_method'], 'S256');
      expect(startBody!['redirect_uri'], callbackUri.toString());
      expect(tokenBody!['code'], 'one-time-code');
      expect(tokenBody!['redirect_uri'], callbackUri.toString());

      final verifier = tokenBody!['code_verifier'] as String;
      final expectedChallenge = base64Url
          .encode(sha256.convert(utf8.encode(verifier)).bytes)
          .replaceAll('=', '');
      expect(startBody!['code_challenge'], expectedChallenge);
    },
  );

  test('signIn rejects a callback with the wrong state', () async {
    var tokenExchangeCalled = false;
    final httpClient = MockClient((request) async {
      if (request.url.path == '/v1/auth/start') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'auth_url': expectedAuthOrigin
                .resolve('/member/sign-in')
                .toString(),
          }),
          200,
        );
      }
      tokenExchangeCalled = true;
      return http.Response(jsonEncode(sessionPayload), 200);
    });
    final auth = TheFaithAppAuthClient(
      apiKey: apiKey,
      redirectUri: callbackUri,
      browser: CallbackBrowser(
        () => callbackUri.replace(
          queryParameters: const <String, String>{
            'code': 'one-time-code',
            'state': 'forged-state',
          },
        ),
      ),
      sessionStore: MemorySessionStore(),
      httpClient: httpClient,
    );

    await expectLater(
      auth.signIn(),
      throwsA(
        isA<TheFaithAuthException>().having(
          (error) => error.code,
          'code',
          TheFaithAuthErrorCode.stateMismatch,
        ),
      ),
    );
    expect(tokenExchangeCalled, isFalse);
  });

  test('authorizedClient injects both auth headers', () async {
    final store = MemorySessionStore()..session = testSession;
    final inner = MockClient((request) async {
      expect(request.headers['X-API-Key'], apiKey);
      expect(request.headers['Authorization'], 'Bearer member-token');
      expect(request.headers['Accept'], 'application/json');
      return http.Response('{"ok":true}', 200);
    });
    final client = TheFaithAuthorizedClient(
      apiKey: apiKey,
      sessionStore: store,
      innerClient: inner,
    );

    final response = await client.get(expectedApiOrigin.resolve('/v1/user'));

    expect(response.statusCode, 200);
    client.close();
  });

  test(
    'authorizedClient rejects other origins before adding credentials',
    () async {
      var sentRequests = 0;
      final client = TheFaithAuthorizedClient(
        apiKey: apiKey,
        sessionStore: MemorySessionStore()..session = testSession,
        innerClient: MockClient((_) async {
          sentRequests++;
          return http.Response('', 200);
        }),
      );

      for (final otherOrigin in <Uri>[
        Uri.parse('https://example.com'),
        expectedApiOrigin.replace(port: expectedApiOrigin.port + 1),
        expectedApiOrigin.replace(
          scheme: expectedApiOrigin.scheme == 'https' ? 'http' : 'https',
        ),
      ]) {
        final request = http.Request('GET', otherOrigin.resolve('/v1/user'));
        await expectLater(
          client.send(request),
          throwsA(
            isA<TheFaithAuthException>().having(
              (error) => error.code,
              'code',
              TheFaithAuthErrorCode.unauthorizedHost,
            ),
          ),
        );
        expect(request.headers, isNot(contains('X-API-Key')));
        expect(request.headers, isNot(contains('Authorization')));
      }
      expect(sentRequests, 0);
      client.close();
    },
  );

  test('signOut revokes the token and clears local storage', () async {
    final store = MemorySessionStore()..session = testSession;
    final auth = TheFaithAppAuthClient(
      apiKey: apiKey,
      redirectUri: callbackUri,
      sessionStore: store,
      httpClient: MockClient((request) async {
        expect(request.url.origin, expectedApiOrigin.origin);
        expect(request.url.path, '/v1/auth/logout');
        expect(request.headers['x-api-key'], apiKey);
        expect(request.headers['authorization'], 'Bearer member-token');
        return http.Response('{"message":"Logged out successfully."}', 200);
      }),
    );

    await auth.signOut();

    expect(store.session, isNull);
  });

  test('signIn rejects hosted auth URLs outside the selected origin', () async {
    for (final otherOrigin in <Uri>[
      Uri.parse('https://attacker.example'),
      expectedAuthOrigin.replace(port: expectedAuthOrigin.port + 1),
      expectedAuthOrigin.replace(
        scheme: expectedAuthOrigin.scheme == 'https' ? 'http' : 'https',
      ),
    ]) {
      final auth = TheFaithAppAuthClient(
        apiKey: apiKey,
        redirectUri: callbackUri,
        browser: CallbackBrowser(() => fail('Browser must not be opened.')),
        sessionStore: MemorySessionStore(),
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object?>{
              'auth_url': otherOrigin.resolve('/member/sign-in').toString(),
            }),
            200,
          ),
        ),
      );

      await expectLater(
        auth.signIn(),
        throwsA(
          isA<TheFaithAuthException>().having(
            (error) => error.code,
            'code',
            TheFaithAuthErrorCode.invalidResponse,
          ),
        ),
      );
      auth.dispose();
    }
  });
}

final sessionPayload = <String, Object?>{
  'access_token': 'member-token',
  'token_type': 'Bearer',
  'member': <String, Object?>{
    'id': 123,
    'name': 'Jane Member',
    'email': 'jane@example.com',
    'client_id': 45,
    'uuid': 'member-uuid',
  },
};

final testSession = TheFaithAuthSession.fromJson(sessionPayload);

final class CallbackBrowser implements TheFaithAuthBrowser {
  const CallbackBrowser(this.callback);

  final Uri Function() callback;

  @override
  Future<Uri> authenticate({
    required Uri authorizationUrl,
    required Uri callbackUri,
  }) async => callback();
}

final class MemorySessionStore implements TheFaithAuthSessionStore {
  TheFaithAuthSession? session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<TheFaithAuthSession?> read() async => session;

  @override
  Future<void> write(TheFaithAuthSession value) async => session = value;
}
