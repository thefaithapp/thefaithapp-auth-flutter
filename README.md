# TheFaithApp Auth for Flutter

`thefaithapp_auth` opens TheFaithApp-hosted member sign-in and returns a member
bearer token for the `v1` API. It handles state validation, S256 PKCE, callback
capture, code exchange, secure session storage, API headers, and logout.

The client API key identifies the church app; it is not treated as a secret in
a compiled mobile application. The member bearer token remains confidential.
The API key is the package's only runtime configuration. Network requests are
locked to `https://api.thefaithapp.com`, and hosted sign-in is accepted only
from `https://auth.thefaithapp.com`.

The package is currently an unpublished `0.1.0` development release. Publishing
remains disabled until the verified pub.dev publisher is selected and the final
release review is complete.

## Install during development

Until the first pub.dev release, use the public Git repository:

```yaml
dependencies:
  thefaithapp_auth:
    git:
      url: https://github.com/thefaithapp/thefaithapp-auth-flutter.git
      ref: main
```

Pin `ref` to a release tag instead of `main` when tagged releases are
available.

## Configure the callback

The default callback is derived from the consuming app's application ID:

```text
<application-id>.thefaithapp://auth/callback
```

For `com.example.church`, open `Settings > Developer Access`, select
**Add Flutter app**, and enter:

```text
com.example.church.thefaithapp
```

The dashboard saves this Redirect URL automatically:

```text
com.example.church.thefaithapp://auth/callback
```

Android callback registration is contributed automatically by the plugin.
Application IDs containing underscores cannot be used as URL schemes; prefer a
standard reverse-domain ID containing letters, numbers, dots, or hyphens.

On iOS, enable **Keychain Sharing** for the Runner target so the default secure
session store can persist the bearer token. No callback URL type is required
for the system authentication session.

## Sign in

```dart
import 'package:thefaithapp_auth/thefaithapp_auth.dart';

final auth = TheFaithAppAuth(apiKey: 'your-client-key');
final callback = await auth.callbackUri;
final session = await auth.signIn();

print(session.member.name);
// Use session.accessToken when direct access to the bearer token is required.
```

Do not log or include `session.accessToken` in crash reports.

## Call the v1 API

The authorized client only sends credentials to the configured TheFaithApp API
origin.

```dart
final client = auth.authorizedClient();
try {
  final response = await client.get(auth.apiUri('/v1/user'));
  print(response.statusCode);
} finally {
  client.close();
}
```

## Restore and sign out

```dart
final savedSession = await auth.currentSession();
await auth.signOut(); // Revokes the server token and removes the secure copy.
auth.dispose();
```

## Security model

- The client API key is a public app identifier. Like any value compiled into
  a mobile app, it can be extracted and must not be treated as a secret.
- A client key alone cannot call protected `v1` endpoints. Those requests also
  require a signed-in member's bearer token for the same church.
- Every sign-in uses random state and S256 PKCE. Authorization codes are
  short-lived, single-use, and bound to the registered callback.
- The package stores bearer tokens in Keychain or Keystore and refuses to send
  them to any host other than the production TheFaithApp API.
- Rotate a client key from Developer Access if it is being abused, then update
  the connected app.

See the standalone consumer app in `examples/thefaithapp_auth_example` for a
complete integration.

## License

TheFaithApp Auth is available under the [MIT License](LICENSE).
