import '../../features/auth/data/models/app_user.dart';
import '../../features/auth/data/repositories/user_repository.dart';
import '../../features/auth/application/password_hasher.dart';

class DatabaseSeeder {
  DatabaseSeeder(this._userRepository);
  static const ownerEmail = 'admin@example.com';
  static const ownerPassword = 'admin123';
  final UserRepository _userRepository;

  Future<void> seedOwnerUser() async {
    if (await _userRepository.getByEmail(ownerEmail) != null) return;
    await _userRepository.create(AppUser(
      name: 'System Owner', email: ownerEmail,
      passwordHash: PasswordHasher.hash(ownerPassword), role: UserRole.owner,
    ));
  }
}
