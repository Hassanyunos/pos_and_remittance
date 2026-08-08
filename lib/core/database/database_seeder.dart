import '../../features/auth/data/models/app_user.dart';
import '../../features/auth/data/repositories/user_repository.dart';
import '../../features/auth/application/password_hasher.dart';
import '../../features/fund_management/data/repositories/fund_repository.dart';

class DatabaseSeeder {
  DatabaseSeeder(this._userRepository, this._fundRepository);
  static const ownerAccountName = 'admin';
  static const ownerPassword = 'admin123';
  final UserRepository _userRepository;
  final FundRepository _fundRepository;

  Future<void> seedAll() async {
    await seedOwnerUser();
    await seedDefaultFunds();
  }

  Future<void> seedOwnerUser() async {
    if (await _userRepository.getByAccountName(ownerAccountName) != null) {
      return;
    }
    await _userRepository.create(
      AppUser(
        name: 'System Owner',
        accountName: ownerAccountName,
        passwordHash: PasswordHasher.hash(ownerPassword),
        role: UserRole.owner,
      ),
    );
  }

  Future<void> seedDefaultFunds() async {
    await _fundRepository.seedDefaultFunds();
  }
}
