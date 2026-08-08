import '../../../core/database/app_database.dart';
import '../data/models/app_user.dart';
import 'password_hasher.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();
  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;

  Future<bool> signIn(
      {required String accountName, required String password}) async {
    await AppDatabase.instance.database;
    final user = await AppDatabase.instance.userRepository!
        .getByAccountName(accountName);
    if (user == null ||
        !user.isActive ||
        user.passwordHash != PasswordHasher.hash(password)) {
      return false;
    }
    _currentUser = user;
    return true;
  }

  Future<void> signOut() async => _currentUser = null;

  Future<UserCreationResult> createUser({
    required String name,
    required String accountName,
    required String password,
    required UserRole role,
  }) async {
    final currentUser = _currentUser;
    if (currentUser == null || !currentUser.isOwner) {
      return UserCreationResult.notAuthorized;
    }
    await AppDatabase.instance.database;
    final userRepository = AppDatabase.instance.userRepository!;
    if (await userRepository.getByAccountName(accountName) != null) {
      return UserCreationResult.accountNameAlreadyInUse;
    }
    await userRepository.create(
      AppUser(
        name: name.trim(),
        accountName: accountName.trim().toLowerCase(),
        passwordHash: PasswordHasher.hash(password),
        role: role,
      ),
    );
    return UserCreationResult.success;
  }

  Future<List<AppUser>> getUsers() async {
    final currentUser = _currentUser;
    if (currentUser == null || !currentUser.isOwner) return const [];
    await AppDatabase.instance.database;
    return AppDatabase.instance.userRepository!.getAll();
  }

  Future<UserManagementResult> setUserActiveStatus(
      {required int userId, required bool isActive}) async {
    final currentUser = _currentUser;
    if (currentUser == null || !currentUser.isOwner) {
      return UserManagementResult.notAuthorized;
    }
    if (currentUser.id == userId && !isActive) {
      return UserManagementResult.cannotDeactivateSelf;
    }
    await AppDatabase.instance.database;
    await AppDatabase.instance.userRepository!
        .updateActiveStatus(userId: userId, isActive: isActive);
    return UserManagementResult.success;
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
      accountName: currentUser.accountName,
      passwordHash: passwordHash,
      role: currentUser.role,
      isActive: currentUser.isActive,
      createdAt: currentUser.createdAt,
    );
    return ChangePasswordResult.success;
  }
}

enum UserCreationResult { success, notAuthorized, accountNameAlreadyInUse }

enum ChangePasswordResult {
  success,
  notAuthenticated,
  incorrectCurrentPassword
}

enum UserManagementResult { success, notAuthorized, cannotDeactivateSelf }
