enum UserRole { owner, staff }

class AppUser {
  const AppUser({
    this.id,
    required this.name,
    required this.accountName,
    required this.passwordHash,
    required this.role,
    this.isActive = true,
    this.createdAt,
  });

  final int? id;
  final String name;
  final String accountName;
  final String passwordHash;
  final UserRole role;
  final bool isActive;
  final DateTime? createdAt;

  bool get isOwner => role == UserRole.owner;

  factory AppUser.fromMap(Map<String, Object?> map) => AppUser(
        id: map['id'] as int?,
        name: map['name'] as String,
        accountName:
            (map['account_name'] as String?) ?? (map['email'] as String),
        passwordHash: map['password_hash'] as String,
        role: (map['role'] as String?) == UserRole.owner.name
            ? UserRole.owner
            : UserRole.staff,
        isActive: (map['is_active'] as int?) != 0,
        createdAt: map['created_at'] == null
            ? null
            : DateTime.tryParse(map['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'account_name': accountName,
        // Keep legacy column populated for compatibility with older schemas.
        'email': accountName,
        'password_hash': passwordHash,
        'role': role.name,
        'is_active': isActive ? 1 : 0,
      };

  AppUser copyWith({int? id}) => AppUser(
        id: id ?? this.id,
        name: name,
        accountName: accountName,
        passwordHash: passwordHash,
        role: role,
        isActive: isActive,
        createdAt: createdAt,
      );
}
