import '../../../core/database/app_database.dart';
import '../data/models/app_user.dart';
import 'password_hasher.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();
  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;

  Future<bool> signIn({required String email, required String password}) async {
    await AppDatabase.instance.database;
    final user = await AppDatabase.instance.userRepository!.getByEmail(email);
    if (user == null || user.passwordHash != PasswordHasher.hash(password)) return false;
    _currentUser = user;
    return true;
  }

  Future<void> signOut() async => _currentUser = null;

  Future<UserCreationResult> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final currentUser = _currentUser;
    if (currentUser == null || !currentUser.isOwner) {
      return UserCreationResult.notAuthorized;
    }
    await AppDatabase.instance.database;
    final userRepository = AppDatabase.instance.userRepository!;
    if (await userRepository.getByEmail(email) != null) {
      return UserCreationResult.emailAlreadyInUse;
    }
    await userRepository.create(AppUser(
      name: name.trim(),
      email: email.trim().toLowerCase(),
      passwordHash: PasswordHasher.hash(password),
      role: role,
    ));
    return UserCreationResult.success;
  }

  /// Updates only the password of the authenticated user.
  Future<ChangePasswordResult> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentUser = _currentUser;
    if (currentUser?.id == null) return ChangePasswordResult.notAuthenticated;
    if (currentUser!.passwordHash != PasswordHasher.hash(currentPassword)) {
      return ChangePasswordResult.incorrectCurrentPassword;
    }
    await AppDatabase.instance.database;
    final passwordHash = PasswordHasher.hash(newPassword);
    await AppDatabase.instance.userRepository!.updatePassword(
      userId: currentUser.id!,
      passwordHash: passwordHash,
    );
    _currentUser = AppUser(
      id: currentUser.id,
      name: currentUser.name,
      email: currentUser.email,
      passwordHash: passwordHash,
      role: currentUser.role,
      createdAt: currentUser.createdAt,
    );
    return ChangePasswordResult.success;
  }
}

enum UserCreationResult { success, notAuthorized, emailAlreadyInUse }
enum ChangePasswordResult { success, notAuthenticated, incorrectCurrentPassword }
