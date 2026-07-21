import 'package:flutter/material.dart';

import '../../../auth/application/auth_service.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../user_management/presentation/pages/create_user_page.dart';
import '../../../auth/presentation/pages/change_password_page.dart';
import '../../../fund_management/presentation/pages/fund_management_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) return const LoginPage();
    return Scaffold(
      appBar: AppBar(title: const Text('POS & Remittance'), actions: [IconButton(
        icon: const Icon(Icons.logout), tooltip: 'Sign out', onPressed: () async {
          await AuthService.instance.signOut();
          if (context.mounted) Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
        })]),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Welcome, ${user.name}', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8), Text(user.email), const SizedBox(height: 24),
          FilledButton.icon(icon: const Icon(Icons.password), label: const Text('Change password'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ChangePasswordPage()))),
          if (user.isOwner) ...[
            const SizedBox(height: 12),
            FilledButton.icon(icon: const Icon(Icons.person_add), label: const Text('Create user'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CreateUserPage()))),
            const SizedBox(height: 12),
            FilledButton.icon(icon: const Icon(Icons.account_balance_wallet), label: const Text('Fund management'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FundManagementPage()))),
          ],
        ],
      ))),
    );
  }
}
