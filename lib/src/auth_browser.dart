import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'exceptions.dart';

/// Opens hosted sign-in and returns the callback received by the app.
abstract interface class TheFaithAuthBrowser {
  Future<Uri> authenticate({
    required Uri authorizationUrl,
    required Uri callbackUri,
  });
}

/// Uses the platform's secure browser authentication session.
final class TheFaithSystemAuthBrowser implements TheFaithAuthBrowser {
  const TheFaithSystemAuthBrowser();

  @override
  Future<Uri> authenticate({
    required Uri authorizationUrl,
    required Uri callbackUri,
  }) async {
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authorizationUrl.toString(),
        callbackUrlScheme: callbackUri.scheme,
        options: callbackUri.scheme == 'https'
            ? FlutterWebAuth2Options(
                httpsHost: callbackUri.host,
                httpsPath: callbackUri.path,
              )
            : const FlutterWebAuth2Options(),
      );
      return Uri.parse(result);
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      if (code.contains('cancel')) {
        throw TheFaithAuthException(
          TheFaithAuthErrorCode.cancelled,
          'Member sign-in was cancelled.',
          cause: error,
        );
      }
      throw TheFaithAuthException(
        TheFaithAuthErrorCode.network,
        'The hosted sign-in session could not be completed.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw TheFaithAuthException(
        TheFaithAuthErrorCode.invalidResponse,
        'Hosted sign-in returned an invalid callback.',
        cause: error,
      );
    }
  }
}
