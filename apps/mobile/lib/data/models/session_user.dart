import '../json_read.dart';

enum UserRole { admin, hub }

UserRole parseRole(String value) {
  switch (value) {
    case 'admin':
      return UserRole.admin;
    case 'hub':
      return UserRole.hub;
    default:
      throw FormatException('Unknown role $value');
  }
}

class SessionUser {
  const SessionUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.roleLabel,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String roleLabel;

  bool get isHub => role == UserRole.hub;
  bool get isAdmin => role == UserRole.admin;

  factory SessionUser.fromJson(Map<String, Object?> json) {
    final role = parseRole(requiredString(json, 'role'));
    return SessionUser(
      id: requiredString(json, 'id'),
      name: requiredString(json, 'name'),
      email: requiredString(json, 'email'),
      role: role,
      roleLabel: requiredString(json, 'roleLabel'),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'roleLabel': roleLabel,
      };
}
