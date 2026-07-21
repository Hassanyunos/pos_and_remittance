enum UserRole { owner, staff }

class AppUser {
  const AppUser({
    this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.role,
    this.createdAt,
  });

  final int? id;
  final String name;
  final String email;
  final String passwordHash;
  final UserRole role;
  final DateTime? createdAt;

  bool get isOwner => role == UserRole.owner;

  factory AppUser.fromMap(Map<String, Object?> map) => AppUser(
        id: map['id'] as int?,
        name: map['name'] as String,
        email: map['email'] as String,
        passwordHash: map['password_hash'] as String,
        role: (map['role'] as String?) == UserRole.owner.name
            ? UserRole.owner
            : UserRole.staff,
        createdAt: map['created_at'] == null
            ? null
            : DateTime.tryParse(map['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'password_hash': passwordHash,
        'role': role.name,
      };

  AppUser copyWith({int? id}) => AppUser(
        id: id ?? this.id,
        name: name,
        email: email,
        passwordHash: passwordHash,
        role: role,
        createdAt: createdAt,
      );
}
