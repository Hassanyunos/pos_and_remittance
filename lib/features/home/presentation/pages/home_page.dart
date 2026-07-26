import 'package:flutter/material.dart';

import '../../../auth/application/auth_service.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../user_management/presentation/pages/create_user_page.dart';
import '../../../auth/presentation/pages/change_password_page.dart';
import '../../../customer_management/presentation/pages/customer_management_page.dart';
import '../../../expense_management/presentation/pages/expense_management_page.dart';
import '../../../fund_management/presentation/pages/fund_management_page.dart';
import '../../../grocery_stock_management/presentation/pages/grocery_stock_management_page.dart';
import '../../../remittance_management/presentation/pages/remittance_management_page.dart';
import '../../../sales_management/presentation/pages/sales_management_page.dart';
import 'dashboard_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) return const LoginPage();

    final modules = <_ModuleCardData>[
      _ModuleCardData(
        title: 'Expenses',
        subtitle: 'Log spending and link it to funds',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFF59E0B),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const ExpenseManagementPage())),
      ),
      _ModuleCardData(
        title: 'Customer',
        subtitle: 'Manage customer profiles and balances',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF3B82F6),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const CustomerManagementPage())),
      ),
      _ModuleCardData(
        title: 'Fund',
        subtitle: user.isOwner
            ? 'Review balances and manage zakah'
            : 'Owner access required',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFFEF4444),
        enabled: user.isOwner,
        onTap: () {
          if (!user.isOwner) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Only owner can access Funds.')),
            );
            return;
          }
          Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const FundManagementPage()));
        },
      ),
      _ModuleCardData(
        title: 'Grocery Stock',
        subtitle: 'Monitor inventory, expiry, and alerts',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const GroceryStockManagementPage())),
      ),
      _ModuleCardData(
        title: 'Remittance',
        subtitle: 'Track cash-in and cash-out records',
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFF10B981),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const RemittanceManagementPage())),
      ),
      _ModuleCardData(
        title: 'Sales',
        subtitle: 'Process point-of-sale transactions',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF0F766E),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const SalesManagementPage())),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS & Remittance'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account options',
            onSelected: (value) async {
              switch (value) {
                case 'change_password':
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const ChangePasswordPage()));
                  break;
                case 'create_user':
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const CreateUserPage()));
                  break;
                case 'logout':
                  await AuthService.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                            builder: (_) => const LoginPage()));
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'change_password',
                  child: ListTile(
                      leading: Icon(Icons.password_rounded),
                      title: Text('Change password'),
                      contentPadding: EdgeInsets.zero)),
              if (user.isOwner)
                const PopupMenuItem(
                    value: 'create_user',
                    child: ListTile(
                        leading: Icon(Icons.person_add_alt_1_rounded),
                        title: Text('Create user'),
                        contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                      leading: Icon(Icons.logout_rounded),
                      title: Text('Logout'),
                      contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const DashboardPage())),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2563EB), Color(0xFF10B981)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.analytics_rounded,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Business Dashboard',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'View sales, remittance, inventory, and expenses',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Operations',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.12,
                      ),
                      itemCount: modules.length,
                      itemBuilder: (context, index) {
                        final module = modules[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: module.enabled ? module.onTap : null,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: module.color.withValues(
                                        alpha: module.enabled ? 0.16 : 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(module.icon,
                                      color: module.enabled
                                          ? module.color
                                          : Colors.grey,
                                      size: 24),
                                ),
                                const Spacer(),
                                Text(
                                  module.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: module.enabled
                                            ? null
                                            : Colors.grey.shade700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  module.subtitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: module.enabled
                                            ? null
                                            : Colors.grey.shade600,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModuleCardData {
  const _ModuleCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;
}
