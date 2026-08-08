import 'package:flutter/material.dart';

import '../../../../core/ui/app_notice.dart';
import '../../../auth/application/auth_service.dart';
import '../../../auth/data/models/app_user.dart';

class ManageUserPage extends StatefulWidget {
  const ManageUserPage({super.key});

  @override
  State<ManageUserPage> createState() => _ManageUserPageState();
}

class _ManageUserPageState extends State<ManageUserPage> {
  final _nameController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _registerFormKey = GlobalKey<FormState>();
  bool _isRegistering = false;
  bool _isToggling = false;
  late Future<List<AppUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<AppUser>> _loadUsers() => AuthService.instance.getUsers();

  Future<void> _showRegisterUserDialog() async {
    _nameController.clear();
    _accountNameController.clear();
    _passwordController.clear();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add salesperson'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Form(
              key: _registerFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a name.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _accountNameController,
                    decoration:
                        const InputDecoration(labelText: 'Account name'),
                    validator: _validateAccountName,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration:
                        const InputDecoration(labelText: 'Temporary password'),
                    obscureText: true,
                    validator: (value) => value == null || value.length < 6
                        ? 'Use at least 6 characters.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Role: Salesperson',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _isRegistering
                ? null
                : () => _registerUser(dialogContext: dialogContext),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: _isRegistering
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Register'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerUser({required BuildContext dialogContext}) async {
    if (!(_registerFormKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isRegistering = true);
    final result = await AuthService.instance.createUser(
      name: _nameController.text,
      accountName: _accountNameController.text,
      password: _passwordController.text,
      role: UserRole.staff,
    );
    if (!mounted) return;
    setState(() => _isRegistering = false);
    final message = switch (result) {
      UserCreationResult.success => 'User registered successfully.',
      UserCreationResult.accountNameAlreadyInUse =>
        'That account name is already in use.',
      UserCreationResult.notAuthorized => 'Only the owner can manage users.',
    };
    if (!dialogContext.mounted) return;
    if (result == UserCreationResult.success) {
      AppNotice.success(message);
    } else {
      AppNotice.warning(message);
    }
    if (result == UserCreationResult.success) {
      Navigator.pop(dialogContext);
      setState(() {
        _usersFuture = _loadUsers();
      });
    }
  }

  Future<void> _toggleUserStatus(AppUser user, bool nextActive) async {
    if (user.id == null || _isToggling) return;
    setState(() => _isToggling = true);
    final result = await AuthService.instance
        .setUserActiveStatus(userId: user.id!, isActive: nextActive);
    if (!mounted) return;
    setState(() {
      _isToggling = false;
      _usersFuture = _loadUsers();
    });
    final message = switch (result) {
      UserManagementResult.success =>
        nextActive ? 'User activated.' : 'User deactivated.',
      UserManagementResult.notAuthorized => 'Only the owner can manage users.',
      UserManagementResult.cannotDeactivateSelf =>
        'You cannot deactivate your own account.',
    };
    if (result == UserManagementResult.success) {
      AppNotice.success(message);
    } else {
      AppNotice.warning(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage users')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRegisterUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add user'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _usersFuture = _loadUsers();
            });
          },
          child: FutureBuilder<List<AppUser>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snapshot.data ?? const <AppUser>[];
              if (users.isEmpty) {
                return const Center(child: Text('No users yet.'));
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: users.map((user) {
                  final roleLabel = _formatRole(user.role);
                  final canToggle = user.role != UserRole.owner;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : 'U',
                        ),
                      ),
                      title: Text(user.name),
                      subtitle: Text(
                          '${user.accountName} • $roleLabel • ${user.isActive ? 'Active' : 'Inactive'}'),
                      trailing: Switch(
                        value: user.isActive,
                        onChanged: !canToggle || _isToggling
                            ? null
                            : (value) => _toggleUserStatus(user, value),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  String? _validateAccountName(String? value) {
    final accountName = value?.trim() ?? '';
    if (accountName.isEmpty) {
      return 'Enter an account name.';
    }
    if (accountName.contains(' ')) {
      return 'Account name must not contain spaces.';
    }
    return null;
  }

  String _formatRole(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.staff:
        return 'Salesperson';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
