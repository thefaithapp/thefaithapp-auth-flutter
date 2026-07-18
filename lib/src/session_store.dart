import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'exceptions.dart';
import 'models.dart';

/// Persistence boundary for hosted-auth sessions.
abstract interface class TheFaithAuthSessionStore {
  Future<TheFaithAuthSession?> read();

  Future<void> write(TheFaithAuthSession session);

  Future<void> clear();
}

/// Stores member bearer tokens with the platform Keychain or Keystore.
final class TheFaithSecureSessionStore implements TheFaithAuthSessionStore {
  TheFaithSecureSessionStore({
    required String apiKey,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _storageKey = _keyFor(apiKey);

  final FlutterSecureStorage _storage;
  final String _storageKey;

  @override
  Future<TheFaithAuthSession?> read() async {
    try {
      final value = await _storage.read(key: _storageKey);
      if (value == null || value.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        throw const FormatException('Stored session is not an object.');
      }
      return TheFaithAuthSession.fromJson(Map<String, dynamic>.from(decoded));
    } on TheFaithAuthException {
      rethrow;
    } catch (error) {
      throw TheFaithAuthException(
        TheFaithAuthErrorCode.sessionStorage,
        'The saved member session could not be read.',
        cause: error,
      );
    }
  }

  @override
  Future<void> write(TheFaithAuthSession session) async {
    try {
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(session.toJson()),
      );
    } catch (error) {
      throw TheFaithAuthException(
        TheFaithAuthErrorCode.sessionStorage,
        'The member session could not be stored securely.',
        cause: error,
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _storageKey);
    } catch (error) {
      throw TheFaithAuthException(
        TheFaithAuthErrorCode.sessionStorage,
        'The saved member session could not be removed.',
        cause: error,
      );
    }
  }

  static String _keyFor(String apiKey) {
    final digest = sha256.convert(utf8.encode(apiKey)).toString();
    return 'thefaithapp_auth.session.${digest.substring(0, 24)}';
  }
}
