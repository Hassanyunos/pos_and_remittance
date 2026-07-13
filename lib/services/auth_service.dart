import 'package:flutter/foundation.dart';
import '../database/database_manager.dart';
import '../models/user.dart';

class AuthService {
  final DatabaseManager _db = DatabaseManager();
  User? _currentUser;

  User? get currentUser => _currentUser;

  // ⚠️ For testing only - use bcrypt in production!
  String _hashPassword(String password) => password;
  bool _verifyPassword(String password, String hash) => password == hash;

  // ============ Register User ============
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('📝 Register attempt: $email');

      // Ensure database is initialized
      await _db.database;

      // Check if user already exists
      final existingUser = await _db.users.getByEmail(email);
      if (existingUser != null) {
        debugPrint('❌ Registration failed: Email already exists');
        return false;
      }

      // Create new user
      final user = User(
        name: name.trim(),
        email: email.toLowerCase().trim(),
        passwordHash: _hashPassword(password),
      );

      // Save user using repository
      final savedUser = await _db.users.create(user);
      
      if (savedUser.id != null && savedUser.id! > 0) {
        debugPrint('✅ User registered successfully with ID: ${savedUser.id}');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      return false;
    }
  }

  // ============ Login User ============
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('📝 Login attempt: $email');

      // Ensure database is initialized
      await _db.database;

      // Find user by email using repository
      final user = await _db.users.getByEmail(email);

      if (user == null) {
        debugPrint('❌ Login failed: User not found');
        return false;
      }

      debugPrint('👤 Found user: ${user.name}');

      if (!_verifyPassword(password, user.passwordHash)) {
        debugPrint('❌ Login failed: Invalid password');
        return false;
      }

      _currentUser = user;
      debugPrint('✅ Login successful for user: ${user.email}');
      return true;
    } catch (e) {
      debugPrint('❌ Login error: $e');
      return false;
    }
  }

  // ============ Logout ============
  Future<void> logout() async {
    _currentUser = null;
    debugPrint('👋 User logged out');
  }

  // ============ Get All Users (Debug) ============
  Future<List<User>> getAllUsers() async {
    try {
      await _db.database;
      return await _db.users.getAll();
    } catch (e) {
      debugPrint('❌ Error getting users: $e');
      return [];
    }
  }

  // ============ Get User by ID ============
  Future<User?> getUserById(int id) async {
    try {
      await _db.database;
      return await _db.users.getById(id);
    } catch (e) {
      debugPrint('❌ Error getting user: $e');
      return null;
    }
  }

  // ============ Update User ============
  Future<bool> updateUser(User user) async {
    try {
      await _db.database;
      final updatedUser = await _db.users.update(user);
      
      if (updatedUser != null) {
        _currentUser = updatedUser;
        debugPrint('✅ User updated successfully');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error updating user: $e');
      return false;
    }
  }

  // ============ Delete User ============
  Future<bool> deleteUser(int id) async {
    try {
      await _db.database;
      return await _db.users.delete(id);
    } catch (e) {
      debugPrint('❌ Error deleting user: $e');
      return false;
    }
  }

  // ============ Check if Logged In ============
  bool isLoggedIn() => _currentUser != null;
}