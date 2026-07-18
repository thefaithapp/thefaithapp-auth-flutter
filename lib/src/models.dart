/// The member associated with a hosted-auth session.
final class TheFaithMember {
  const TheFaithMember({
    required this.id,
    required this.name,
    required this.clientId,
    required this.uuid,
    this.email,
  });

  factory TheFaithMember.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final clientId = json['client_id'];

    if (id is! num || clientId is! num) {
      throw const FormatException('Member identifiers are missing.');
    }

    return TheFaithMember(
      id: id.toInt(),
      name: _requiredString(json, 'name'),
      email: json['email'] as String?,
      clientId: clientId.toInt(),
      uuid: _requiredString(json, 'uuid'),
    );
  }

  final int id;
  final String name;
  final String? email;
  final int clientId;
  final String uuid;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'email': email,
    'client_id': clientId,
    'uuid': uuid,
  };

  @override
  String toString() => 'TheFaithMember(id: $id, name: $name)';
}

/// A member bearer token and its associated member.
final class TheFaithAuthSession {
  const TheFaithAuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.member,
    required this.receivedAt,
    this.expiresAt,
  });

  factory TheFaithAuthSession.fromJson(Map<String, dynamic> json) {
    final member = json['member'];
    if (member is! Map) {
      throw const FormatException('Session member is missing.');
    }

    return TheFaithAuthSession(
      accessToken: _requiredString(json, 'access_token'),
      tokenType: _requiredString(json, 'token_type'),
      member: TheFaithMember.fromJson(Map<String, dynamic>.from(member)),
      receivedAt: _dateTime(json['received_at']) ?? DateTime.now().toUtc(),
      expiresAt: _dateTime(json['expires_at']),
    );
  }

  final String accessToken;
  final String tokenType;
  final TheFaithMember member;
  final DateTime receivedAt;
  final DateTime? expiresAt;

  bool get isExpired => expiresAt?.isBefore(DateTime.now().toUtc()) ?? false;

  Map<String, Object?> toJson() => <String, Object?>{
    'access_token': accessToken,
    'token_type': tokenType,
    'member': member.toJson(),
    'received_at': receivedAt.toUtc().toIso8601String(),
    if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
  };

  @override
  String toString() =>
      'TheFaithAuthSession(tokenType: $tokenType, member: $member)';
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key is missing.');
  }
  return value;
}

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}
