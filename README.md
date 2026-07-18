# TheFaithApp Auth for Flutter

`thefaithapp_auth` opens TheFaithApp-hosted member sign-in and returns a member
bearer token for the `v1` API. It handles state validation, S256 PKCE, callback
capture, code exchange, secure session storage, API headers, and logout.

Use the client API key from `Settings > Developer Access` to initialize the
package. The member session is stored securely on the device.

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

## License

TheFaithApp Auth is available under the [MIT License](LICENSE).
