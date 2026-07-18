import 'package:package_info_plus/package_info_plus.dart';

import 'exceptions.dart';

/// Resolves the callback URI that returns hosted sign-in to the app.
abstract interface class TheFaithCallbackUriProvider {
  Future<Uri> resolve();
}

/// Derives a callback from the Android application ID or iOS bundle ID.
final class TheFaithPackageCallbackUriProvider
    implements TheFaithCallbackUriProvider {
  const TheFaithPackageCallbackUriProvider();

  @override
  Future<Uri> resolve() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return forPackageName(packageInfo.packageName);
    } on TheFaithAuthException {
      rethrow;
    } on Object catch (error) {
      throw TheFaithAuthException(
        TheFaithAuthErrorCode.configuration,
        'The application ID could not be read for the hosted auth callback.',
        cause: error,
      );
    }
  }

  /// Returns `<package-name>.thefaithapp://auth/callback`.
  static Uri forPackageName(String packageName) {
    final normalized = packageName.trim().toLowerCase();
    final scheme = '$normalized.thefaithapp';
    final validScheme = RegExp(r'^[a-z][a-z0-9+.-]*$');

    if (!validScheme.hasMatch(scheme)) {
      throw TheFaithAuthException(
        TheFaithAuthErrorCode.configuration,
        'The application ID cannot be converted into a callback URI. '
        'Use an application ID containing only letters, numbers, dots, or hyphens.',
      );
    }

    return Uri(scheme: scheme, host: 'auth', path: '/callback');
  }
}
