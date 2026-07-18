import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

final class PkceRequest {
  const PkceRequest({
    required this.state,
    required this.verifier,
    required this.challenge,
  });

  final String state;
  final String verifier;
  final String challenge;
}

PkceRequest createPkceRequest() {
  final random = Random.secure();
  final state = _randomBase64Url(random, 32);
  final verifier = _randomBase64Url(random, 64);
  final challenge = base64Url
      .encode(sha256.convert(utf8.encode(verifier)).bytes)
      .replaceAll('=', '');

  return PkceRequest(state: state, verifier: verifier, challenge: challenge);
}

String _randomBase64Url(Random random, int length) {
  final bytes = List<int>.generate(length, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
