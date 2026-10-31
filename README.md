# TheFaithApp Auth for Flutter

`thefaithapp_auth` opens TheFaithApp-hosted member sign-in and returns a member
bearer token for the `v1` API. It handles state validation, S256 PKCE, callback
capture, code exchange, secure session storage, API headers, and logout.

Use the client API key from `Settings > Developer Access` to initialize the
package. The member session is stored securely on the device.

## Documentation

- [Flutter SDK quickstart](https://docs.thefaithapp.com/api-reference/flutter-sdk)
- [Hosted authentication guide](https://docs.thefaithapp.com/api-reference/hosted-auth)
- [Standalone example app](https://github.com/thefaithapp/thefaithapp-auth-flutter/tree/main/example)

## Install

```yaml
dependencies:
  thefaithapp_auth: ^0.1.0
```

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

See the [`example`](example) app for a complete integration.

## Develop from a source checkout

The repository's example uses a path dependency on the local package source.
For that source build, API and hosted-auth origins can be selected at build time.
Production URLs remain the default; HTTP is accepted only for loopback hosts.
These overrides are unreleased and are not part of the published `0.1.0` package.

```bash
git clone https://github.com/thefaithapp/thefaithapp-auth-flutter.git
cd thefaithapp-auth-flutter/example
flutter pub get
flutter run \
  --dart-define=TFA_CLIENT_KEY=replace-with-local-client-key \
  --dart-define=TFA_API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=TFA_HOSTED_AUTH_BASE_URL=http://localhost:3001
```

Run the local API and hosted-auth services separately and register the example's
callback there. Use development credentials for this build. A phone or emulator
has its own loopback interface; these addresses work only when those services
are reachable on that device's loopback interface.

## License

TheFaithApp Auth is available under the [MIT License](LICENSE).
